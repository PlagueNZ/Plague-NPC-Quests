local UPDATE = {
  enabled = true,
  repo = "PlagueNZ/plague_npc_quests_2.0", -- CHANGE: owner/repo
  intervalMinutes = 360,                  -- check every 6 hours
  notifyOnStart = true
}

local function getLocalVersion()
  -- You can set this in fxmanifest.lua as: version '2.0.3'
  return GetResourceMetadata(GetCurrentResourceName(), "version", 0) or "0.0.0"
end

local function normalizeTag(tag)
  if type(tag) ~= "string" then return "" end
  return tag:gsub("^v", ""):gsub("%s+", "")
end

local function isNewer(remote, localv)
  -- very simple semver compare: major.minor.patch
  local function split(v)
    local a,b,c = v:match("^(%d+)%.(%d+)%.(%d+)$")
    return tonumber(a) or 0, tonumber(b) or 0, tonumber(c) or 0
  end
  local r1,r2,r3 = split(remote)
  local l1,l2,l3 = split(localv)
  if r1 ~= l1 then return r1 > l1 end
  if r2 ~= l2 then return r2 > l2 end
  return r3 > l3
end

local function checkForUpdates()
  if not UPDATE.enabled then return end

  local localv = normalizeTag(getLocalVersion())
  local url = ("https://api.github.com/repos/%s/releases/latest"):format(UPDATE.repo)

  PerformHttpRequest(url, function(code, body, headers)
    if code ~= 200 or type(body) ~= "string" then
      Util.dbg("^3UpdateCheck:^7 failed", "http=", code)
      return
    end

    local data = json.decode(body)
    if not data or not data.tag_name then
      Util.dbg("^3UpdateCheck:^7 invalid response")
      return
    end

    local remotev = normalizeTag(data.tag_name)
    if remotev == "" then return end

    if isNewer(remotev, localv) then
      print(("^3[PLAGUE_NPC_QUEST]^7 Update available: ^5%s^7 (installed ^2%s^7)"):format(remotev, localv))
      if data.html_url then
        print(("^3[PLAGUE_NPC_QUEST]^7 Release: %s"):format(data.html_url))
      end
    else
      Util.dbg("^2UpdateCheck:^7 up to date", "version=", localv)
    end
  end, "GET", "", {
    ["User-Agent"] = "plague_npc_quest_update_checker",
    ["Accept"] = "application/vnd.github+json"
  })
end

CreateThread(function()
  Wait(2000)
  if UPDATE.notifyOnStart then
    checkForUpdates()
  end

  local ms = (tonumber(UPDATE.intervalMinutes) or 360) * 60 * 1000
  while true do
    Wait(ms)
    checkForUpdates()
  end
end)

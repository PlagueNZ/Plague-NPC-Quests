-- server/version.lua
-- Checks Cloudflare Pages for updates and logs if outdated.

local RESOURCE = GetCurrentResourceName()

--local UPDATE_URL = "https://plague-npc-quests-updates.pages.dev/plague_npc_quests/version.json"
-- When your custom domain is ready, swap to:
local UPDATE_URL = "https://update.plagueoce.com/version.json"

local function dbg(...)
  if Util and Util.dbg then
    Util.dbg(...)
  else
    print("^2[PLAGUE_NPC_QUEST]^7", ...)
  end
end

-- Read fxmanifest.lua and extract version 'x.y.z'
local function getLocalVersion()
  local raw = LoadResourceFile(RESOURCE, "fxmanifest.lua")
  if not raw or raw == "" then return nil end

  -- matches: version '0.0.1' or version "0.0.1"
  local v = raw:match("version%s+['\"]([^'\"]+)['\"]")
  if not v or v == "" then return nil end
  return v
end

-- Parse versions like: 2.0.1, v2.0.1, 2.0, 2
local function parseVersion(v)
  if type(v) ~= "string" then return {0,0,0} end
  v = v:gsub("^v", "")
  local a,b,c = v:match("^(%d+)%.?(%d*)%.?(%d*)")
  return {
    tonumber(a) or 0,
    tonumber(b) or 0,
    tonumber(c) or 0
  }
end

local function isNewer(remote, localv)
  local r = parseVersion(remote)
  local l = parseVersion(localv)
  for i = 1, 3 do
    if r[i] > l[i] then return true end
    if r[i] < l[i] then return false end
  end
  return false
end

local function httpGetJson(url, cb)
  PerformHttpRequest(url, function(code, body, headers)
    if code ~= 200 or not body or body == "" then
      cb(false, ("HTTP %s"):format(tostring(code)), nil)
      return
    end

    local ok, data = pcall(function()
      return json.decode(body)
    end)

    if not ok or type(data) ~= "table" then
      cb(false, "JSON decode failed", nil)
      return
    end

    cb(true, nil, data)
  end, "GET", "", {
    ["User-Agent"] = "plague_npc_quests_update_check",
    ["Accept"] = "application/json"
  })
end

local function runCheck()
  local localV = getLocalVersion() or "0.0.0"
  dbg(("Version check: local=%s, url=%s"):format(localV, UPDATE_URL))

  httpGetJson(UPDATE_URL, function(ok, err, data)
    if not ok then
      dbg("^3Update check failed:^7", err or "unknown error")
      return
    end

    -- Expected JSON shape:
    -- { "resource": "plague_npc_quests_2.0", "latest": "2.0.0", "notes": "...", "url": "..." }
    local latest = tostring(data.latest or "")
    if latest == "" then
      dbg("^3Update check:^7 missing 'latest' in JSON")
      return
    end

    local remoteIsNewer = isNewer(latest, localV)

    if remoteIsNewer then
      print("^1[PLAGUE_NPC_QUEST]^7 Update available!")
      print(("^1[PLAGUE_NPC_QUEST]^7 Current: %s  Latest: %s"):format(localV, latest))
      if data.notes and tostring(data.notes) ~= "" then
        print(("^1[PLAGUE_NPC_QUEST]^7 Notes: %s"):format(tostring(data.notes)))
      end
      if data.url and tostring(data.url) ~= "" then
        print(("^1[PLAGUE_NPC_QUEST]^7 More info: %s"):format(tostring(data.url)))
      end
    else
      dbg(("Up to date (local=%s, latest=%s)"):format(localV, latest))
    end
  end)
end

CreateThread(function()
  -- Delay slightly so resource is fully booted and util/config loaded
  Wait(3500)
  runCheck()
end)

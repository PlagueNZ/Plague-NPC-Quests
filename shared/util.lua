-- shared/util.lua
Util = Util or {}

-- -----------------------------
-- Debug print (client + server)
-- -----------------------------
function Util.dbg(...)
  if Config and Config.Debug then
    print("^2[PLAGUE_NPC_QUEST]^7", ...)
  end
end

-- -----------------------------
-- Random helper (client + server)
-- -----------------------------
function Util.randBetween(a, b)
  a = tonumber(a) or 0
  b = tonumber(b) or 0
  if b < a then a, b = b, a end
  return math.random(a, b)
end

-- -----------------------------
-- Read file helper (resource) (client + server)
-- -----------------------------
function Util.readResourceFile(path)
  local res = GetCurrentResourceName()
  local raw = LoadResourceFile(res, path)
  if not raw then
    Util.dbg("^1Missing file:^7", path)
    return nil
  end
  return raw
end

-- -----------------------------
-- JSON decode safe (client + server)
-- -----------------------------
function Util.jsonDecode(raw, fallback)
  if type(raw) ~= "string" or raw == "" then
    return fallback
  end

  local ok, parsed = pcall(function()
    return json.decode(raw)
  end)

  if not ok then
    Util.dbg("^1JSON decode failed:^7", parsed)
    return fallback
  end

  return parsed
end

-- -----------------------------
-- Load JSON file to table (client + server)
-- -----------------------------
function Util.loadJsonFile(path, fallback)
  local raw = Util.readResourceFile(path)
  if not raw then return fallback end
  return Util.jsonDecode(raw, fallback)
end

-- -----------------------------
-- Client-only notify event
-- -----------------------------
if not IsDuplicityVersion() then
  RegisterNetEvent("plague_npc_quest:notify", function(data)
    if not data or not data.text then return end

    -- ox_lib notify
    if lib and lib.notify then
      lib.notify({
        type = data.type or "inform",
        description = data.text
      })
    else
      print("[PLAGUE_NPC_QUEST]", data.text)
    end
  end)
end

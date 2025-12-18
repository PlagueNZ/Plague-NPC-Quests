Quests = Quests or {}

local function getCitizenId(src)
  local Player = exports.qbx_core:GetPlayer(src)
  if not Player or not Player.PlayerData then return nil end
  return Player.PlayerData.citizenid
end

local function decodeFlags(s)
  if not s or s == "" then return {} end
  local ok, t = pcall(json.decode, s)
  return ok and (t or {}) or {}
end

local function encodeFlags(t)
  local ok, s = pcall(json.encode, t or {})
  return ok and s or "{}"
end

-- Ensure row exists, then fetch
function Quests.GetState(src, questId)
  local citizenid = getCitizenId(src)
  if not citizenid then return nil end

  local row = MySQL.single.await([[
    SELECT stage, flags_json
    FROM plague_quests
    WHERE citizenid = ? AND quest_id = ?
  ]], { citizenid, questId })

  if not row then
    MySQL.insert.await([[
      INSERT INTO plague_quests (citizenid, quest_id, stage, flags_json)
      VALUES (?, ?, 0, '{}')
    ]], { citizenid, questId })

    return { citizenid = citizenid, questId = questId, stage = 0, flags = {} }
  end

  return { citizenid = citizenid, questId = questId, stage = tonumber(row.stage) or 0, flags = decodeFlags(row.flags_json) }
end

function Quests.SetStage(src, questId, stage)
  local citizenid = getCitizenId(src)
  if not citizenid then return false end

  -- keep flags as-is
  MySQL.update.await([[
    INSERT INTO plague_quests (citizenid, quest_id, stage, flags_json)
    VALUES (?, ?, ?, '{}')
    ON DUPLICATE KEY UPDATE stage = VALUES(stage)
  ]], { citizenid, questId, stage })

  return true
end

function Quests.SetFlag(src, questId, key, value)
  local state = Quests.GetState(src, questId)
  if not state then return false end

  state.flags[key] = value

  MySQL.update.await([[
    UPDATE plague_quests
    SET flags_json = ?
    WHERE citizenid = ? AND quest_id = ?
  ]], { encodeFlags(state.flags), state.citizenid, questId })

  return true
end

function Quests.Reset(src, questId)
  local citizenid = getCitizenId(src)
  if not citizenid then return false end

  MySQL.update.await([[
    DELETE FROM plague_quests
    WHERE citizenid = ? AND quest_id = ?
  ]], { citizenid, questId })

  return true
end

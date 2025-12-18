CreateThread(function()
  if Util and Util.dbg then
    Util.dbg("Client boot (rebuild) OK")
  else
    print("^2[PLAGUE_NPC_QUEST]^7 Client boot (rebuild) OK (Util not ready?)")
  end
end)

CreateThread(function()
  Wait(500)
  if Zones and Zones.Init then
    Zones.Init()
  end
end)


ClientQuestsUI = ClientQuestsUI or {}
if ClientQuestsUI.hideCompleted == nil then
  ClientQuestsUI.hideCompleted = false
end


local function isCompletedQuest(q)
  -- Best: rely on stageLabel or a flag if you add one later
  if q.flags and q.flags.completed == true then return true end
  if type(q.stageLabel) == "string" and q.stageLabel:lower() == "completed" then return true end

  -- Fallback heuristic (works for your current quests):
  return (tonumber(q.stage) or 0) >= 2
end

local function buildReqLines(requirements)
  if type(requirements) ~= "table" or #requirements == 0 then
    return nil
  end

  local done, missing = {}, {}

  for _, r in ipairs(requirements) do
    local have = tonumber(r.have) or 0
    local need = tonumber(r.need) or 0
    local label = r.label or r.name or "item"
    local ok = have >= need

    local line = ("%s %d/%d %s"):format(ok and "✔" or "✖", have, need, label)

    if ok then
      done[#done + 1] = line
    else
      missing[#missing + 1] = line
    end
  end

  -- Missing first, then fulfilled
  local lines = {}
  for _, l in ipairs(missing) do lines[#lines + 1] = l end
  for _, l in ipairs(done) do lines[#lines + 1] = l end

  return table.concat(lines, "\n")
end

local function ShowQuestUI()
  local quests = lib.callback.await("plague_npc_quest:status:get", false)
  if type(quests) ~= "table" then return end

  local options = {}

  -- Toggle: hide/show completed
  options[#options + 1] = {
    title = ClientQuestsUI.hideCompleted and "Show completed quests" or "Hide completed quests",
    description = "Toggle whether completed questlines are displayed.",
    onSelect = function()
      ClientQuestsUI.hideCompleted = not ClientQuestsUI.hideCompleted
      ShowQuestUI() -- rebuild immediately (no ExecuteCommand)
    end
  }

  for _, q in ipairs(quests) do
    local stage = tonumber(q.stage) or 0
    local completed = isCompletedQuest(q)

    -- Hide not-started quests (stage 0) unless completed
    if stage == 0 and not completed then
      goto continue
    end

    -- Hide completed quests if toggle enabled
    if ClientQuestsUI.hideCompleted and completed then
      goto continue
    end

    local desc = q.stageLabel or ("Stage " .. stage)

    local reqText = buildReqLines(q.requirements)
    if reqText then
      desc = desc .. "\n\nRequirements:\n" .. reqText
    end

    options[#options + 1] = {
      title = q.title,
      description = desc
    }

    ::continue::
  end

  if #options == 1 then
    options[#options + 1] = {
      title = "No active quests",
      description = "You have no quests in progress right now."
    }
  end

  lib.registerContext({
    id = "plague_quest_status",
    title = "Quest Status",
    options = options
  })

  lib.showContext("plague_quest_status")
end

RegisterCommand("quest", function()
  ShowQuestUI()
end, false)

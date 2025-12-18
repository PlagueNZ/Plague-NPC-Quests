if GetResourceState('oxmysql') ~= 'started' then
  print("^1[PLAGUE_NPC_QUEST]^7 oxmysql is not started!")
end

-- Client asks for quest state
RegisterNetEvent("plague_npc_quest:quests:getState", function(questId)
  local src = source
  local state = Quests.GetState(src, questId)
  TriggerClientEvent("plague_npc_quest:quests:state", src, state)
end)

-- Dialogue button action: set stage
RegisterNetEvent("plague_npc_quest:quests:setStage", function(data)
  local src = source
  if type(data) ~= "table" then return end

  local questId = tostring(data.questId or "")
  local stage = tonumber(data.stage)

  if questId == "" or stage == nil then return end

  Quests.SetStage(src, questId, stage)
  local state = Quests.GetState(src, questId)
  TriggerClientEvent("plague_npc_quest:quests:state", src, state)
end)

-- Dialogue button action: set flag
RegisterNetEvent("plague_npc_quest:quests:setFlag", function(data)
  local src = source
  if type(data) ~= "table" then return end

  local questId = tostring(data.questId or "")
  local key = tostring(data.key or "")
  local value = data.value

  if questId == "" or key == "" then return end

  Quests.SetFlag(src, questId, key, value)
  local state = Quests.GetState(src, questId)
  TriggerClientEvent("plague_npc_quest:quests:state", src, state)
end)

-- =========================
-- XP SYSTEM (plague_quests)
-- =========================

local XP = {}
XP.QuestId = "__xp__"

function XP.get(src)
  local state = Quests.GetState(src, XP.QuestId)
  return tonumber(state and state.stage) or 0
end

function XP.add(src, amount)
  if not (Config.XP and Config.XP.Enabled) then return end
  amount = tonumber(amount) or 0
  if amount <= 0 then return end

  local newXp = XP.get(src) + amount

  Quests.SetStage(src, XP.QuestId, newXp)

  TriggerClientEvent("plague_npc_quest:xp:gain", src, {
    amount = amount,
    total = newXp
  })

  Util.dbg(("[PLAGUE_NPC_QUEST] XP +%d (total=%d)"):format(amount, newXp))
end

function XP.getTierFromXP(xp)
  xp = tonumber(xp) or 0
  if xp >= 30 then return 3 end
  if xp >= 20 then return 2 end
  if xp >= 10 then return 1 end
  return 0
end

function XP.awardQuestCompletionOnce(src, questId)
  if not (Config.XP and Config.XP.Enabled) then return end
  questId = tostring(questId or "")
  if questId == "" then return end

  local qcfg = Config.QuestParameters and Config.QuestParameters[questId]
  local reward = tonumber(qcfg and qcfg.xpReward) or 0
  if reward <= 0 then return end

  local state = Quests.GetState(src, questId)
  local flags = state and state.flags or {}

  if flags.xp_awarded == true then return end

  Quests.SetFlag(src, questId, "xp_awarded", true)
  XP.add(src, reward)
end

-- =========================
-- QUEST COMPLETION CHECK
-- =========================

local function checkQuestCompletion(src, questId)
  questId = tostring(questId or "")
  if questId == "" then return end
  if questId == XP.QuestId then return end

  local qcfg = Config.QuestParameters and Config.QuestParameters[questId]
  if not qcfg then return end

  local completionStage = tonumber(qcfg.completionStage)
  if not completionStage then return end

  local state = Quests.GetState(src, questId)
  if not state then return end

  local flags = state.flags or {}
  if flags.completed == true then return end

  if tonumber(state.stage) ~= completionStage then return end

  Quests.SetFlag(src, questId, "completed", true)
  XP.awardQuestCompletionOnce(src, questId)

  Util.dbg(("[PLAGUE_NPC_QUEST] Quest completed: %s (stage=%d)"):format(questId, completionStage))
end

-- Wrap Quests.SetStage so completion is evaluated whenever stage changes
CreateThread(function()
  while not Quests or type(Quests.SetStage) ~= "function" do
    Wait(0)
  end

  if Quests.__plague_stage_hooked then return end
  Quests.__plague_stage_hooked = true

  local _SetStage = Quests.SetStage
  Quests.SetStage = function(src, questId, stage)
    _SetStage(src, questId, stage)
    checkQuestCompletion(src, questId)
  end

  Util.dbg("^2[PLAGUE_NPC_QUEST]^7 Quest completion hook installed (Quests.SetStage wrapped)")
end)

-- =========================
-- Conditions (dialogue filtering)
-- =========================

local function evalCondition(src, cond)
  if cond.type == "questStage" then
    local questId = tostring(cond.questId or "")
    local op = cond.op
    local value = tonumber(cond.value)
    if questId == "" or value == nil then return false end

    local state = Quests.GetState(src, questId)
    local stage = state and state.stage or 0

    if op == "==" then return stage == value end
    if op == "!=" then return stage ~= value end
    if op == ">=" then return stage >= value end
    if op == "<=" then return stage <= value end
    if op == ">"  then return stage > value end
    if op == "<"  then return stage < value end
  end

  if cond.type == "questFlag" then
    local questId = tostring(cond.questId or "")
    local key = tostring(cond.key or "")
    local op = tostring(cond.op or "==")
    local value = cond.value

    if questId == "" or key == "" then return false end

    local state = Quests.GetState(src, questId)
    local flags = state and state.flags or {}
    local cur = flags[key]

    if op == "exists" then return cur ~= nil end
    if value == nil then return cur == true end
    if op == "==" then return cur == value end
    if op == "!=" then return cur ~= value end
  end

  return false
end

local function filterButtonsForPlayer(src, buttons)
  if not buttons then return {} end
  local out = {}

  for _, btn in ipairs(buttons) do
    local ok = true
    if btn.conditions then
      for _, cond in ipairs(btn.conditions) do
        if not evalCondition(src, cond) then
          ok = false
          break
        end
      end
    end

    if ok then
      out[#out + 1] = btn
    end
  end

  return out
end

RegisterNetEvent("plague_npc_quest:dialogue:getNode", function(data)
  local src = source
  if type(data) ~= "table" then return end

  local npcId = tostring(data.npcId or "")
  local node = data.node
  if npcId == "" or type(node) ~= "table" then return end

  local filteredButtons = filterButtonsForPlayer(src, node.buttons)

  TriggerClientEvent("plague_npc_quest:dialogue:node", src, {
    npcId = npcId,
    text = node.text,
    buttons = filteredButtons
  })
end)

-- =========================
-- Payments (ox_inventory)
-- =========================

RegisterNetEvent("plague_npc_quest:quests:pay", function(data)
  local src = source
  if type(data) ~= "table" then return end

  local questId = tostring(data.questId or "")
  local paymentKey = tostring(data.paymentKey or "")
  local npcId = tostring(data.npcId or "giver")
  local okNodeId = tostring(data.okNodeId or "")
  local failNodeId = tostring(data.failNodeId or "")

  if questId == "" or paymentKey == "" then return end

  local questCfg = Config.QuestParameters and Config.QuestParameters[questId]
  local paymentCfg = questCfg and questCfg.payments and questCfg.payments[paymentKey]
  if not paymentCfg then return end

  local inv = exports.ox_inventory
  local moneyItem = Config.Money or "black_money"

  -- Check items
  for item, amount in pairs((paymentCfg.items or {})) do
    if inv:GetItemCount(src, item) < amount then
      TriggerClientEvent("plague_npc_quest:dialogue:goto", src, { npcId = npcId, nodeId = failNodeId })
      return
    end
  end

  -- Check money item
  local moneyAmount = tonumber(paymentCfg.money) or 0
  if moneyAmount > 0 then
    if inv:GetItemCount(src, moneyItem) < moneyAmount then
      TriggerClientEvent("plague_npc_quest:dialogue:goto", src, { npcId = npcId, nodeId = failNodeId })
      return
    end
  end

  -- Remove items
  for item, amount in pairs((paymentCfg.items or {})) do
    inv:RemoveItem(src, item, amount)
  end

  if moneyAmount > 0 then
    inv:RemoveItem(src, moneyItem, moneyAmount)
  end

  -- Advance quest (payment-driven)
  local nextStage = tonumber(paymentCfg.onSuccess and paymentCfg.onSuccess.setStage)
  if not nextStage then
    Util.dbg(("^1[PLAGUE_NPC_QUEST]^7 paymentCfg missing onSuccess.setStage for questId=%s paymentKey=%s"):format(questId, paymentKey))
    return
  end

  Quests.SetStage(src, questId, nextStage)

  local state = Quests.GetState(src, questId)
  TriggerClientEvent("plague_npc_quest:quests:state", src, state)

  -- Show success node (client keeps dialogue open)
  TriggerClientEvent("plague_npc_quest:dialogue:goto", src, { npcId = npcId, nodeId = okNodeId })

end)

lib.callback.register("plague_npc_quest:status:get", function(src)
  local results = {}

  for questId, qcfg in pairs(Config.QuestParameters or {}) do
    local state = Quests.GetState(src, questId) or { stage = 0, flags = {} }
    local stage = tonumber(state.stage) or 0

    local entry = {
      questId = questId,
      stage = stage,
      flags = state.flags or {},
      title = (qcfg.status and qcfg.status.name) or questId,
      stageLabel = (qcfg.status and qcfg.status.stages and qcfg.status.stages[stage]) or ("Stage " .. stage),
      requirements = nil
    }

    local paymentKey =
      qcfg.status and qcfg.status.paymentStages and qcfg.status.paymentStages[stage]

    if paymentKey and qcfg.payments and qcfg.payments[paymentKey] then
      local paymentCfg = qcfg.payments[paymentKey]
      local reqs = {}

      for item, amount in pairs(paymentCfg.items or {}) do
        local have = exports.ox_inventory:GetItemCount(src, item) or 0

        local itemData = exports.ox_inventory:Items(item)
        local label = itemData and itemData.label or item

        reqs[#reqs + 1] = { 
          name = item,
          label = label,
          have = have, 
          need = amount }
      end

      local moneyNeed = tonumber(paymentCfg.money) or 0
      if moneyNeed > 0 then
        local moneyItem = Config.Money or "black_money"
        local have = exports.ox_inventory:GetItemCount(src, moneyItem) or 0

        local moneyData = exports.ox_inventory:Items(moneyItem)
        local label = moneyData and moneyData.label or moneyItem

        reqs[#reqs + 1] = {
          name = moneyItem,
          label = label,
          have = have,
          need = moneyNeed
        }
      end

      entry.requirements = reqs
    end

    results[#results + 1] = entry
  end

  return results
end)



-- Dev commands
if Config.Debug then
  RegisterCommand("questset", function(src, args)
    if src == 0 then return end

    local questId = args[1]
    local stage = tonumber(args[2])
    if not questId or stage == nil then return end

    Quests.SetStage(src, questId, stage)

    local state = Quests.GetState(src, questId)
    TriggerClientEvent("plague_npc_quest:quests:state", src, state)

    Util.dbg("DEV command questset:", "questId=", questId, "stage=", stage)
  end)

  RegisterCommand("questreset", function(src, args)
    if src == 0 then return end

    local questId = args[1]
    if not questId then return end

    Quests.Reset(src, questId)
    TriggerClientEvent("plague_npc_quest:quests:state", src, { questId = questId, stage = 0, flags = {} })

    Util.dbg("DEV command questreset:", "questId=", questId)
  end)
end


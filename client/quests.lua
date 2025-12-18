ClientQuests = ClientQuests or {}
ClientQuests.state = ClientQuests.state or {} -- [questId] = {stage, flags}

RegisterNetEvent("plague_npc_quest:quests:state", function(state)
  if type(state) ~= "table" or not state.questId then return end
  ClientQuests.state[state.questId] = { stage = state.stage or 0, flags = state.flags or {} }
  Util.dbg("Quest state updated:", state.questId, "stage=", state.stage)
end)

function ClientQuests.get(questId)
  return ClientQuests.state[questId]
end

function ClientQuests.request(questId)
  TriggerServerEvent("plague_npc_quest:quests:getState", questId)
end

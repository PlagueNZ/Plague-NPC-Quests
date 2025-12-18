Dialogue = Dialogue or {}
Dialogue.active = false
Dialogue.npcId = nil
Dialogue.nodeId = nil
Dialogue.uiButtons = {}

local function getNode(npc, nodeId)
  if not npc or not npc.nodes then return nil end
  return npc.nodes[nodeId]
end

local function dumpNode(npc, nodeId, node)
  Util.dbg(("DIALOGUE [%s:%s] %s"):format(npc.id, nodeId, node.text or ""))

  local btns = node.buttons or {}
  if #btns == 0 then
    Util.dbg("  (no buttons)")
    return
  end

  for i, b in ipairs(btns) do
    Util.dbg(("  [%d] %s (%s) -> %s"):format(
      i,
      b.label or "???",
      b.id or "no_id",
      b.next == nil and "nil" or tostring(b.next)
    ))
  end
end

local function toPayload(npc, node)
  return {
    locale = (Config and Config.Locale) or "en",
    npcName = npc.name or npc.id,
    npcSubtitle = npc.subtitle or "",
    text = node.text or "",
    buttons = node.buttons or {}
  }
end

local function startCameraForNpc(npcId)
  if not (Camera and Camera.startOnPed) then return end
  if not (NPC and NPC.spawned) then return end

  local ped = NPC.spawned[npcId]
  if ped and DoesEntityExist(ped) then
    Camera.startOnPed(ped)
  else
    Util.dbg("^3Camera:^7 ped not found for npcId=", npcId)
  end
end

function Dialogue.start(npcId)
  local npc = DialogueData.getNpc(npcId)
  if not npc then
    Util.dbg("^3Dialogue:^7 no dialogue for npcId=", npcId)
    return
  end

  local nodeId = "start"
  local node = getNode(npc, nodeId)
  if not node then
    Util.dbg("^1Dialogue:^7 npc has no 'start' node:", npcId)
    return
  end

  Dialogue.active = true
  Dialogue.npcId = npcId
  Dialogue.nodeId = nodeId
  Dialogue.uiButtons = {}

  Util.dbg(("NPC: %s (%s)"):format(npc.name or npc.id, npc.subtitle or ""))
  dumpNode(npc, nodeId, node)

  -- Start camera first, then open UI
  startCameraForNpc(npcId)

  if NUI and NUI.open then
    TriggerServerEvent("plague_npc_quest:dialogue:getNode", {
      npcId = npc.id,
      node = node
    })
  end
end

function Dialogue.press(index)
  if not Dialogue.active then return end

  local npc = DialogueData.getNpc(Dialogue.npcId)
  if not npc then return end

  local node = getNode(npc, Dialogue.nodeId)
  if not node then
    Dialogue.stop()
    return
  end

  local btn = (Dialogue.uiButtons and Dialogue.uiButtons[index]) or (node.buttons and node.buttons[index])
  if not btn then
    Util.dbg("^1Dialogue:^7 invalid button index=", index)
    return
  end

  -- OPTIONAL SERVER ACTION (QUESTS)
  if btn.action and btn.data then
    if btn.action == "quest:setStage" then
      TriggerServerEvent("plague_npc_quest:quests:setStage", btn.data)

    elseif btn.action == "quest:setFlag" then
      TriggerServerEvent("plague_npc_quest:quests:setFlag", btn.data)

    elseif btn.action == "quest:requestState" then
      TriggerServerEvent("plague_npc_quest:quests:getState", btn.data.questId)

    elseif btn.action == "quest:pay" then
      TriggerServerEvent("plague_npc_quest:quests:pay", btn.data)
    end
  end

  -- IMPORTANT: action-only buttons wait for server response (do not advance locally)
-- Action-only buttons:
-- - If close=true → close immediately after action
-- - Otherwise → wait for server response
  if btn.action and btn.next == nil then
    if btn.close then

      Dialogue.stop()
    end
    return
  end


  -- END DIALOGUE (only if no action)
  if btn.next == nil and not btn.action then
    Util.dbg("Button ends dialogue:", btn.id or btn.label or index)
    Dialogue.stop()
    return
  end

  -- ADVANCE NODE
  local nextNode = getNode(npc, btn.next)
  if not nextNode then
    Util.dbg("^1Dialogue:^7 next node missing:", tostring(btn.next))
    Dialogue.stop()
    return
  end

  Dialogue.nodeId = btn.next
  dumpNode(npc, btn.next, nextNode)

  -- UPDATE NUI
  if NUI and NUI.render then
    TriggerServerEvent("plague_npc_quest:dialogue:getNode", {
      npcId = npc.id,
      node = nextNode
    })
  end
end


function Dialogue.stop()
  if not Dialogue.active then return end

  Util.dbg("Dialogue stopped:", Dialogue.npcId)

  -- Stop camera first (prevents stuck scripted cam issues)
  if Camera and Camera.stop then
    Camera.stop()
  end

  -- Close NUI (releases focus)
  if NUI and NUI.close then
    NUI.close()
  end

  -- Clear the server-filtered UI buttons (prevents stale index mapping)
  Dialogue.uiButtons = {}

  Dialogue.active = false
  Dialogue.npcId = nil
  Dialogue.nodeId = nil
end


RegisterNetEvent("plague_npc_quest:dialogue:node", function(data)
  if not Dialogue.active then return end
  if type(data) ~= "table" then return end

  local npc = DialogueData.getNpc(data.npcId)
  if not npc then return end

  Dialogue.uiButtons = data.buttons or {}

  if NUI and NUI.render then
    NUI.render({
      locale = (Config and Config.Locale) or "en",
      npcName = npc.name or npc.id,
      npcSubtitle = npc.subtitle or "",
      text = data.text or "",
      buttons = Dialogue.uiButtons
    })
  end

  -- Auto-close ONLY if server sent a terminal node
  if #Dialogue.uiButtons == 0 then
    CreateThread(function()
      Wait(10000)
      if Dialogue.active then
        Dialogue.stop()
      end
    end)
  end
end)




-- Server can force-jump the active dialogue to a nodeId (e.g., payment success/fail)
RegisterNetEvent("plague_npc_quest:dialogue:goto", function(data)
  if not Dialogue.active then return end
  if type(data) ~= "table" then return end

  local npcId = data.npcId
  local nodeId = data.nodeId
  if not npcId or not nodeId then return end

  local npc = DialogueData.getNpc(npcId)
  if not npc then return end

  local node = getNode(npc, nodeId)
  if not node then
    Util.dbg("^1Dialogue:^7 goto missing node:", tostring(nodeId))
    return
  end

  Dialogue.nodeId = nodeId

  -- Ask server to filter buttons for this node and render it
  TriggerServerEvent("plague_npc_quest:dialogue:getNode", {
    npcId = npc.id,
    node = node
  })
end)

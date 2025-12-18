NUI = NUI or {}
NUI.opened = false

local function send(action, payload)
  payload = payload or {}
  payload.action = action
  SendNUIMessage(payload)
end

function NUI.open(payload)
  if not NUI.opened then
    NUI.opened = true
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(false)
  end
  send("open", payload)
end

function NUI.render(payload)
  if not NUI.opened then
    return NUI.open(payload)
  end
  send("render", payload)
end

function NUI.close()
  if not NUI.opened then return end
  NUI.opened = false
  send("close", {})
  SetNuiFocus(false, false)
  SetNuiFocusKeepInput(false)
end

RegisterNUICallback("close", function(_, cb)
  Dialogue.stop()
  cb(true)
end)

RegisterNUICallback("press", function(data, cb)
  local idx = tonumber(data and data.index)
  if idx then
    Dialogue.press(idx)
  end
  cb(true)
end)

AddEventHandler("onResourceStop", function(res)
  if res ~= GetCurrentResourceName() then return end
  NUI.close()
end)

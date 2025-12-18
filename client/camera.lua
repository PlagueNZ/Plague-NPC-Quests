Camera = Camera or {}

Camera.active = false
Camera.cam = nil
Camera.thread = nil

Camera._prevFrozen = false
Camera._prevVisible = true
Camera._prevCollision = true
Camera._prevCanSwitchWeapon = true

-- Tweak these if you want different framing
Camera.Offset = vector3(0.0, 1.55, 0.65)  -- (x right, y forward, z up) from NPC
Camera.LookAt = vector3(0.0, 0.0, 0.60)  -- where on NPC to aim (z is "head-ish")
Camera.Fov = 50.0

local function safeDestroyCam()
  if Camera.cam then
    DestroyCam(Camera.cam, false)
    Camera.cam = nil
  end
  RenderScriptCams(false, true, 250, true, true)
end

-- Freeze + hide player while camera is active, and restore on stop
local function setPlayerState(state)
  local ped = PlayerPedId()
  if not DoesEntityExist(ped) then return end

  if state then
    Camera._prevFrozen = IsEntityPositionFrozen(ped)
    Camera._prevVisible = IsEntityVisible(ped)

    FreezeEntityPosition(ped, true)

    -- Hide player so they never block the shot
    SetEntityVisible(ped, false, false)
    SetEntityCollision(ped, false, false)

    -- Optional: reduce weirdness during UI
    SetPedCanSwitchWeapon(ped, false)
  else
    -- Restore freeze state
    FreezeEntityPosition(ped, Camera._prevFrozen or false)

    -- Restore visibility & collision
    SetEntityVisible(ped, Camera._prevVisible ~= false, false)
    SetEntityCollision(ped, true, true)

    SetPedCanSwitchWeapon(ped, true)
  end
end

local function startControlLock()
  if Camera.thread then return end

  Camera.thread = CreateThread(function()
    while Camera.active do
      -- Disable movement / combat / camera look. Keep ESC and chat etc.
      DisableControlAction(0, 1, true)   -- LookLeftRight
      DisableControlAction(0, 2, true)   -- LookUpDown
      DisableControlAction(0, 24, true)  -- Attack
      DisableControlAction(0, 25, true)  -- Aim
      DisableControlAction(0, 30, true)  -- MoveLeftRight
      DisableControlAction(0, 31, true)  -- MoveUpDown
      DisableControlAction(0, 21, true)  -- Sprint
      DisableControlAction(0, 22, true)  -- Jump
      DisableControlAction(0, 44, true)  -- Cover
      DisableControlAction(0, 140, true) -- Melee
      DisableControlAction(0, 141, true)
      DisableControlAction(0, 142, true)
      DisableControlAction(0, 143, true)

      Wait(0)
    end
    Camera.thread = nil
  end)
end

function Camera.startOnPed(targetPed)
  if Camera.active then
    Camera.stop()
  end

  if not targetPed or not DoesEntityExist(targetPed) then
    Util.dbg("^1Camera:^7 invalid target ped")
    return
  end

  Camera.active = true

  -- Freeze + hide player + disable controls
  setPlayerState(true)
  startControlLock()

  local npcCoords = GetEntityCoords(targetPed)
  local camPos = GetOffsetFromEntityInWorldCoords(
    targetPed,
    Camera.Offset.x, Camera.Offset.y, Camera.Offset.z
  )

  Camera.cam = CreateCamWithParams(
    "DEFAULT_SCRIPTED_CAMERA",
    camPos.x, camPos.y, camPos.z,
    0.0, 0.0, 0.0,
    Camera.Fov,
    true, 2
  )

  PointCamAtEntity(Camera.cam, targetPed, Camera.LookAt.x, Camera.LookAt.y, Camera.LookAt.z, true)
  SetCamActive(Camera.cam, true)
  RenderScriptCams(true, true, 250, true, true)

  Util.dbg("Camera started on ped=", targetPed, "npcCoords=", npcCoords)
end

function Camera.stop()
  if not Camera.active then
    safeDestroyCam()
    return
  end

  Camera.active = false
  safeDestroyCam()
  setPlayerState(false)

  Util.dbg("Camera stopped")
end

AddEventHandler("onResourceStop", function(res)
  if res ~= GetCurrentResourceName() then return end
  Camera.stop()
end)

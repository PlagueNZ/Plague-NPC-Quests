NPC = NPC or {}
NPC.spawned = NPC.spawned or {} -- [id] = ped

NPC._teaserLastAttention = 0
NPC._teaserLoopStarted = false
NPC._teaserAnimActive = false


local function loadModel(model)
  local hash = type(model) == "number" and model or joaat(model)
  if not IsModelInCdimage(hash) then return false end

  -- ox_lib is available (your fxmanifest loads @ox_lib/init.lua)
  if lib and lib.requestModel then
    lib.requestModel(hash)
    return true
  end

  RequestModel(hash)
  local timeout = GetGameTimer() + 5000
  while not HasModelLoaded(hash) and GetGameTimer() < timeout do
    Wait(0)
  end

  return HasModelLoaded(hash)
end

local function spawnOne(def)
  if not def or not def.id or not def.model or not def.coords then return end
  if NPC.spawned[def.id] and DoesEntityExist(NPC.spawned[def.id]) then return end

  local ok = loadModel(def.model)
  if not ok then
    Util.dbg("^1Failed to load model:^7", def.id)
    return
  end

  local c = def.coords
  local modelHash = type(def.model) == "number" and def.model or joaat(def.model)

  local ped = CreatePed(
    4,
    modelHash,
    c.x, c.y, c.z - 1.0,
    c.w or 0.0,
    false,
    true
  )

  if not ped or ped == 0 then
    Util.dbg("^1Failed to create ped:^7", def.id)
    return
  end

  SetEntityAsMissionEntity(ped, true, true)
  SetBlockingOfNonTemporaryEvents(ped, true)
  SetPedFleeAttributes(ped, 0, false)
  SetPedCanRagdoll(ped, false)
  SetEntityInvincible(ped, true)
  FreezeEntityPosition(ped, true)

  if def.scenario and def.scenario ~= "" then
    TaskStartScenarioInPlace(ped, def.scenario, 0, true)
  end

  NPC.spawned[def.id] = ped

  -- release model memory
  SetModelAsNoLongerNeeded(modelHash)

  Util.dbg("Spawned NPC:", def.id, "ped=", ped)
end

function NPC.spawnAll()
  if not Config or not Config.NPCs then return end
  for _, def in pairs(Config.NPCs) do
    spawnOne(def)
  end
end

function NPC.despawnAll()
  for id, ped in pairs(NPC.spawned) do
    if ped and DoesEntityExist(ped) then
      DeleteEntity(ped)
    end
    NPC.spawned[id] = nil
  end

  NPC._teaserLastAttention = 0
  NPC._teaserLoopStarted = false

  Util.dbg("Despawned all NPCs")
end

-- -----------------------------
-- Teaser attention (whistle/wave)
-- -----------------------------
local function getNpcDefById(id)
  if not Config or not Config.NPCs then return nil end
  for _, def in pairs(Config.NPCs) do
    if def and def.id == id then return def end
  end
  return nil
end

local function playTeaserAttentionAnim(ped, returnScenario)
  if not DoesEntityExist(ped) then return end
  if NPC._teaserAnimActive then return end

  NPC._teaserAnimActive = true

  local dict = "rcmnigel1c"
  local anim = "hailing_whistle_waive_a"

  RequestAnimDict(dict)
  while not HasAnimDictLoaded(dict) do Wait(0) end

  ClearPedSecondaryTask(ped)
  TaskPlayAnim(ped, dict, anim, 8.0, -8.0, 1800, 49, 0.0, false, false, false)

  CreateThread(function()
    Wait(1900)
    if DoesEntityExist(ped) and returnScenario then
      ClearPedTasks(ped)
      TaskStartScenarioInPlace(ped, returnScenario, 0, true)
    end

    -- hard lockout to prevent spam
    Wait(2000)
    NPC._teaserAnimActive = false
  end)
end


function NPC.StartTeaserAttentionLoop()
  if NPC._teaserLoopStarted then return end
  NPC._teaserLoopStarted = true

  CreateThread(function()
    while NPC._teaserLoopStarted do
      Wait(500)

      -- feature toggle
      if not Config.Attention or not Config.Attention.enabled then
        goto continue
      end

      -- do not interrupt active dialogue/UI/camera
      if (Dialogue and Dialogue.active) or (NUI and NUI.opened) or (Camera and Camera.active) then
        goto continue
      end

      local teaserPed = NPC.spawned and NPC.spawned["teaser"]
      if not teaserPed or not DoesEntityExist(teaserPed) then
        goto continue
      end

      local teaserDef = getNpcDefById("teaser")
      local returnScenario = teaserDef and teaserDef.scenario or nil

      local playerPed = PlayerPedId()
      local dist = #(GetEntityCoords(playerPed) - GetEntityCoords(teaserPed))

      if dist <= (Config.Attention.range or 25.0) then
        local now = GetGameTimer()
        local minDelay = Config.Attention.minDelayMs or 8000

        if (now - (NPC._teaserLastAttention or 0)) >= minDelay then
          NPC._teaserLastAttention = now
          playTeaserAttentionAnim(teaserPed, returnScenario)
          Util.dbg("Teaser attention anim played (dist=", dist, ")")
        end
      end

      ::continue::
    end
  end)
end

-- -----------------------------
-- Bootstrap
-- -----------------------------
CreateThread(function()
  while not NetworkIsSessionStarted() do Wait(250) end
  Wait(500)

  NPC.spawnAll()

  -- start teaser attention once NPCs exist
  if Config and Config.Attention and Config.Attention.enabled then
    NPC.StartTeaserAttentionLoop()
  end
end)

AddEventHandler("onResourceStop", function(res)
  if res ~= GetCurrentResourceName() then return end
  NPC._teaserLoopStarted = false
  NPC.despawnAll()
end)

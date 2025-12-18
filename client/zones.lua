Zones = Zones or {}

local function getStage(questId)
  if not ClientQuests or not ClientQuests.get then return 0 end
  local st = ClientQuests.get(questId)
  return tonumber(st and st.stage) or 0
end

local function completeStage(questId, setStage)
  TriggerServerEvent("plague_npc_quest:quests:setStage", {
    questId = questId,
    stage = setStage
  })
end

function Zones.Init()
  if not Config.Zones or not lib or not lib.zones then
    Util.dbg("^1Zones:^7 ox_lib zones not available / Config.Zones missing")
    return
  end

  local z = Config.Zones.IntroLifeInvader
  if not z then
    Util.dbg("^3Zones:^7 No Config.Zones.IntroLifeInvader")
    return
  end

  -- Ensure we have state locally (optional)
  if ClientQuests and ClientQuests.request then
    ClientQuests.request(z.questId)
  end

  if z.type == "box" then
    lib.zones.box({
      coords = z.coords,
      size = z.size,
      rotation = z.rotation or 0.0,
      debug = Config.Debug or false,

      onEnter = function()
        -- Only complete when at required stage
        if getStage(z.questId) == (z.requiredStage or 1) then
          Util.dbg("Zone entered -> completing quest:", z.questId, "to stage", z.setStage)
          completeStage(z.questId, z.setStage or 2)

          if lib.notify then
            lib.notify({
              title = "Quest Updated",
              description = "Objective completed.",
              type = "success"
            })
          end
        end
      end
    })
  else
    Util.dbg("^1Zones:^7 Unsupported zone type:", tostring(z.type))
  end
end

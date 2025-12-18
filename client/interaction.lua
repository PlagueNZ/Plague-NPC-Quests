Interaction = Interaction or {}
Interaction.targetsAdded = Interaction.targetsAdded or {} -- [id] = true

local function getPedById(id)
  if not NPC or not NPC.spawned then return nil end
  local ped = NPC.spawned[id]
  if ped and DoesEntityExist(ped) then return ped end
  return nil
end

local function onInteract(npcId)
  Util.dbg("INTERACT -> npcId=", npcId)
    Dialogue.start(npcId)
end

local function addTargetForNpc(def)
  if not def or not def.id then return end
  if Interaction.targetsAdded[def.id] then return end

  local ped = getPedById(def.id)
  if not ped then
    Util.dbg("Target delayed (ped not ready):", def.id)
    return
  end

  local label = def.interactionLabel or "Talk"
  local icon = def.interactionIcon or "fa-solid fa-comments"
  local dist = (Config and Config.TargetDistance) or 2.0

  if exports.ox_target then
    exports.ox_target:addLocalEntity(ped, {
      {
        name = ("plague_npc_%s"):format(def.id),
        icon = icon,
        label = label,
        distance = dist,
        onSelect = function()
          onInteract(def.id)
        end
      }
    })

    Interaction.targetsAdded[def.id] = true
    Util.dbg("ox_target added:", def.id)
    return
  end

  Interaction.targetsAdded[def.id] = true
  Util.dbg("ox_target not found; fallback keypress enabled for:", def.id)
end


function Interaction.initTargets()
  if not Config or not Config.NPCs then return end

  for _, def in pairs(Config.NPCs) do
    addTargetForNpc(def)
  end
end

-- Keep trying until peds exist (NPC spawns happen after session start)
CreateThread(function()
  while true do
    Wait(1000)
    Interaction.initTargets()
  end
end)

-- Safety cleanup (not strictly required for localEntity targets, but good hygiene)
AddEventHandler("onResourceStop", function(res)
  if res ~= GetCurrentResourceName() then return end
  Util.dbg("interaction.lua stopping")
end)

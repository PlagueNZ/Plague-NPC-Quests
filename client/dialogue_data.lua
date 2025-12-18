DialogueData = DialogueData or {}
DialogueData.npcs = {}

local resourceName = GetCurrentResourceName()

local function loadJson(path)
  local raw = LoadResourceFile(resourceName, path)
  if not raw then
    Util.dbg("^1[PLAGUE_NPC_QUEST]^7 Failed to load:", path)
    return nil
  end

  local ok, data = pcall(json.decode, raw)
  if not ok then
    Util.dbg("^1[PLAGUE_NPC_QUEST]^7 Invalid JSON:", path)
    return nil
  end

  return data
end

function DialogueData.loadAll()
  DialogueData.npcs = {}

  if not Config.DialogueFiles then
    Util.dbg("^1[PLAGUE_NPC_QUEST]^7 Config.DialogueFiles missing")
    return
  end

  for _, path in ipairs(Config.DialogueFiles) do
    local quest = loadJson(path)
    if quest and quest.npcs then
      for _, npc in ipairs(quest.npcs) do
        if DialogueData.npcs[npc.id] then
          Util.dbg("^3[PLAGUE_NPC_QUEST]^7 Duplicate npcId:", npc.id, "in", path)
        end
        DialogueData.npcs[npc.id] = npc
      end
    end
  end

  Util.dbg("^2[PLAGUE_NPC_QUEST]^7 Loaded quest NPCs:",
    json.encode(DialogueData.npcs, { indent = true })
  )
end

function DialogueData.getNpc(npcId)
  return DialogueData.npcs[npcId]
end

CreateThread(function()
  Wait(0)
  DialogueData.loadAll()
end)

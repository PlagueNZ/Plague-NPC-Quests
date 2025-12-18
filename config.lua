Config = {}

-- =========================
-- Core
-- =========================
Config.Debug = false
Config.Locale = 'en'
Config.TargetDistance = 2.0

-- Money item name (server-dependent)
Config.Money = "black_money"

-- =========================
-- NPC Attention (Teaser)
-- =========================
Config.Attention = {
  enabled = true,
  range = 25.0,
  minDelayMs = 5000
}

-- =========================
-- NPC Definitions
-- =========================
Config.NPCs = {
  Teaser = {
    id = 'teaser',
    model = `a_m_y_business_01`,
    coords = vec4(-1031.0586, -2736.4138, 20.2144, 141.9856),
    scenario = 'WORLD_HUMAN_CHEERING',
    interactionLabel = 'Talk',
    interactionIcon = 'fa-solid fa-comment'
  },

  Giver = {
    id = 'giver',
    model = `s_m_m_highsec_01`,
    coords = vec4(-1088.3356, -252.9595, 37.7633, 281.3287),
    scenario = 'WORLD_HUMAN_CLIPBOARD',
    interactionLabel = 'Talk',
    interactionIcon = 'fa-solid fa-circle-question'
  }
}

Config.DialogueFiles = {
  'quests/intro.json',
  'quests/hobo_king.json'
}
-- =========================
-- QUEST PARAMETERS (ALL IN ONE PLACE)
-- =========================
Config.QuestParameters = {
  intro = {
    tier = 0,
    status = {
      name = "Intro",
      stages = {
        [0] = "Not started",
        [1] = "Go to Life Invader",
        [2] = "Completed"
      }
    }
    -- no completionStage/xpReward here (teaser only)
  },

  hobo_king = {
    tier = 0,
    completionStage = 2,
    xpReward = 3,

    payments = {
      hobo_king = {
        items = {
          plastic = 50
        },
        money = 2000,
        onSuccess = {
          setStage = 2
        }
      }
    },

    status = {
      name = "Hobo King",
      stages = {
        [0] = "Not started",
        [1] = "Payment required",
        [2] = "Completed"
      },
      paymentStages = {
        [1] = "hobo_king"
      }
    }
  }
}

Config.Zones = {
  IntroLifeInvader = {
    questId = "intro",
    requiredStage = 1,
    setStage = 2,

    -- Box zone at the doorway (you’ll replace these with your coords)
    type = "box",
    coords = vec3(-1082.6998, -258.8441, 37.7633),
    size = vec3(2.8, 2.0, 2.0),
    rotation = 27.0
  }
}


-- =========================
-- XP SYSTEM (GLOBAL)
-- =========================
Config.XP = {
  Enabled = true,

  TierThresholds = {
    [0] = 0,
    [1] = 10,
    [2] = 20,
    [3] = 30
  }
}

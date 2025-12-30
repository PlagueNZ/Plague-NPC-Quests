fx_version 'cerulean'
game 'gta5'

author 'Plague'
description 'NPC Quest System'
version '1.3.8'

lua54 'yes'

shared_scripts {
  '@ox_lib/init.lua',
  'config.lua',
  'config_notifs.lua',
  'shared/util.lua',
}

client_scripts {
  'client/camera.lua',
  'client/nui.lua',
  'client/dialogue_data.lua',
  'client/dialogue.lua',
  'client/npc.lua',
  'client/interaction.lua',
  'client/zones.lua',
  'client/c_quests.lua',
  'client/cl_boosting_jobs.lua',
  'cl_main.lua',
}

server_scripts {
  '@oxmysql/lib/MySQL.lua',
  'server/s_quests.lua',
  'server/version.lua',
  'server/s_boosting_jobs.lua',
  'server/notify.lua',
  'server/s_main.lua',
}

ui_page 'html/index.html'

files {
  'html/index.html',
  'html/style.css',
  'html/app.js',

  'quests/*.json',
  'locales/*.json',
}

dependencies {
  'ox_lib',
  'ox_target',
  'oxmysql'
}

exports {
    'useCarHackingUSB',
    'useLockpick'
}
escrow_ignore {
  'config.lua',
  'quests/*.json',
  'fuckyou.txt'
}
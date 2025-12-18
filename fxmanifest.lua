fx_version 'cerulean'
game 'gta5'

author 'Plague'
description 'NPC Quest System'
version '1.7'

lua54 'yes'

shared_scripts {
  '@ox_lib/init.lua',
  'config.lua',
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
  'client/quests.lua',
  'cl_main.lua',
}

server_scripts {
  '@oxmysql/lib/MySQL.lua',
  'server/quests.lua',
  'server/version.lua',
  
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

escrow_ignore {
  'config.lua',
  'quests/*.json',
}
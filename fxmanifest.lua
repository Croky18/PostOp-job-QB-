fx_version 'cerulean'
game 'gta5'
lua54 'yes'
author 'Leagcy-Shop'
description 'EletroJob'
version '1.0.0'

dependency 'qb-core'
dependency 'ox_lib'


shared_script 'config.lua'

client_script 'client/main.lua'

server_script 'server/main.lua'

shared_script '@ox_lib/init.lua'
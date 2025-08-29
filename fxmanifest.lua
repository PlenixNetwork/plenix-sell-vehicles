fx_version 'cerulean'
game 'gta5'

author 'Plenix Network'
description 'Players sell their vehicles to other players.'
version '2.0.0'

lua54 'yes'

shared_scripts {
    '@es_extended/imports.lua',
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    '/client/**.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    '/server/**.lua',
}

files {
    'locales/*.json'
}

dependencies {
    'oxmysql',
    'ox_lib',
    'es_extended',
}
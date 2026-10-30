resource_manifest_version '44febabe-d386-4d18-afbe-5e627f4af937'

author 'Catusse'
description 'Haze Anti-Cheat'
version '2.0.0'

server_scripts {
    'haze_cfg.lua',
    'protected/server-side/haze_s.lua'
}

client_scripts {
    'haze_cfg.lua',
    'protected/client-side/haze_c.lua',
    'protected/client-side/haze_native.lua'
}

files {
    'haze_ac_bans.json',
    'haze_ac_logs.json',
    'haze_ac_admin_whitelist.json',
    'native-module/haze_security.dll'
}
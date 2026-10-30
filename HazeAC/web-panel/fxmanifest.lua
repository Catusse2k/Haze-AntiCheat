resource_manifest_version '44febabe-d386-4d18-afbe-5e627f4af937'

description 'HazeAC Admin Panel - React TypeScript NUI'
version '1.0.0'
author 'HazeAC'

ui_page 'hazeac-panel' 'html/index.html'

client_script 'client-side/haze_nui_client.lua'

server_script 'server-side/haze_nui_bridge.lua'

files {
    'nui/hazeac-panel.js',
    'nui/hazeac-panel.css'
}

dependencies {
    '/server:5848',
    '/onesync'
}

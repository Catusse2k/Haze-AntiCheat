# Haze Anti-Cheat | FiveM

**A layered anti-cheat for FiveM: Lua behavioral detection, server-side cross-validation, token-protected events, a native C++ security module, and an in-game admin panel.**

![Platform](https://img.shields.io/badge/platform-FiveM-orange)
![Language](https://img.shields.io/badge/lua-5.4-blue)
![Native](https://img.shields.io/badge/native-C%2B%2B17%20(x64)-informational)
![Version](https://img.shields.io/badge/version-2.0.0-green)

---

## Table of Contents

1. [Overview](#1-overview)
2. [Features](#2-features)
3. [Detection Coverage and Limitations](#3-detection-coverage-and-limitations)
4. [Repository Structure](#4-repository-structure)
5. [Requirements](#5-requirements)
6. [Installation (Step by Step)](#6-installation-step-by-step)
7. [Configuration](#7-configuration)
8. [Admin Commands](#8-admin-commands)
9. [Event Protection System (Tokens)](#9-event-protection-system-tokens)
10. [Developer API (Exports)](#10-developer-api-exports)
11. [Native C++ Security Module](#11-native-c-security-module)
12. [Admin Web Panel (NUI)](#12-admin-web-panel-nui)
13. [Code Protection: Escrow and Obfuscation](#13-code-protection-escrow-and-obfuscation)
14. [Performance Design](#14-performance-design)
15. [Troubleshooting and FAQ](#15-troubleshooting-and-faq)
16. [Best Practices](#16-best-practices)
17. [Roadmap](#17-roadmap)
18. [License and Support](#18-license-and-support)

---

## 1. Overview

HazeAC v2.0 is a complete refactoring of the original HazeAC resource. It was redesigned around four goals:

- **Fewer false positives** through realistic thresholds, grace periods and context awareness.
- **Better server and client performance** through fewer threads, batched network events and asynchronous I/O.
- **Real checks instead of security theater**: ineffective detections were removed and replaced with server-side validation and behavioral analysis.
- **Defense in depth**: Lua heuristics, token-protected events, a native C++ module and human moderation working together.

> **Important:** HazeAC is a script-level anti-cheat with an optional native module. It is a strong first layer, not a silver bullet. See [Detection Coverage and Limitations](#3-detection-coverage-and-limitations).

---

## 2. Features

### Native C++ security module
- Low-level behavioral scanning outside the Lua runtime (`haze_security.dll`).
- Detects remote debuggers, inline hooks in system DLLs, unsigned modules, suspicious thread injection and dangerous external process handles.
- All native detections result in an immediate permanent ban.
- Admin whitelist to avoid false positives during development.

### Event protection with tokens
- Token-based validation prevents unauthorized remote triggering of your server events.
- Global rate limiting by event type and player.
- Client-side token caching to reduce overhead.
- Ready-made exports for custom events; examples for Qbox, QBcore, ESX and OxLib.

### Client-side optimization
- Client threads reduced from **12 to 4**.
- Data is accumulated in buffers and sent in **5-second batches**.
- Network traffic reduced from roughly **500 to 50 events/s** (with 50 players).
- Longer, documented intervals (see [Configuration](#7-configuration)).

### Reduced false positives
- Higher thresholds, grace periods and multi-violation requirements before a strike.
- Context awareness for parachutes, falling and vehicles.
- Improved strike system (higher threshold, longer decay, longer session grace).

### Aggressive server-side validation
- **Cross-player distance verification**: the server computes the real attacker-to-victim distance.
- **Damage mismatch detection**: client-reported vs. server-computed distance (±30 m tolerance).
- **Statistical damage analysis** over 60 seconds to detect persistent anomalies.
- **Impossible distance check**: damage dealt beyond 200 m triggers an immediate strike.
- **High-damage counter**: 5+ hits above the ceiling before a strike.

### Behavioral anomaly detection
- Movement pattern analysis (12 position samples over 60 seconds).
- Average-speed analysis (flags sustained speeds above 100 m/s).
- Persistent position history for temporal analysis.

### Operations tooling
- Admin commands, ban management and strike management.
- Asynchronous, non-blocking ban storage with a 60-second ban-check cache.
- In-game React/TypeScript admin panel (NUI).
- Framework-agnostic: works with ESX Legacy, QBcore, Qbox or standalone.

---

## 3. Detection Coverage and Limitations

### What HazeAC can detect

| Detection | Notes |
|---|---|
| Speedhack | Context-aware |
| Teleport | Grace period and pattern analysis |
| Godmode | Frozen health, invincibility flag |
| Noclip | Floating without falling |
| Super jump | Anomalous vertical velocity |
| Magic bullet | Wall penetration via line-of-sight check |
| Silent aim | Anomalous hit ratio with cross-validation |
| Triggerbot | Fire-rate and reaction-time analysis |
| Aimbot | Angular velocity analysis and camera snap |
| Weapon / vehicle blacklist | Unauthorized weapons and vehicles |
| Explosion spam | Rate limiting |
| Behavioral anomalies | Unnatural movement patterns |
| Remote debuggers | Via native module |
| Process handle violations | External memory access, via native module |
| Inline hooks | Hooked system functions, via native module |
| Unsigned modules | Untrusted DLL signatures, via native module |
| Thread injection | Suspicious thread start addresses, via native module |

### What HazeAC cannot detect

- Kernel-level cheats (would require a kernel driver).
- Advanced memory manipulation (requires kernel-level protection).
- Sophisticated DLL hiding that evades module scanning.
- Advanced spoofing.
- ESP/wallhack (requires more advanced heuristics).
- Network-level attacks (require server-side/infra protection).

### Checks intentionally removed in v2.0

These were disabled or removed because they were ineffective, trivially bypassable or caused lag without real value:

- Resource scan via `GetNumResources()` (does not detect real injections).
- Model/RPF checks via `IsModelInCdimage()` (easily bypassable).
- DOM / NUI / DOM-mutation checks (too superficial for modern cheats).
- Particle, scenario and entity-count checks.
- Fake-hash HWID (replaced by a focus on `license2` and tokens).
- Blacklist-based process detection in the native module (modern cheats disguise themselves as legitimate processes; the module now relies on behavioral analysis).

---

## 4. Repository Structure

```
HazeAC/
├── __resource.lua / fxmanifest.lua   # Resource manifest
├── haze_cfg.lua                      # Configuration (the ONLY file you should edit)
├── protected/                        # Escrow-protected core logic (do not edit)
│   ├── client-side/
│   │   ├── haze_c.lua                # Core anti-cheat logic
│   │   └── haze_native.lua           # Bridge to the native module
│   └── server-side/
│       └── haze_s.lua                # Server validation and ban logic
├── client-side/                      # Original client sources (reference only)
├── server-side/                      # Original server sources (reference only)
├── boilerplate/
│   └── haze_framework_bridge.lua     # Framework bridge (ESX/QB/Qbox), editable
├── native-module/
│   ├── haze_security.cpp             # Native module source
│   ├── HazeSecurity.vcxproj          # Visual Studio project
│   └── haze_security.dll             # Compiled DLL (you build/provide this)
├── web-panel/                        # React + TypeScript admin panel (NUI)
│   ├── src/                          # App.tsx, components/AdminPanel.tsx, utils/fetchNui.ts, main.tsx
│   ├── server-side/haze_nui_bridge.lua
│   └── client-side/haze_nui_client.lua
├── integration_examples.lua          # Framework integration and event-protection examples
├── haze_ac_bans.json                 # Ban database (generated)
└── haze_ac_logs.json                 # Logs (generated)
```

> The exact layout may vary slightly between releases. The rule that matters: **edit `haze_cfg.lua` only**, and never edit files in `protected/`.

---

## 5. Requirements

| Component | Requirement |
|---|---|
| Server | A FiveM server (artifact with Lua 5.4 support) |
| Clients | Windows (native module is Windows-only, x64) |
| Native module build (optional) | Visual Studio 2022 (or 2019 with C++17), Windows 10 SDK, CMake 3.15+ (optional) |
| Web panel build (optional) | Node.js and npm |
| Obfuscation (optional) | Lua and LuaRocks (for the obfuscator) |

---

## 6. Installation (Step by Step)

### Step 1: Install the resource

1. Copy the entire `HazeAC` folder into your server `resources` directory. The resource name must be **`haze_ac`** (the exports and events rely on it).
2. Add the resource to your `server.cfg`:

   ```cfg
   ensure haze_ac
   ```

### Step 2: Configure

Open `haze_cfg.lua` and adapt thresholds and punishments to your server. See [Configuration](#7-configuration) for recommended presets.

### Step 3: Verify the manifest

The manifest must reference the configuration and the protected files:

```lua
resource_manifest_version '44febabe-d386-4d18-afbe-5e627f4af937'

author 'Catusse'
description 'Haze Anti-Cheat v2.0'
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
    'haze_cfg.lua',
    'haze_ac_bans.json',
    'haze_ac_logs.json',
    'native-module/haze_security.dll'
}
```

### Step 4: Whitelist yourself (important)

To avoid banning yourself while testing, whitelist your admin license (see [Admin whitelist](#admin-whitelist)):

```
hazeac_whitelist_add license2:xxxxxxxxxxxxxxxx
```

You can read your `license2` from the server console when you connect.

### Step 5 (optional): Build the native C++ module

Follow [Section 11](#11-native-c-security-module) and place `haze_security.dll` in `native-module/`.

### Step 6 (optional): Build the admin web panel

Follow [Section 12](#12-admin-web-panel-nui).

### Step 7 (recommended for production): Obfuscate the client code

Follow [Section 13](#13-code-protection-escrow-and-obfuscation).

### Step 8: Start and verify

1. Start (or restart) the server.
2. Confirm in the console that `haze_ac` started without errors.
3. Run `/haze_ac_status` and check that statistics are displayed.
4. Review `haze_ac_logs.json` periodically for false positives during the first days.

---

## 7. Configuration

All settings live in **`haze_cfg.lua`**, exposed through the `HazeConfig` table. Example:

```lua
HazeConfig.StrikeThreshold = 5
HazeConfig.Aim.CamSnapAngle = 90.0
```

### Default thresholds (v2.0)

| Setting | v1.0 | v2.0 |
|---|---|---|
| MaxPedSpeed | 30 | 45 m/s |
| MaxVehicleSpeed | 120 | 150 m/s |
| MaxTeleportDistance | 250 | 400 m |
| MaxSuperJumpHeight | 15 | 25 m/s |
| CamSnapAngle | 45 | 90° |
| CamSnapVertical | 80 | 120° |
| No-ragdoll counter | 3 | 10 |
| Frozen-health counter | 20 | 50 |
| Vehicle-godmode counter | 3 | 10 |
| Strike threshold | 3 | 5 |
| Strike decay time | 90 s | 180 s |
| Session grace | 20 s | 30 s |

Grace periods: 5 seconds of tolerance after teleport violations, and 2-3 violations are required before a strike is issued.

### Default intervals

| Check | v1.0 | v2.0 |
|---|---|---|
| Heartbeat | 800 ms | 2000 ms |
| State report | 500 ms | 1000 ms |
| Camera check | 200 ms | 300 ms |
| Shot check | 60 ms | 100 ms |
| Batched event flush | n/a | 5000 ms |

### Recommended presets

**Light RP server (1-30 players)**
```lua
HazeConfig.StrikeThreshold = 5
HazeConfig.StrikeDecayTime = 180000        -- 3 minutes
HazeConfig.SessionGrace = 30000            -- 30 seconds
HazeConfig.PunishAction = 'kick'
```

**Heavy RP server (30-100 players)**
```lua
HazeConfig.StrikeThreshold = 7
HazeConfig.StrikeDecayTime = 300000        -- 5 minutes
HazeConfig.SessionGrace = 45000            -- 45 seconds
HazeConfig.PunishAction = 'ban'
HazeConfig.PunishDuration = 86400          -- 24 hours
```

**Competitive server (high security)**
```lua
HazeConfig.StrikeThreshold = 4
HazeConfig.StrikeDecayTime = 120000        -- 2 minutes
HazeConfig.SessionGrace = 20000            -- 20 seconds
HazeConfig.PunishAction = 'ban'
HazeConfig.PunishDuration = 0              -- permanent
```

### Tuning tips

- **Too many false positives?** Raise `StrikeThreshold` to 7-10, raise `SessionGrace` to 45-60 s, disable problematic checks, or use `PunishAction = 'kick'` while you tune.
- **Server lag?** Make sure you are not running other script-based anti-cheats, raise the values in `HazeConfig.Intervals`, or reduce the number of monitored players.
- **Cheats not detected?** Confirm the resource loaded correctly, check for accidental whitelists, and remember that injection-based cheats are outside the scope of the Lua layer.

---

## 8. Admin Commands

All commands are server-side/admin commands.

| Command | Description |
|---|---|
| `/haze_ac_status` | Show anti-cheat statistics |
| `/haze_ac_check [id]` | Show details for a player |
| `/haze_ac_ban [id] [duration] [reason]` | Manually ban a player |
| `/haze_ac_unban [license/hwid/name]` | Unban a player |
| `/haze_ac_banlist [page]` | List bans |
| `/haze_ac_baninfo [id]` | Detailed ban information |
| `/haze_ac_whitelist [id]` | Whitelist a player |
| `/haze_ac_unwhitelist [id]` | Remove a player from the whitelist |
| `/haze_ac_reset [id]` | Reset a player's strikes |
| `/haze_ac_punish [ban\|kick\|duration]` | Change the punishment action |
| `/haze_ac_scan` | Manual resource scan |
| `/haze_ac_ensure [resource]` | Ensure a critical resource is running |
| `/hazeac_panel` | Open the admin panel (requires `haze_ac.admin` ACE) |

### Admin whitelist

Administrators can be exempted from **native module** detections, which is essential during development and testing:

```
hazeac_whitelist_add license2:your_license_here
hazeac_whitelist_remove license2:your_license_here
```

Run these from the server console or RCON. Entries are stored in `haze_ac_admin_whitelist.json`:

```json
{
  "whitelist": {
    "license2:abc123def456": true,
    "license2:xyz789uvw012": true
  }
}
```

---

## 9. Event Protection System (Tokens)

Cheaters can trigger your server events directly. HazeAC lets you require a short-lived, server-validated token on any critical event.

### Protecting a custom event

**Server-side**
```lua
RegisterNetEvent('myResource:doSomething', function(token, data)
    if not exports.haze_ac:validateToken(source, 'myResource:doSomething', token) then
        return -- Unauthorized event
    end
    -- Event logic here
end)
```

**Client-side**
```lua
exports.haze_ac:triggerProtectedEvent('myResource:doSomething', data)
```

### How it works

- The server generates a signature from the player's `license2`, the event name, a **server timestamp** and a server-side salt (`CFG.HwidSalt`), then hashes it into a token.
- Tokens are valid for **15 seconds** (server timestamp based, to tolerate latency and client timer drift).
- The client caches tokens for **12 seconds** to avoid repeated requests.
- Events can additionally be rate-limited per event type and per player using `checkEventRate`.

> Set a strong, unique, private value for `HwidSalt` in your configuration.

See `integration_examples.lua` for complete Qbox, QBcore, ESX and OxLib examples.

---

## 10. Developer API (Exports)

### Server-side

```lua
-- Generate a token for an event
local token = exports.haze_ac:generateToken(playerId, 'eventName')

-- Validate a token received from a client
local valid = exports.haze_ac:validateToken(playerId, 'eventName', token)

-- Get a player's strike count
local strikes = exports.haze_ac:getPlayerStrikes(playerId)

-- Check if a player has a specific strike type
local hasStrike = exports.haze_ac:hasStrike(playerId, 'aimbot')

-- Check if a player is banned
local banned = exports.haze_ac:isBanned(playerId)

-- Add a custom strike
exports.haze_ac:addCustomStrike(playerId, 'Reason', 'customType')

-- Check an event rate limit
local allowed = exports.haze_ac:checkEventRate(playerId, 'eventName')
```

### Client-side

```lua
-- Get a token (cached when possible)
local token = exports.haze_ac:getToken('eventName')

-- Request a token asynchronously
exports.haze_ac:requestToken('eventName', function(token)
    -- Use the token here
end)

-- Trigger a protected event
exports.haze_ac:triggerProtectedEvent('eventName', arg1, arg2, ...)
```

### Exports used by the web panel

`getPlayerStrikes`, `getHwid`, `banPlayer`, `unban`, `resetStrikes`.

---

## 11. Native C++ Security Module

`haze_security.dll` is a native Windows DLL that scans at a level the Lua runtime cannot reach.

### Detection types

| ID | Name | Description |
|---|---|---|
| 0 | None | No detection |
| 1 | Remote Debugger | A debugger is attached to the process |
| 2 | Inline Hook | Hook detected in a system DLL |
| 3 | Unsigned Module | Unsigned module loaded outside trusted paths |
| 4 | Thread Injection | Suspicious thread injection |
| 5 | Process Handle Violation | External process holds a dangerous handle to FiveM |

Every native detection results in an **immediate permanent ban**, unless the player is on the admin whitelist.

### Building the DLL

**Method 1: Visual Studio (recommended)**
1. Open `HazeSecurity.vcxproj` in Visual Studio 2022.
2. Set the configuration to **Release | x64**.
3. Build (F7, or *Build > Build Solution*).
4. Take the DLL from `build/haze_security.dll`.

**Method 2: CMake**
```bash
mkdir build
cd build
cmake .. -G "Visual Studio 17 2022" -A x64
cmake --build . --config Release
```

Then copy the DLL to **`HazeAC/native-module/haze_security.dll`**. The manifest `files` block must include it (see [Step 3](#step-3-verify-the-manifest)).

### Lua integration

The bridge (`haze_native.lua`) runs periodic scans (default every **5 seconds**) and reports to the server together with a validated token:

```lua
local scanInterval = 5000 -- milliseconds

TriggerServerEvent('haze_ac:nativeDetection', token, {
    detectionType = detectionType,
    detectedProcess = detectedProcess,
    detectedDLL = detectedDLL,
    detectionTime = detectionTime
})
```

The server handler checks the admin whitelist, validates the token, then bans:

```lua
RegisterNetEvent('haze_ac:nativeDetection')
AddEventHandler('haze_ac:nativeDetection', function(token, detectionData)
    if isAdminWhitelisted(pId) then return end
    if not exports.haze_ac:validateToken(pId, 'haze_ac:native_scan', token) then return end
    banPlayer(pId, reason, 0, 'native_module')
end)
```

### Customization

Allow-listing a safe process (edit `native-module/haze_security.cpp`, then rebuild):

```cpp
void initializeWhitelist() {
    whitelistProcesses = {
        "chrome.exe",
        "your_safe_process.exe",  // add here
    };
}
```

For debugging, add logging in the C++ code and rebuild in the **Debug** configuration:

```cpp
printf("[HazeSecurity] Scan result: %s\n", isClean ? "clean" : "dirty");
```

### Performance impact

- CPU: low. Memory: about 2 MB. Network: a single event, only on detection.

### Native module troubleshooting

| Symptom | Cause | Solution |
|---|---|---|
| `[HazeAC Native] ERROR: Failed to load haze_security.dll` | DLL missing or wrong path | Ensure it is at `native-module/haze_security.dll` and dependencies are present |
| Legitimate players banned | Safe process not recognized | Add it to the C++ whitelist and rebuild, or whitelist the admin with `hazeac_whitelist_add` |
| Linker errors or missing libraries (build) | Missing Windows SDK or wrong platform | Install the Windows 10 SDK and select **x64** |
| Scan fails with access denied | Antivirus or permission issues | Exclude the server directory from antivirus; run with suitable permissions |

### Limitations

- Windows clients only; x64 required.
- Cannot detect kernel-level cheats.
- Can be bypassed by advanced users (hidden processes, in-memory patching, blocked DLL loading).
- Windows Defender may flag the DLL; whitelist your server directory.

---

## 12. Admin Web Panel (NUI)

A React + TypeScript + Tailwind CSS panel that runs **in-game** through FiveM's NUI system. It is not a standalone web application.

### Features

- Real-time statistics: online players, monitored players, active strikes, total bans, punish action, ban duration.
- Player management: list connected players, view strikes by type, ban with a custom reason and duration, reset strikes.
- Ban management: list active bans, filter by name/HWID/license, unban, view expiration dates.

### Installation

1. Build the panel:
   ```bash
   cd web-panel
   npm install
   npm run build
   ```
   This generates the `nui` folder with the compiled JavaScript and CSS.

2. Copy the panel to your resources directory:
   ```bash
   cp -r web-panel /path/to/server/resources/haze_ac_panel
   ```

3. Add it to `server.cfg` (after `haze_ac`):
   ```cfg
   ensure haze_ac_panel
   ```

4. Grant permissions (replace `xxxxxx` with your admin license, or use group principals):
   ```cfg
   add_ace resource.haze_ac_panel command.hazeac_panel allow
   add_ace identifier.license:xxxxxx haze_ac.admin allow
   ```

### Usage

Open the panel in-game with `/hazeac_panel` (or `/hazeac panel`). It requires the `haze_ac.admin` ACE permission and refreshes automatically every 5 seconds via client-side polling (adjustable in `components/AdminPanel.tsx`).

### Architecture

- **Frontend:** `web-panel/src/` (`App.tsx`, `components/AdminPanel.tsx`, `utils/fetchNui.ts`, `main.tsx`).
- **NUI bridge:** `server-side/haze_nui_bridge.lua` and `client-side/haze_nui_client.lua`. Standalone; works with ESX Legacy, QBcore, Qbox or no framework.
- If HazeAC exports are unavailable, the bridge falls back to manual file operations for bans.

### Extending the panel

1. Register a new NUI callback in `server-side/haze_nui_bridge.lua`:
   ```lua
   RegisterNUICallback('myNewFeature', function(data, cb)
       -- Your logic here
       cb(result)
   end)
   ```
2. Call it from React:
   ```typescript
   const result = await fetchNui('myNewFeature', data)
   ```
3. Update the UI in `components/AdminPanel.tsx` and run `npm run build`.

For styling, edit `tailwind.config.js` and rebuild. For development, run `npm run dev` (Vite HMR is disabled for FiveM compatibility; refresh manually).

### Security

- Every operation requires the `haze_ac.admin` ACE permission.
- Bans pass through HazeAC validation; the panel has no direct database access.
- NUI callbacks are validated server-side.

### Panel troubleshooting

| Symptom | Check |
|---|---|
| Panel won't open | The panel resource is started; you hold `haze_ac.admin`; the `nui` folder exists (build ran) |
| Data not loading | HazeAC is running; browser/NUI console for JavaScript errors; FiveM console for Lua errors |
| Bans not persisting | Write permission on `haze_ac_bans.json`; correct file path; no other anti-cheat writing to the same file |

Browser compatibility: FiveM's CEF (Chromium-based) supports everything required.

---

## 13. Code Protection: Escrow and Obfuscation

### Escrow model

Detection logic is kept out of reach of players and casual editing:

| Path | Purpose | Editable? |
|---|---|---|
| `haze_cfg.lua` | Configuration | **Yes (the only one)** |
| `protected/client-side/haze_c.lua` | Core client logic | No |
| `protected/client-side/haze_native.lua` | Native bridge | No |
| `protected/server-side/haze_s.lua` | Server validation and bans | No |
| `client-side/`, `server-side/` | Original sources, reference only | No |
| `boilerplate/haze_framework_bridge.lua` | Framework bridge | Yes, if needed |
| `integration_examples.lua`, Markdown docs | Examples and documentation | Yes |

**Why:** protects detection logic from being read or tampered with, makes bypasses harder, and keeps integrity (users change config values, not logic). Editing detection logic directly can introduce false positives, create bypasses or vulnerabilities, and break compatibility with future updates.

**Verifying the escrow setup**
1. `haze_cfg.lua` is plain text.
2. Other Lua files are obfuscated in production.
3. The manifest points to the obfuscated client file.
4. Configuration changes work without any code change.

### Why obfuscate the client

Client Lua is readable by cheaters, who can study heuristics and thresholds. Obfuscation raises the cost of bypassing and of copying your work. It is **an additional layer, not complete protection**: a determined attacker can still decompile, monitor network traffic or inject code.

### Recommended tools

- **LuaObfuscator** (recommended): FiveM-compatible, Lua 5.3/5.4, configurable, open source. https://github.com/gladius900/lua-obfuscator
- **IronBrew2**: very aggressive with anti-tamper, but larger output, slower and harder to configure. https://github.com/Upio/lua-ironbrew

LuaObfuscator setup:
```bash
git clone https://github.com/gladius900/lua-obfuscator.git
cd lua-obfuscator
luarocks install --only-deps --local
```

### Obfuscation procedure

```bash
# 1. ALWAYS back up the readable source first
cp client-side/haze_c.lua client-side/haze_c.lua.backup

# 2. Obfuscate the protected client file
lua build.lua protected/client-side/haze_c.lua protected/client-side/haze_c.lua.obf
mv protected/client-side/haze_c.lua.obf protected/client-side/haze_c.lua
```

Suggested `config.lua` for the obfuscator:

```lua
return {
    RenameGlobals = true,
    RenameLocals = true,
    EncryptStrings = true,
    Minify = true,

    -- FiveM-specific
    KeepNativeCalls = true,
    KeepExports = true,
    KeepRegisterNetEvent = true,

    -- Anti-decompilation
    AntiTamper = true,
    Watermark = "HazeAC v2.0",

    -- Never obfuscate these
    Whitelist = {
        -- FiveM API
        "CreateThread", "Wait", "Citizen", "exports", "PlayerId",
        "GetCurrentResourceName", "TriggerServerEvent", "RegisterNetEvent",
        "AddEventHandler", "RemoveEventHandler",
        -- Game natives
        "GetPlayerPed", "GetEntityCoords", "GetEntityVelocity", "GetEntityHealth",
        "GetPedArmour", "IsPedFalling", "IsPedRagdoll", "IsPedShooting",
        "GetSelectedPedWeapon", "GetGameplayCamRot", "GetGameTimer",
        -- Network
        "GetPlayerServerId", "GetPlayerFromServerId", "NetworkGetPlayerIndexFromPed",
    }
}
```

### Test after obfuscating

- [ ] The resource loads without errors
- [ ] Client-server events work
- [ ] Basic protections are active
- [ ] The FiveM console shows no errors
- [ ] Logs are being generated
- [ ] `/haze_ac_status` and `/haze_ac_check [id]` return data

### Optional extra hardening

- Split the client into separately obfuscated files (core, movement, combat, events).
- Add a runtime integrity check that compares a hash of the obfuscated file and reports `haze_ac:integrityFailure` on mismatch.
- Dynamic code loading: only with thorough testing, never straight on production.

### Obfuscation issues

| Error | Cause | Solution |
|---|---|---|
| `Failed to load script` | Obfuscation too aggressive | Lower the level, whitelist more functions |
| `Native not found` | Native names were renamed | Add the natives to the whitelist |
| Performance drop | Obfuscation too heavy | Use minify only, or a lower level |
| File too large | IronBrew is verbose | Use LuaObfuscator with minify |

**Do not obfuscate** during active development, while debugging, during code review, or for an open-source release you want to keep readable. Obfuscate on every release, keep the unobfuscated source versioned, back up first, and test before deploying.

---

## 14. Performance Design

### Asynchronous ban I/O
Ban modifications used to write synchronously and could cause lag spikes and race conditions. Bans are now held in memory with a dirty flag and flushed asynchronously every **5 seconds** in a separate thread, with an immediate flush on resource stop. Tune with `database.ioFlushInterval` (e.g. 3000 ms for very busy servers, 10000 ms for quiet ones).

### Ban-check cache
Ban lookups are cached for **60 seconds**, keyed on `license2`, `steam` or `discord`, with hit/miss statistics logged at shutdown. A hit rate above 70% is good and above 80% is excellent. Raise the TTL in `isBanned()` (e.g. 120 s) if the hit rate is low and misses are a real problem.

### Token reliability
Tokens now use server timestamps instead of `GetGameTimer()`, a 15 s validation window and a 12 s client cache. This tolerates latency spikes and client timer drift. If you still see frequent "Invalid token" errors, raise the validation timeout in `validateEventToken()` to 20-30 s and check client performance.

### Graceful shutdown
On resource stop, the pending ban cache is flushed to disk and cache statistics are logged, so no bans are lost on restart. Look for `Ban cache flush complete` in the console.

### Summary

| Area | v1.0 | v2.0 |
|---|---|---|
| Ban I/O | Synchronous, blocking | Asynchronous, non-blocking |
| Ban checks | Full scan every time | 60 s TTL cache |
| Token timeout | 10 s, game timer | 15 s, server timestamp |
| Network events | ~500/s | ~50/s |
| Client threads | 12 | 4 |

Designed to handle 100+ players, frequent ban operations and restarts without data loss.

---

## 15. Troubleshooting and FAQ

**Bans are not persisting after a restart.**
Look for `Ban cache flush complete` in the console, verify write permissions on `haze_ac_bans.json`, and make sure `flushBanCache()` is called on resource stop.

**Cache hit rate is below 50%.**
Possible causes: TTL too short, many unique players, frequent cache invalidation. Increase the TTL to 120 s and check whether it actually matters.

**I banned myself while testing.**
Add your license to the admin whitelist with `hazeac_whitelist_add`, then unban with `/haze_ac_unban`.

**Does HazeAC replace human moderation?**
No. It is a strong first layer; combine it with active moderation, logging and, if needed, other systems (screenshot-based or commercial anti-cheats).

**Does it work with my framework?**
Yes: ESX Legacy, QBcore, Qbox or standalone. Use `boilerplate/haze_framework_bridge.lua` and `integration_examples.lua`.

**Can I edit the detection logic?**
Not recommended and not supported. Use `haze_cfg.lua` for tuning.

---

## 16. Best Practices

1. Tune thresholds to your gameplay instead of using defaults blindly.
2. Start with `kick` while monitoring logs, then move to `ban`.
3. Review logs regularly, especially during the first weeks.
4. **Obfuscate the client code** before going to production.
5. **Protect your critical events** (money, items, jobs) with the token system.
6. Whitelist administrators before testing native detections.
7. Keep the unobfuscated source in version control and back up before every build.
8. Use HazeAC as one layer among several: native detection, behavioral analysis, event protection and human moderation.

---

## 17. Roadmap

- Database backend (MySQL/PostgreSQL) in place of JSON for large servers.
- Distributed cache (e.g. Redis) and shared ban state across multiple servers.
- Pre-generated token pools to reduce network requests.
- Adaptive cache TTL based on hit rate.
- Kernel-level driver support, hardware signature verification, memory-integrity checks.
- Network traffic analysis and machine-learning-assisted detection patterns.

---

## 18. License and Support

This software is provided **"as is"**, without warranties of any kind. The native module and the web panel are part of HazeAC and follow the same license. Add your preferred license text in a `LICENSE` file at the repository root.

**Support**
- Open a GitHub Issue for bugs and feature requests, including your server artifact version, the console output and the relevant lines of `haze_ac_logs.json`.
- For the native module: check the Visual Studio build output, confirm the DLL location and review the server console for Lua errors.
- For the web panel: check the browser/NUI console and the FiveM console.

---

*HazeAC v2.0. Built to raise the cost of cheating on your server, one layer at a time.*

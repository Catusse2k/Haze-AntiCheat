HazeConfig = {}

HazeConfig.LogLevel = 2
HazeConfig.DebugDraw = false

HazeConfig.StrikeThreshold = 5
HazeConfig.StrikeDecayTime = 180000
HazeConfig.SessionGrace = 30000
HazeConfig.PunishAction = 'ban'
HazeConfig.PunishDuration = 0
HazeConfig.KickMessage = 'haze_ac: Violation detected - '
HazeConfig.BanMessage = 'haze_ac: You have been banned - '

HazeConfig.BanFile = 'haze_ac_bans.json'
HazeConfig.LogFile = 'haze_ac_logs.json'
HazeConfig.PersistLogs = true
HazeConfig.HwidSalt = 'change_this_salt_on_each_server_x7f3a9c2'
HazeConfig.CheckBansOnConnect = true
HazeConfig.CheckTokens = true
HazeConfig.CheckHwid = true
HazeConfig.CheckIp = false

HazeConfig.Intervals = {
    HeartbeatClient = 2000,
    HeartbeatScan = 30000,
    StateClient = 1000,
    StateServer = 3000,
    CamClient = 300,
    ShotClient = 100,
    WeaponClient = 5000,
    ResourceClient = 0,
    HealthClient = 0,
    StaminaClient = 2000,
    VisionClient = 3000,
    ResourceScan = 0,
    ManifestCheck = 0,
    Watchdog = 30000,
    EntityCount = 0,
    PendingLosTimeout = 5000,
    NativeScanClient = 5000
}

HazeConfig.Movement = {
    MaxPedSpeed = 45.0,
    MaxVehicleSpeed = 150.0,
    MaxTeleportDistance = 400.0,
    MaxSuperJumpHeight = 25.0,
    MaxVerticalDelta = 60.0,
    NoclipMinHeight = 5.0,
    NoclipMinSpeed = 12.0,
    EnableNoclipCheck = true,
    EnableTeleportCheck = true,
    EnableSpeedCheck = true,
    EnableSuperJumpCheck = true
}

HazeConfig.Aim = {
    CamSnapAngle = 90.0,
    CamSnapVertical = 120.0,
    CamSnapRateLimit = 15,
    CamSnapWindow = 2000,
    EnableAimbotCheck = true,
    EnableSilentAimCheck = true,
    EnableTriggerbotCheck = true,
    EnableTrackingCheck = true
}

HazeConfig.Combat = {
    MaxShotsPerSecond = 15,
    ShotBurstWindow = 70,
    MinShotsForRatio = 10,
    MaxHitRatio = 0.95,
    MinShotsForHeadshot = 15,
    MaxHeadshotRatio = 0.90,
    MinShotsForTracking = 8,
    TrackingAccuracy = 0.92,
    TrackingDistance = 150.0,
    MaxDamagePerHit = 500,
    DamageCeilingMultiplier = 1.35,
    EnableDamageCheck = true,
    EnableRatioCheck = true,
    EnableHeadshotCheck = true
}

HazeConfig.Health = {
    MaxHealth = 200,
    MaxArmor = 100,
    MaxHealthOverflow = 250,
    MaxArmorOverflow = 150,
    MaxNoRagdollChecks = 5,
    FrozenHealthThreshold = 20,
    EnableGodmodeCheck = true,
    EnableOverflowCheck = true,
    EnableNoRagdollCheck = true,
    EnableVehicleGodmodeCheck = true
}

HazeConfig.Weapons = {
    MaxAmmoPerWeapon = 250,
    MaxTotalAmmo = 1000,
    MaxAmmoIncrease = 200,
    MaxWeaponCount = 8,
    GiveWeaponGrace = 3000,
    EnableBlacklist = true,
    EnableAmmoCheck = true,
    EnableInventoryCheck = true,
    Blacklist = {
        [`WEAPON_RAILGUN`] = true,
        [`WEAPON_RPG`] = true,
        [`WEAPON_MINIGUN`] = true,
        [`WEAPON_HOMINGLAUNCHER`] = true,
        [`WEAPON_GRENADELAUNCHER`] = true,
        [`WEAPON_GRENADELAUNCHER_SMOKE`] = true,
        [`WEAPON_FIREWORK`] = true,
        [`WEAPON_EMPLAUNCHER`] = true,
        [`WEAPON_STINGER`] = true,
        [`WEAPON_SNOWLAUNCHER`] = true,
        [`WEAPON_RAYMINIGUN`] = true,
        [`WEAPON_RAYPISTOL`] = true,
        [`WEAPON_RAYCARBINE`] = true,
        [`WEAPON_DIGISCANNER`] = true,
        [`WEAPON_CERAMICPISTOL`] = true,
        [`WEAPON_NAVYREVOLVER`] = true,
        [`WEAPON_GADGETPISTOL`] = true,
        [`WEAPON_MILITARYRIFLE`] = true,
        [`WEAPON_HEAVYRIFLE`] = true,
        [`WEAPON_TACTICALRIFLE`] = true,
        [`WEAPON_PRECISIONRIFLE`] = true,
        [`WEAPON_ACIDPACKAGE`] = true,
        [`WEAPON_FERTILIZERCAN`] = true,
        [`WEAPON_STUNGUN_MP`] = true
    }
}

HazeConfig.Vehicles = {
    EnableBlacklist = true,
    EnableRpfCheck = true,
    EnableGodmodeCheck = true,
    AutoDeleteOnDetection = true,
    Blacklist = {
        [`rhino`] = true, [`hydra`] = true, [`lazer`] = true, [`savage`] = true,
        [`apc`] = true, [`insurgent3`] = true, [`trailersmall2`] = true,
        [`oppressor2`] = true, [`deluxo`] = true, [`stromberg`] = true,
        [`scramjet`] = true, [`rcbandito`] = true, [`minitank`] = true,
        [`barrage`] = true, [`chernobog`] = true, [`khanjali`] = true,
        [`akula`] = true, [`hunter`] = true, [`volatol`] = true,
        [`bombushka`] = true, [`rogue`] = true, [`starling`] = true,
        [`seabreeze`] = true, [`pyro`] = true, [`molotok`] = true,
        [`nokota`] = true, [`microlight`] = true, [`alphaz1`] = true,
        [`tula`] = true, [`avenger`] = true, [`avenger2`] = true,
        [`strikeforce`] = true, [`cerberus`] = true, [`cerberus2`] = true,
        [`cerberus3`] = true, [`bruiser`] = true, [`bruiser2`] = true,
        [`bruiser3`] = true, [`brutus`] = true, [`brutus2`] = true,
        [`brutus3`] = true, [`imperator`] = true, [`imperator2`] = true,
        [`imperator3`] = true, [`deathbike`] = true, [`deathbike2`] = true,
        [`deathbike3`] = true, [`dominator4`] = true, [`dominator5`] = true,
        [`dominator6`] = true, [`issi4`] = true, [`issi5`] = true,
        [`issi6`] = true, [`monster3`] = true, [`monster4`] = true,
        [`monster5`] = true, [`slamvan4`] = true, [`slamvan5`] = true,
        [`slamvan6`] = true, [`zr380`] = true, [`zr3802`] = true,
        [`zr3803`] = true, [`scarab`] = true, [`scarab2`] = true,
        [`scarab3`] = true, [`toreador`] = true, [`veto`] = true,
        [`veto2`] = true, [`weevil2`] = true, [`comet7`] = true,
        [`ignus`] = true, [`zeno`] = true
    }
}

HazeConfig.Entities = {
    EnableBlacklist = true,
    EnableSpawnRateCheck = true,
    EnableDeleteRateCheck = true,
    EnableEntityCountCheck = true,
    AutoCancelOnSpawn = true,
    MaxEntitiesPerPlayer = 50,
    MaxSpawnsPerMinute = 20,
    MaxPropsPerMinute = 15,
    MaxPedsPerMinute = 10,
    MaxVehiclesPerMinute = 8,
    MaxObjectsPerMinute = 25,
    MaxParticlesPerMinute = 10,
    MaxScenariosPerMinute = 5,
    MaxDeletedEntitiesPerMinute = 30,
    Blacklist = {
        [`prop_roadcone02a`] = true, [`prop_roadcone02b`] = true,
        [`prop_barrier_work05`] = true, [`prop_mp_barrier_01`] = true,
        [`prop_mp_barrier_01b`] = true, [`prop_mp_barrier_02`] = true,
        [`prop_mp_barrier_02b`] = true, [`prop_cons_plz`] = true,
        [`prop_cons_crate`] = true, [`prop_const_plz`] = true,
        [`prop_rub_binbag_01`] = true, [`prop_rub_binbag_03`] = true,
        [`prop_rub_binbag_04`] = true, [`prop_rub_binbag_05`] = true,
        [`prop_rub_binbag_06`] = true, [`prop_rub_binbag_08`] = true,
        [`prop_rub_boxpile_01`] = true, [`prop_rub_boxpile_02`] = true,
        [`prop_rub_boxpile_03`] = true, [`prop_rub_boxpile_04`] = true,
        [`prop_rub_boxpile_05`] = true, [`prop_rub_boxpile_06`] = true,
        [`prop_rub_boxpile_07`] = true, [`prop_rub_boxpile_08`] = true,
        [`prop_rub_boxpile_09`] = true, [`prop_rub_boxpile_10`] = true,
        [`prop_rub_carpart_01`] = true, [`prop_rub_carpart_02`] = true,
        [`prop_rub_carpart_03`] = true, [`prop_rub_carpart_04`] = true,
        [`prop_rub_carpart_05`] = true, [`prop_rub_couch01`] = true,
        [`prop_rub_couch02`] = true, [`prop_rub_couch03`] = true,
        [`prop_rub_couch04`] = true, [`prop_rub_dumpster_01a`] = true,
        [`prop_rub_dumpster_02a`] = true, [`prop_rub_dumpster_02b`] = true,
        [`prop_rub_dumpster_03a`] = true, [`prop_rub_dumpster_04a`] = true,
        [`prop_rub_dumpster_05a`] = true, [`prop_rub_liner`] = true,
        [`prop_rub_pile_01`] = true, [`prop_rub_pile_02`] = true,
        [`prop_rub_pile_03`] = true, [`prop_rub_pile_04`] = true,
        [`prop_rub_table_01`] = true, [`prop_rub_table_02`] = true,
        [`prop_rub_trolley01a`] = true, [`prop_rub_trolley02a`] = true,
        [`prop_rub_trolley03a`] = true
    }
}

HazeConfig.Explosions = {
    EnableCheck = true,
    MaxPerMinute = 5,
    MaxDamageScale = 5.0,
    MaxRadius = 50.0,
    SafeTypes = {
        [0]=true,[1]=true,[2]=true,[3]=true,[4]=true,[5]=true,[6]=true,[7]=true,
        [8]=true,[9]=true,[10]=true,[11]=true,[12]=true,[13]=true,[14]=true,
        [15]=true,[16]=true,[17]=true,[18]=true,[19]=true,[20]=true
    }
}

HazeConfig.MagicBullet = {
    EnableCheck = true,
    MaxWallDistance = 150.0,
    MaxVehicleDistance = 100.0
}

HazeConfig.Esp = {
    EnableTrackingCheck = true,
    EnableInvisibleTrackingCheck = true,
    MaxTrackingDistance = 250.0
}

HazeConfig.DevTool = {
    EnableHeartbeatCheck = true,
    EnableDomCheck = true,
    EnableNuiRateCheck = true,
    MaxHeartbeatGap = 3000,
    HeartbeatAbsentMultiplier = 5,
    MaxDomMutationsPerMinute = 5,
    MaxNuiCallbacksPerMinute = 10
}

HazeConfig.Resources = {
    EnableManifestCheck = true,
    EnableSuspiciousScan = true,
    EnableBackdoorScan = true,
    EnableWatchdog = true,
    AutoRestartCritical = true,
    Critical = {
        'haze_ac', 'spawnmanager', 'sessionmanager', 'mapmanager',
        'chat', 'hardcap', 'rconlog', 'monitor', 'webadmin',
        'screenshot-basic', 'yarn', 'baseevents'
    },
    Suspicious = {
        'devtool', 'devtools', 'nui_devtools', 'debugger', 'executor',
        'injector', 'cheat', 'hack', 'modmenu', 'redengine', 'eulen',
        'susano', 'phantom', 'impulse', 'cipher', 'backdoor', 'exploit',
        'bypass', 'antidetect'
    }
}

HazeConfig.Events = {
    EnableEventCheck = true,
    EnableCommandCheck = true,
    EnableTriggerCheck = true,
    MaxEventsPerSecond = 8,
    MaxCommandsPerMinute = 5,
    SuspiciousPrefixes = {
        'devtool_', 'nui_dev_', 'debug_', 'inject_', 'exec_', 'hack_',
        'cheat_', 'exploit_', 'bypass_', 'admin_', 'god_', 'give_money_hack'
    },
    SuspiciousCommands = {
        'stop ', 'restart ', 'quit', 'exit', 'shutdown',
        'kill ', 'crash', 'unload', 'disable'
    }
}

HazeConfig.Misc = {
    MinStaminaThreshold = 10.0,
    MaxFreecamChecks = 10,
    MaxInvisibleChecks = 10,
    EnableStaminaCheck = true,
    EnableFreecamCheck = true,
    EnableInvisibilityCheck = true,
    EnableNightVisionCheck = true,
    EnableThermalCheck = true
}

HazeConfig.Behavior = {
    EnableMovementPatternCheck = true,
    EnableDamageStatisticalCheck = true,
    EnableCrossPlayerValidation = true,
    MovementHistorySize = 12,
    AbnormalSpeedThreshold = 100.0,
    ViolationGracePeriod = 5000
}

HazeConfig.Whitelist = {
    AutoWhitelistAdmins = true,
    AceBypass = 'haze_ac.bypass',
    AceAdmin = 'haze_ac.admin',
    AceSuperAdmin = 'haze_ac.superadmin'
}

HazeConfig.Native = {
    EnableNativeModule = true,
    AutoBanOnDetection = true,
    ScanInterval = 5000,
    ReportToServer = true,
    TokenValidation = true,
    WhitelistAdmins = true,
    EnableProcessScan = true,
    EnableWindowScan = true,
    EnableModuleScan = true,
    EnableDebuggerCheck = true,
    EnableThreadInjectionCheck = true
}

function HazeConfig.Validate()
    local errors = {}
    if HazeConfig.StrikeThreshold < 1 then
        errors[#errors + 1] = 'StrikeThreshold must be >= 1'
    end
    if HazeConfig.StrikeDecayTime < 30000 then
        errors[#errors + 1] = 'StrikeDecayTime too low (minimum 30s)'
    end
    if HazeConfig.SessionGrace < 10000 then
        errors[#errors + 1] = 'SessionGrace too low (minimum 10s)'
    end
    if HazeConfig.Movement.MaxPedSpeed < 20.0 then
        errors[#errors + 1] = 'MaxPedSpeed too restrictive (minimum 20.0)'
    end
    if HazeConfig.Combat.MaxHitRatio > 1.0 or HazeConfig.Combat.MaxHitRatio < 0.5 then
        errors[#errors + 1] = 'MaxHitRatio must be between 0.5 and 1.0'
    end
    if HazeConfig.HwidSalt == 'change_this_salt_on_each_server_x7f3a9c2' then
        print('[haze_ac] WARNING: HwidSalt is still the default value')
    end
    if #errors > 0 then
        print('[haze_ac] ============ CONFIG ERRORS ============')
        for _, e in ipairs(errors) do
            print('[haze_ac] ERROR: ' .. e)
        end
        print('[haze_ac] =======================================')
        return false
    end
    print('[haze_ac] Configuration validated successfully')
    print('[haze_ac] - Strike Threshold: ' .. HazeConfig.StrikeThreshold)
    print('[haze_ac] - Strike Decay: ' .. (HazeConfig.StrikeDecayTime / 1000) .. 's')
    print('[haze_ac] - Session Grace: ' .. (HazeConfig.SessionGrace / 1000) .. 's')
    print('[haze_ac] - Max Ped Speed: ' .. HazeConfig.Movement.MaxPedSpeed .. ' m/s')
    print('[haze_ac] - Max Vehicle Speed: ' .. HazeConfig.Movement.MaxVehicleSpeed .. ' m/s')
    print('[haze_ac] - Aim Snap Threshold: ' .. HazeConfig.Aim.CamSnapAngle .. ' deg')
    return true
end

# HazeAC Web Admin Panel / Pannello Admin Web HazeAC

## Overview / Panoramica

A modern React TypeScript admin panel for HazeAC anticheat.
Un pannello admin moderno React TypeScript per l'anticheat HazeAC.

## Features / Caratteristiche

- ✅ Real-time player statistics / Statistiche player real-time
- ✅ Ban management (view, add, remove) / Gestione ban (visualizza, aggiungi, rimuovi)
- ✅ Strike monitoring / Monitoraggio strike
- ✅ Framework agnostic (ESX, QBcore, QBox, standalone) / Agnostico framework (ESX, QBcore, QBox, standalone)
- ✅ Modern UI with Tailwind CSS / UI moderna con Tailwind CSS
- ✅ TypeScript for type safety / TypeScript per sicurezza tipi

## Quick Start / Avvio Rapido

### Build / Costruzione
```bash
cd web-panel
npm install
npm run build
```

### Installation / Installazione
Copy the `web-panel` folder to your server resources.
Copia la cartella `web-panel` nelle risorse del tuo server.

Add to `server.cfg`:
Aggiungi a `server.cfg`:
```
ensure haze_ac_panel
start haze_ac_panel
```

### Access / Accesso
In-game command / Comando in-game:
```
/hazeac_panel
```

Requires ACE permission `haze_ac.admin`.
Richiede permesso ACE `haze_ac.admin`.

## Documentation / Documentazione

See `WEB_PANEL_GUIDE.md` for detailed installation and usage instructions.
Vedi `WEB_PANEL_GUIDE.md` per istruzioni dettagliate di installazione e utilizzo.

## Structure / Struttura

```
web-panel/
├── src/
│   ├── components/
│   │   └── AdminPanel.tsx
│   ├── utils/
│   │   └── fetchNui.ts
│   ├── App.tsx
│   ├── main.tsx
│   └── index.css
├── server-side/
│   └── haze_nui_bridge.lua
├── client-side/
│   └── haze_nui_client.lua
├── fxmanifest.lua
├── package.json
├── vite.config.ts
├── tailwind.config.js
└── tsconfig.json
```

## Dependencies / Dipendenze

- React 18
- TypeScript 5
- Vite 4
- Tailwind CSS 3
- FiveM NUI API

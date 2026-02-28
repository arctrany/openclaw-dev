# OpenClaw Source Code Map

## Core (`src/`)

```
src/
├── cli/                # CLI wiring, argument parsing, entry point
│   └── index.ts        # Main CLI entry → commands dispatch
├── commands/           # CLI subcommands
│   ├── gateway.ts      # `openclaw gateway` — start/manage Gateway
│   ├── agent.ts        # `openclaw agent` — interact with Pi agent
│   ├── message.ts      # `openclaw message` — send via channels
│   └── ...
├── gateway/            # Gateway WS server
│   ├── index.ts        # WS server setup, connection management, routing
│   └── doctor.ts       # `openclaw doctor` — health checks
├── agents/             # Agent runtime (Pi)
├── sessions/           # Session management (main, group, queue)
├── channels/           # Channel routing layer
├── routing/            # Message routing between channels/agents
├── config/             # Configuration system
├── browser/            # Browser control (CDP — Chrome DevTools Protocol)
├── canvas-host/        # Canvas + A2UI (Agent-to-UI)
├── web/                # WebChat + web provider
├── plugins/            # Plugin loading and management
├── providers/          # Model providers (Anthropic, OpenAI, etc.)
├── media/              # Media pipeline (images, audio, video)
├── tts/                # Text-to-speech
├── cron/               # Cron jobs + timed wakeups
├── hooks/              # Event hook system
├── wizard/             # Onboarding wizard (`openclaw onboard`)
├── terminal/           # Terminal utilities
│   ├── table.ts        # Table formatting
│   └── palette.ts      # Color palette
└── ...
```

## Extensions (`extensions/`) — 39 packages

### Channels
| Extension | Protocol |
|-----------|----------|
| `bluebubbles` | iMessage via BlueBubbles |
| `discord` | Discord (discord.js) |
| `slack` | Slack (Bolt SDK) |
| `telegram` | Telegram (grammY) |
| `whatsapp` | WhatsApp (Baileys) |
| `signal` | Signal |
| `imessage` | iMessage (native) |
| `msteams` | Microsoft Teams |
| `matrix` | Matrix |
| `googlechat` | Google Chat |
| `feishu` | Feishu / Lark |
| `mattermost` | Mattermost |
| `irc` | IRC |
| `nostr` | Nostr protocol |
| `line` | LINE |
| `zalo` / `zalouser` | Zalo |
| `synology-chat` | Synology Chat |
| `nextcloud-talk` | Nextcloud Talk |
| `tlon` | Tlon / Urbit |
| `twitch` | Twitch chat |

### Memory & Storage
| Extension | Purpose |
|-----------|---------|
| `memory-core` | Core memory plugin |
| `memory-lancedb` | LanceDB vector memory |

### Tools & Utilities
| Extension | Purpose |
|-----------|---------|
| `lobster` | Workflow shell |
| `llm-task` | LLM task execution |
| `phone-control` | Phone remote control |
| `device-pair` | Device pairing |
| `talk-voice` | Voice conversation |
| `voice-call` | Voice calling |
| `diagnostics-otel` | OpenTelemetry diagnostics |
| `thread-ownership` | Thread management |
| `copilot-proxy` | Copilot proxy |
| `open-prose` | Prose editing |
| `acpx` | ACP exchange |

### Auth Helpers
| Extension | Purpose |
|-----------|---------|
| `google-gemini-cli-auth` | Gemini CLI auth |
| `minimax-portal-auth` | Minimax portal auth |
| `qwen-portal-auth` | Qwen portal auth |

## Apps (`apps/`)

| App | Tech | Description |
|-----|------|-------------|
| `macos/` | SwiftUI | Menu bar app, Voice Wake, Talk Mode |
| `ios/` | Swift | iOS node (Canvas, camera) |
| `android/` | Kotlin | Android node |

## Scripts (`scripts/`)

| Script | Purpose |
|--------|---------|
| `run-node.mjs` | Run Node.js processes (gateway/agent/TUI) |
| `package-mac-app.sh` | macOS app packaging + signing |
| `restart-mac.sh` | Restart macOS app |
| `clawlog.sh` | macOS unified log viewer |

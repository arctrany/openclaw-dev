---
name: scaffold-plugin
description: Interactive workflow to create a new OpenClaw plugin (extension) with manifest, TypeScript entry point, and component registration.
argument-hint: [plugin-name]
---

# Scaffold OpenClaw Plugin

Guide the user through creating a new OpenClaw plugin (extension).

## Step 1: Gather Requirements

Ask the user:

1. **Plugin name** (if not provided as $1)
   - Must be kebab-case
   - Examples: `voice-assistant`, `slack-channel`, `custom-tools`

2. **Plugin purpose** — What capability does it add?

3. **Components to register** (select all that apply):
   - Tool (new tool for agents)
   - Channel (new messaging platform)
   - Provider (model/auth provider)
   - Hook (event handler)
   - CLI command (openclaw CLI extension)
   - Service (background service)

4. **Author information** — Name, email (optional)

## Step 2: Validate Plugin Name

```bash
PLUGIN_NAME="${1:-<from user>}"

if ! echo "$PLUGIN_NAME" | grep -qE '^[a-z0-9]+(-[a-z0-9]+)*$'; then
  echo "ERROR: Plugin name must be kebab-case"
  exit 1
fi

if [ -d "$PLUGIN_NAME" ]; then
  echo "WARNING: Directory $PLUGIN_NAME already exists"
fi
```

## Step 3: Create Directory Structure

```bash
mkdir -p "$PLUGIN_NAME/src"
```

## Step 4: Create openclaw.plugin.json

```json
{
  "name": "<plugin-name>",
  "version": "0.1.0",
  "description": "<plugin-purpose>",
  "author": {
    "name": "<author-name>"
  },
  "entry": "./src/index.ts"
}
```

Save to `$PLUGIN_NAME/openclaw.plugin.json`

## Step 5: Create package.json

```json
{
  "name": "<plugin-name>",
  "version": "0.1.0",
  "type": "module",
  "openclaw": {
    "extensions": ["."]
  },
  "devDependencies": {
    "typescript": "^5.0.0"
  }
}
```

## Step 6: Create TypeScript Entry Point

Generate `$PLUGIN_NAME/src/index.ts` based on selected components:

```typescript
import type { PluginAPI } from "openclaw";

export default function activate(api: PluginAPI) {
  // Tool registration
  api.registerTool("my-tool", {
    description: "Description of what this tool does",
    parameters: {
      input: { type: "string", description: "Input parameter" },
    },
    async execute({ input }) {
      // Tool implementation
      return { result: `Processed: ${input}` };
    },
  });

  // Channel registration (if selected)
  // api.registerChannel("my-channel", { ... });

  // Hook registration (if selected)
  // api.registerHook("onSessionStart", async (ctx) => { ... });

  // CLI command (if selected)
  // api.registerCLI("my-cmd", { ... });

  // Service (if selected)
  // api.registerService("my-service", { ... });
}
```

Uncomment relevant sections based on user's component selections.

## Step 7: Create tsconfig.json

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ESNext",
    "moduleResolution": "bundler",
    "strict": true,
    "outDir": "./dist",
    "rootDir": "./src"
  },
  "include": ["src/**/*.ts"]
}
```

## Step 8: Install Plugin

```bash
# Option A: Link to workspace extensions
ln -s "$(pwd)/$PLUGIN_NAME" ~/.openclaw/extensions/$PLUGIN_NAME

# Option B: Add to config
# Edit ~/.openclaw/openclaw.json:
#   plugins.load.paths: ["<absolute-path-to-plugin>"]

# Restart Gateway
pkill -TERM openclaw-gateway
sleep 3
openclaw health
openclaw plugins list
```

## Step 9: Verify

```bash
# Check plugin loaded
openclaw plugins list | grep "$PLUGIN_NAME"

# If tool registered, test it
openclaw gateway call --method "tools.list" 2>/dev/null | grep "my-tool"
```

## Step 10: Report

```
Plugin created: <plugin-name>
  Location:  ./<plugin-name>/
  Manifest:  openclaw.plugin.json
  Entry:     src/index.ts
  Components:
    ✓ openclaw.plugin.json (manifest)
    ✓ src/index.ts (entry point)
    ✓ package.json
    ✓ tsconfig.json

Registered:
    <tool|channel|hook|cli|service>: <name>

Next steps:
  - Edit src/index.ts to implement your logic
  - Run: openclaw plugins list (verify loaded)
  - Test: send a message that triggers your tool
```

# Getting Started

This guide walks you through building and running OpenRocky from source.

## Prerequisites

- **macOS** (latest recommended)
- **Xcode 26+** with iOS 26.0+ SDK
- **Apple Developer account** (for device builds and TestFlight)
- **Physical iPhone** — `ios_system` does not support the iOS Simulator

## Clone the Repository

```bash
git clone https://github.com/openrocky/openrocky.git
cd openrocky
```

## Setup Python Runtime (Optional)

If you want local Python execution support:

```bash
scripts/setup_python.sh
```

This downloads Python 3.13 xcframework and pre-installs pip packages (requests, httpx, aiohttp, etc.) into the app bundle.

## Build

```bash
# Build for device
xcodebuild build -scheme OpenRocky -project OpenRocky/OpenRocky.xcodeproj -destination 'generic/platform=iOS'
```

Or open `OpenRocky/OpenRocky.xcodeproj` in Xcode and build with `Cmd+B`.

## Run Tests

Tests run on the iOS Simulator (they don't depend on `ios_system`):

```bash
xcodebuild test -scheme OpenRocky -project OpenRocky/OpenRocky.xcodeproj \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

The test suite uses Swift Testing (`@Test`, `#expect`) and covers:

- Session state machine transitions
- Tool registration completeness
- Provider inventory
- Skill store operations
- Character system prompts

## Configure AI Providers

After installing on a device:

1. Open Rocky
2. Go to **Settings → Providers**
3. Add at least one **chat provider** (e.g., OpenAI with your API key)
4. Optionally add a **realtime voice provider** for live voice sessions
5. Return to the home screen — Rocky is ready to use

## Deploy to TestFlight

### Quick Deploy

```bash
./scripts/deploy.sh
```

This runs the full pipeline: Python setup → build number increment → archive → upload to App Store Connect.

### Manual Steps

```bash
# Set App Store Connect API credentials
export ASC_API_KEY_ID=your_key_id
export ASC_API_ISSUER_ID=your_issuer_id
export ASC_API_KEY_P8_PATH=/path/to/AuthKey.p8

# Run TestFlight upload
scripts/testflight.sh all
```

### Deploy Options

- `./scripts/deploy.sh --skip-setup` — skip Python framework download
- `./scripts/deploy.sh --archive` — archive only, don't upload
- `scripts/testflight.sh archive` — archive step only
- `scripts/testflight.sh upload` — upload step only

## Project Structure

```
OpenRocky/                  # Xcode project
  OpenRocky/OpenRocky/
    App/                    # Entry point (@main, ContentView)
    Features/               # UI screens
    Models/                 # Data models
    Providers/              # AI provider configuration
    Runtime/                # ROS runtime core
      Tools/                # 30+ native bridge services
      Skills/               # Skill system
      Voice/                # Realtime voice clients
    Theme/                  # Visual palette
  OpenRockyTests/            # Unit tests
Packages/               # Local Swift packages
scripts/                # Build & deploy scripts
docs/                   # Documentation (you are here)
```

## Next Steps

- [Architecture](architecture.md) — understand how Rocky works
- [Tools](tools.md) — browse the 30+ native tools
- [Providers](providers.md) — configure AI backends
- [Skills](skills.md) — create and import custom skills
- [Voice](voice.md) — learn about voice interaction
- [Characters](characters.md) — customize AI personality

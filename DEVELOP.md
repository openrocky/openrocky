# Development

This project was developed by [everettjf](https://github.com/everettjf) with the assistance of [Claude Code](https://claude.ai/code) and [Codex](https://openai.com/codex).

## Requirements

- Xcode 26+
- iOS 26.0+ deployment target
- Swift 6.0 with strict concurrency
- macOS for building (no iOS Simulator support for `ios_system`)

## Build

```bash
# Build for device
xcodebuild build -scheme OpenRocky -project OpenRocky/OpenRocky.xcodeproj -destination 'generic/platform=iOS'

# Run tests (simulator)
xcodebuild test -scheme OpenRocky -project OpenRocky/OpenRocky.xcodeproj -destination 'platform=iOS Simulator,name=iPhone 16'

# Setup Python runtime (required by OpenRockyPython package)
scripts/setup_python.sh
```

## Deploy to TestFlight

```bash
# Full deploy pipeline
./scripts/deploy.sh

# Or step by step
ASC_API_KEY_ID=... ASC_API_ISSUER_ID=... ASC_API_KEY_P8_PATH=... scripts/testflight.sh all
```

## Code Style

- 4-space indentation, opening brace on same line
- `PascalCase` for types, `camelCase` for properties/methods
- All app types prefixed with `OpenRocky`
- SwiftUI + `@Observable` macro, async/await concurrency
- Early returns, guard statements, composition over inheritance

## Testing

Uses Swift Testing framework (`@Test`, `#expect`). Tests cover session state machine, tool registration, provider inventory, skill store, and character system prompts.

## Project Structure

```
OpenRocky/                  # iOS app (Xcode project)
  OpenRocky/OpenRocky/      # App source
    App/                    # Entry point
    Features/               # UI screens (Home, Chat, Voice, Settings, Providers)
    Models/                 # Data models
    Providers/              # AI provider configuration & clients
    Runtime/                # ROS runtime core
      Tools/                # 30+ native bridge services
      Skills/               # Skill system
      Voice/                # Realtime voice clients
    Theme/                  # Visual palette
  OpenRockyTests/            # Unit tests (Swift Testing)
  OpenRockyUITests/          # UI tests
Packages/               # Local Swift packages
  SwiftOpenAI/          # OpenAI API & Realtime session bridge
  LanguageModelChatUI/  # UIKit-based chat detail view
  MarkdownViewLocal/    # Markdown rendering
  OpenRockyIOSSystem/       # ios_system binary frameworks
  OpenRockyPython/          # Python runtime on iOS
scripts/                # Build & deploy scripts
website/                # Documentation site (Docusaurus)
```

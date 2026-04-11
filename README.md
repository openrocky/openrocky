# OpenRocky

> English | [中文](README_CN.md)

**Rocky** is a voice-first AI Agent app for iPhone. **OpenRocky** is the open-source project behind it.

Rocky is not a mobile chat wrapper or a Linux container crammed into a phone. It organizes voice interaction, task execution, system bridging, and result review into a native iPhone agent experience.

## Naming Convention

- **Rocky** — the product name, shown on the home screen, Siri, App Store, and all user-facing text
- **OpenRocky** — the open-source project name, used for the GitHub repo, Xcode project, code prefixes (`OpenRocky*`), and Swift package names

Think of it like Chrome vs. Chromium, or VS Code vs. VS Code OSS.

## Highlights

- **Voice-first** — voice is the primary interface, not a chat list
- **30+ native iOS tools** — contacts, calendar, health, weather, location, reminders, camera, photos, browser, crypto, and more
- **Multi-provider AI** — supports OpenAI, Anthropic, Gemini, Azure, Groq, xAI, OpenRouter, DeepSeek, Doubao, aiProxy
- **Realtime voice** — live voice sessions via OpenAI, Gemini, and Doubao realtime APIs
- **Custom skills** — built-in skills plus user-importable custom skills
- **Local execution** — controlled shell and Python runtime on-device via `ios_system`
- **Characters & Souls** — configurable AI personality and voice

## Architecture

```
User Voice → Voice Engine → AI Provider → ROS Runtime → Execution Layer → Results → UI + Voice
```

### ROS (Rocky OS) Runtime

The central execution core that organizes:

- **Sessions** — conversation and task contexts with state machine management
- **Tools** — 30+ iOS native bridge services registered in `OpenRockyToolbox`
- **Skills** — built-in and custom importable skills via `OpenRockySkillStore`
- **Voice** — realtime voice bridges for OpenAI, Gemini, and Doubao
- **Characters & Souls** — personality and voice configuration
- **Memory** — persistent context across sessions

### Three Execution Layers

1. **iOS Native Bridge** — Swift code calling system APIs (contacts, calendar, health, etc.)
2. **AI Tool Layer** — actions dispatched through provider APIs
3. **Local Execution** — controlled shell/Python in sandbox via `ios_system`

### Provider Architecture

Three-layer abstraction: **Provider** → **Account** → **Model**. Configured in `OpenRocky/OpenRocky/Providers/`.

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

## Development

This project was developed by [everettjf](https://github.com/everettjf) with the assistance of [Claude Code](https://claude.ai/code) and [Codex](https://openai.com/codex).

### Code Style

- 4-space indentation, opening brace on same line
- `PascalCase` for types, `camelCase` for properties/methods
- All app types prefixed with `OpenRocky`
- SwiftUI + `@Observable` macro, async/await concurrency
- Early returns, guard statements, composition over inheritance

### Testing

Uses Swift Testing framework (`@Test`, `#expect`). Tests cover session state machine, tool registration, provider inventory, skill store, and character system prompts.

## License

See [LICENSE](LICENSE) for details.

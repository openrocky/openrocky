# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Rocky is a voice-first AI Agent app for iPhone. OpenRocky is the open-source project behind it. The repo is in "documentation-first + early prototype" stage. The primary language is Chinese for docs/README, English for code.

**Naming:** "Rocky" is the user-facing product name (home screen, Siri, App Store, permission dialogs). "OpenRocky" is the project/code name (Xcode project, class prefixes, package names). Do not mix them — user-visible strings say "Rocky", code identifiers use `OpenRocky`.

- iOS-only, deployment target iOS 26.0+, Swift 6.0 strict concurrency
- Voice interaction is the primary input; text is supplementary
- Chat UI is a task detail page, not the main interface

## Build Commands

```bash
# Build (no simulator support for ios_system)
xcodebuild build -scheme OpenRocky -project OpenRocky/OpenRocky.xcodeproj -destination 'generic/platform=iOS'

# Run tests
xcodebuild test -scheme OpenRocky -project OpenRocky/OpenRocky.xcodeproj -destination 'platform=iOS Simulator,name=iPhone 16'

# TestFlight upload
ASC_API_KEY_ID=... ASC_API_ISSUER_ID=... ASC_API_KEY_P8_PATH=... scripts/testflight.sh all

# Full deploy (setup Python + build + archive + upload)
./scripts/deploy.sh
```

## Architecture

### ROS (Rocky OS) Runtime

The central execution core at `OpenRocky/OpenRocky/Runtime/`. Organizes:
- **Sessions** (`OpenRockySessionRuntime.swift`) — conversation and task contexts
- **Tools** (`Runtime/Tools/`) — 31+ iOS native bridge tools (contacts, calendar, health, weather, location, reminders, notifications, etc.) registered in `OpenRockyToolbox.swift`
- **Skills** (`Runtime/Skills/`) — built-in and custom importable skills via `OpenRockySkillStore`
- **Voice** (`Runtime/Voice/`) — realtime voice bridges for OpenAI and GLM
- **Characters/Souls** — personality and voice configuration

### Data Flow

```
User Voice → Voice Engine → AI Provider → ROS Runtime → Execution Layer → Results → UI + Voice
```

### Three Execution Layers

1. **iOS Native Bridge** — Swift code calling system APIs (contacts, calendar, health, etc.)
2. **AI Tool Layer** — actions dispatched through provider APIs
3. **Local Execution** (`ios_system`) — controlled shell/Python in sandbox. Note: ios_system xcframeworks do not support iOS Simulator.

### Provider Architecture

Three-layer abstraction: Provider → Account → Model. Configured in `OpenRocky/OpenRocky/Providers/`. Supports 10+ backends: OpenAI, Azure, Anthropic, Gemini, Groq, xAI, OpenRouter, DeepSeek, Doubao, aiProxy. Realtime voice providers: OpenAI, GLM.

### Local Packages (`Packages/`)

- **SwiftOpenAI** — OpenAI API and Realtime session bridge (Swift 5.9, iOS 15+)
- **LanguageModelChatUI** — UIKit-based chat detail view (Swift 6.0, iOS 17+)
- **MarkdownViewLocal** — Markdown rendering (Swift 6.0, iOS 16+)
- **OpenRockyIOSSystem** — ios_system binary frameworks for local execution (iOS 17+)
- **OpenRockyPython** — Python runtime on iOS; requires `scripts/setup_python.sh` to download xcframework

## Code Style

- 4-space indentation, opening brace on same line
- PascalCase for types, camelCase for properties/methods
- All app types prefixed with `OpenRocky`
- SwiftUI for UI, `@Observable` macro (not ObservableObject), async/await concurrency
- Early returns, guard statements, composition over inheritance
- Dependency injection over singletons

## Testing

Uses Swift Testing framework (`@Test` macro, `#expect`). Tests in `OpenRocky/OpenRockyTests/` cover session state machine, tool registration, provider inventory, skill store, and character system prompts.

## Deploy Scripts

- `scripts/testflight.sh` — auto-increments build number (skips numbers containing digit 4), archives, uploads via ASC API
- `scripts/deploy.sh` — full pipeline: Python setup → build → archive → upload; auto-commits version bumps
- `scripts/setup_python.sh` — downloads Python.xcframework for OpenRockyPython package

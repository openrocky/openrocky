# Architecture

This document describes the high-level architecture of OpenRocky, the voice-first AI Agent app for iPhone.

## Overview

Rocky is built around the concept of **ROS (Rocky OS) Runtime** — a central execution core that bridges voice input, AI reasoning, and native iOS capabilities into a unified agent experience.

```
User Voice → Voice Engine → AI Provider → ROS Runtime → Execution Layer → Results → UI + Voice
```

## ROS Runtime

The runtime lives in `OpenRocky/OpenRocky/Runtime/` and manages the full lifecycle of a user interaction:

### Sessions

`OpenRockySessionRuntime` drives the core state machine with four modes:

| Mode | Description | UI Indicator |
|------|-------------|--------------|
| **listening** | Microphone active, waiting for user intent | Waveform icon |
| **planning** | Converting speech into a task graph | Planning icon |
| **executing** | Tools running, timeline updating | Bolt icon |
| **ready** | Context attached, session quiet | Checkmark icon |

Transitions follow the cycle: `listening → planning → executing → ready → listening`.

Each session tracks live transcript, assistant reply, execution plan steps, timeline entries, and the active provider configuration.

### Tools

30+ native iOS bridge tools are registered in `OpenRockyToolbox`. Tools have dual registration paths:

- **Realtime tool definitions** — optimized for voice/realtime APIs
- **Chat tool definitions** — for standard chat completion APIs

See [Tools](tools.md) for the complete catalog.

### Skills

Built-in and user-importable skills extend the agent's capabilities. Skills are serialized as YAML frontmatter + prompt content and are dynamically injected as callable `skill-{name}` tools at runtime.

See [Skills](skills.md) for details.

### Voice

Realtime voice bridges connect audio I/O to AI providers for live voice conversations. Three providers are supported: OpenAI, Gemini, and Doubao.

See [Voice](voice.md) for details.

### Characters

Configurable AI personalities that control system prompts, speaking style, and voice selection across providers.

See [Characters](characters.md) for details.

## Three Execution Layers

### 1. iOS Native Bridge

Swift code calling system frameworks directly:

- **Contacts** — search via Contacts framework
- **Calendar** — events via EventKit
- **Health** — metrics via HealthKit
- **Location** — GPS + geocoding via CoreLocation
- **Weather** — forecasts via Open-Meteo API
- **Reminders** — Apple Reminders via EventKit
- **Camera/Photos** — capture and selection via UIKit/PhotosUI
- **Browser** — web browsing, cookie access, page reading
- **Notifications** — local notification scheduling
- **Crypto** — HMAC, SHA256, AES encryption via CommonCrypto

### 2. AI Tool Layer

Actions dispatched through provider APIs. The AI model decides which tools to call based on user intent. Tool calls and results are logged as conversation parts for persistence.

### 3. Local Execution

Controlled shell and Python runtime on-device via `ios_system`:

- Shell command execution
- Python 3.13 runtime with pre-installed packages
- FFmpeg for media processing
- File read/write in sandbox

> **Note:** `ios_system` xcframeworks do not support iOS Simulator. Device builds only.

## Provider Architecture

A three-layer abstraction handles AI backend diversity:

```
Provider → Account → Model
```

### Chat Providers (10 backends)

OpenAI, Azure OpenAI, Anthropic, Gemini, Groq, xAI, OpenRouter, DeepSeek, Volcengine (Doubao), AIProxy.

### Realtime Voice Providers (3 backends)

OpenAI, Gemini, Doubao — each implementing the `OpenRockyRealtimeVoiceClient` protocol.

Credentials are stored in the OS Keychain, never persisted to disk files.

See [Providers](providers.md) for configuration details.

## Local Packages

| Package | Purpose | Swift | iOS |
|---------|---------|-------|-----|
| **SwiftOpenAI** | OpenAI API & Realtime session bridge | 5.9 | 15+ |
| **LanguageModelChatUI** | UIKit-based chat detail view | 6.0 | 17+ |
| **MarkdownViewLocal** | Markdown rendering | 6.0 | 16+ |
| **OpenRockyIOSSystem** | ios_system binary frameworks | 6.0 | 17+ |
| **OpenRockyPython** | Python 3.13 runtime on iOS | 6.0 | 17+ |

## UI Architecture

- **SwiftUI** with `@Observable` macro (not ObservableObject)
- Responsive layout: stack on iPhone, `NavigationSplitView` on iPad
- Voice overlay presented on top of main content
- Chat UI is a task detail page, not the main interface
- Keyboard shortcuts: `Cmd+N` (new conversation), `Cmd+,` (settings)

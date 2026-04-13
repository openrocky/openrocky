# Voice Interaction

Voice is the primary interface in Rocky. The app supports both realtime voice sessions (live conversation) and a text-based fallback mode.

## Architecture

```
Microphone → Audio I/O → Realtime Voice Client → AI Provider → Tool Execution → Audio Output
```

### Key Components

- **OpenRockyRealtimeVoiceBridge** — central orchestrator that connects audio input/output, manages client lifecycle, and routes tool call results
- **OpenRockyRealtimeVoiceClient** — protocol that all voice providers implement
- **OpenRockyRealtimeVoiceFeatures** — feature flag declarations per provider

## Voice Session Lifecycle

1. **Start** — user taps the voice button; microphone activates, session enters `listening` mode
2. **Listen** — audio streams to the realtime AI provider
3. **Process** — provider detects speech, processes intent, may invoke tools
4. **Respond** — AI generates voice response streamed back through speakers
5. **Tool calls** — if the AI needs device data, tools execute and results feed back into the conversation
6. **End** — user stops the session or it times out

## Supported Providers

### OpenAI Realtime

- **Models:** `gpt-realtime-mini`, `gpt-realtime`
- **Protocol:** WebSocket-based realtime API
- **Features:** Full tool support, text + audio input, streaming responses
- **Note:** Requires microphone suspension during TTS playback to avoid feedback

### GLM (Zhipu AI)

- **Model:** GLM realtime voice models
- **Protocol:** GLM realtime API
- **Features:** Tool support (via category tools), client VAD, 16kHz WAV audio input
- **Note:** Optimized for Chinese language interactions

## Voice + Character Integration

The active character's personality and voice preferences are propagated to all voice providers:

- **System prompt** — character personality injected (shortened for realtime brevity)
- **Voice selection** — each character maps to specific voices per provider:
  - OpenAI voices: `alloy`, `sage`, `ash`, `echo`, `shimmer`

## Text Fallback

When realtime voice is unavailable, `OpenRockyChatInferenceRuntime` provides text-based chat inference. This uses standard chat completion APIs and supports the same tool calling capabilities.

## Session State Machine

Voice sessions drive the session state machine:

```
listening → planning → executing → ready
    ↑                                  |
    └──────────────────────────────────┘
```

Each state has associated UI feedback (icons, labels, colors) so the user always knows what Rocky is doing.

## Audio Pipeline

- Input: device microphone → raw audio buffer → streamed to provider
- Output: provider audio response → device speakers
- Some providers (OpenAI) require coordinating mic muting during playback to prevent echo/feedback loops

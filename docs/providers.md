# Providers

Rocky uses a three-layer provider abstraction to support multiple AI backends for both chat and realtime voice interactions.

## Architecture

```
Provider Kind → Provider Instance (Account + Credential) → Model
```

- **Provider Kind** — the backend type (e.g., OpenAI, Anthropic)
- **Provider Instance** — a configured account with API credentials
- **Model** — the specific model to use (e.g., gpt-4o, claude-sonnet-4-20250514)

## Chat Providers

Ten chat provider backends are supported:

| Provider | Key Features |
|----------|-------------|
| **OpenAI** | GPT-4o, GPT-4o-mini, o1, o3 series |
| **Azure OpenAI** | OpenAI models via Azure endpoints |
| **Anthropic** | Claude model family |
| **Gemini** | Google Gemini models |
| **Groq** | Fast inference for open models |
| **xAI** | Grok models |
| **OpenRouter** | Multi-provider routing |
| **DeepSeek** | DeepSeek models |
| **Volcengine (Doubao)** | ByteDance models, Chinese-optimized |
| **AIProxy** | Proxy service for iOS apps |

### Configuration

Each provider instance is stored as JSON in `Application Support/OpenRockyProviders/{id}.json`. The configuration includes:

- Provider kind
- Model ID
- API credential (stored in OS Keychain, not in the JSON file)
- Azure-specific parameters (endpoint, deployment name, API version)
- Proxy settings (if applicable)

### Credential Security

All API keys and secrets are stored in the iOS Keychain via `OpenRockyKeychain`. They are never written to disk files or included in backups.

## Realtime Voice Providers

Three realtime voice providers enable live voice conversations:

### OpenAI Realtime

- Models: `gpt-realtime-mini`, `gpt-realtime`
- Full feature support: text input, streaming, tool calls, audio output
- Requires microphone suspension during TTS playback

### Gemini Live

- Model: `gemini-2.5-flash-native-audio-latest`
- Multimodal live capability
- Cost-effective option

### Doubao (Volcengine)

- Model: `doubao-e2e-voice`
- Natural speech emotion
- VAD-based turn detection
- Optimized for Chinese language

### Voice Feature Flags

Each realtime provider declares its capabilities:

| Feature | OpenAI | Gemini | Doubao |
|---------|--------|--------|--------|
| Text input | Yes | Yes | Yes |
| Assistant streaming | Yes | Yes | Yes |
| Tool calls | Yes | Yes | Yes |
| Audio output | Yes | Yes | Yes |
| Needs mic suspension | Yes | No | No |

## Provider Stores

- `OpenRockyProviderStore` — manages chat provider instances
- `OpenRockyRealtimeProviderStore` — manages voice provider instances

Both stores handle CRUD operations, credential management, and backward-compatible migration from older data formats.

## Setting Up Providers

1. Open **Settings** in the app
2. Navigate to **Providers** (Chat or Voice)
3. Tap **Add Provider**
4. Select the provider kind
5. Enter your API key and model configuration
6. The provider is immediately available for use

Multiple instances of the same provider kind can be configured (e.g., different OpenAI accounts or models).

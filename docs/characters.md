# Characters

Characters define the AI personality, speaking style, and voice configuration for Rocky. Each character provides a consistent persona across both chat and voice interactions.

## Character Structure

| Field | Description |
|-------|-------------|
| `id` | Unique identifier |
| `name` | Display name |
| `description` | Brief description of the character |
| `personality` | Full system prompt defining behavior |
| `greeting` | Initial greeting message |
| `speakingStyle` | Description of how the character communicates |
| `openaiVoice` | Voice ID for OpenAI realtime (e.g., `alloy`, `sage`) |
| `isBuiltIn` | Whether the character ships with the app |

## Built-in Characters

Rocky ships with five built-in characters:

### Rocky (Default)

- **Personality:** Friendly, efficient assistant
- **OpenAI Voice:** `alloy`
- The default character for general-purpose use

### English Teacher

- **Personality:** Patient language tutor
- **OpenAI Voice:** `sage`
- Focused on language learning and practice

### Software Dev Expert

- **Personality:** Technical, precise coder
- **OpenAI Voice:** `ash`
- Specialized in programming and technical topics

### Storm Chaser

- **Personality:** Enthusiastic, adventurous
- **OpenAI Voice:** `echo`
- Energetic persona for exploration and discovery

### Mindful Guide

- **Personality:** Calm, wellbeing-focused
- **OpenAI Voice:** `shimmer`
- Gentle persona for wellness and mindfulness

## Custom Characters

Users can create custom characters through **Settings → Characters**:

1. Tap **Add Character**
2. Define the personality (system prompt), greeting, and speaking style
3. Select voice preferences for each realtime provider
4. Save — the character is immediately selectable

## How Characters Work

### System Prompt Injection

The active character's personality is injected into the system prompt for every interaction:

- **Chat mode** — full personality prompt including tool list and enabled skills
- **Voice mode** — shortened prompt optimized for realtime brevity (omits tool list and skills)

### Voice Mapping

Each character can specify preferred voices for different providers. When switching characters, the voice automatically changes to match.

### Persistence

Characters are stored as JSON files in `Application Support/OpenRockyCharacters/`. A manifest file tracks the active character ID.

## Migration from Souls

The character system replaced an earlier "Souls" system. Rocky automatically migrates old soul definitions to characters on first launch. The migration is transparent to users.

## Character Store

`OpenRockyCharacterStore` (singleton) manages:

- Loading and saving characters
- Active character selection
- Built-in character seeding on first launch
- Soul → Character migration

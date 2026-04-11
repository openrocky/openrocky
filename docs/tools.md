# Tools

Rocky ships with 30+ native iOS bridge tools that give the AI agent direct access to device capabilities. All tools are registered in `OpenRockyToolbox` and dispatched through the ROS Runtime.

## Tool Registration

Tools are registered via two paths depending on the API mode:

- `realtimeToolDefinitions()` — for voice/realtime sessions
- `chatToolDefinitions()` — for text-based chat completions

Both paths produce the same tool capabilities but with format differences suited to each API style.

## Tool Catalog

### Location & Navigation

| Tool | Description |
|------|-------------|
| `apple-location` | Get current device GPS coordinates |
| `apple-geocode` | Convert addresses to coordinates and vice versa |
| `nearby-search` | Search for local places using Apple Maps |

### Calendar & Reminders

| Tool | Description |
|------|-------------|
| `apple-calendar` | Create, read, and manage calendar events (EventKit) |
| `apple-reminder` | Create and manage Apple Reminders |
| `apple-alarm` | Create alarms using AlarmKit |
| `notification-schedule` | Schedule local notifications |

### Health & Wellness

| Tool | Description |
|------|-------------|
| `apple-health-summary` | Get an overview of health metrics |
| `apple-health-metric` | Query specific metrics: steps, heart rate, active energy, distance, sleep (HealthKit) |

### Contacts

| Tool | Description |
|------|-------------|
| `apple-contacts-search` | Search contacts by name or other fields (Contacts framework) |

### Weather

| Tool | Description |
|------|-------------|
| `weather` | Current conditions and forecasts (via Open-Meteo, no API key required) |

### Web & Browser

| Tool | Description |
|------|-------------|
| `browser-open` | Open a URL in the in-app browser |
| `browser-cookies` | Access browser cookies |
| `browser-read` | Read page content from a loaded web page |
| `web-search` | Search the web |
| `open-url` | Open URLs and deep links |

### Media

| Tool | Description |
|------|-------------|
| `camera-capture` | Capture a photo using the device camera |
| `photo-pick` | Select photos from the photo library (PhotosUI) |
| `file-pick` | Select files from the device file system |

### Local Execution

| Tool | Description |
|------|-------------|
| `shell-execute` | Run shell commands in a controlled sandbox (ios_system) |
| `python-execute` | Execute Python 3.13 scripts on-device |
| `ffmpeg-execute` | Run FFmpeg commands for media processing |

### File System

| Tool | Description |
|------|-------------|
| `file-read` | Read file contents from the app sandbox |
| `file-write` | Write file contents to the app sandbox |

### Memory

| Tool | Description |
|------|-------------|
| `memory_get` | Retrieve persistent key-value data across sessions |
| `memory_write` | Store persistent key-value data across sessions |

### Security & Crypto

| Tool | Description |
|------|-------------|
| `crypto` | Symmetric encryption/decryption (AES), hashing (SHA256, MD5), HMAC, base64 |
| `oauth-authenticate` | Perform OAuth authentication flows (AuthenticationServices) |

### Task Management

| Tool | Description |
|------|-------------|
| `todo` | Persistent to-do list management |

### Skills (Dynamic)

Custom and built-in skills are registered as `skill-{name}` tools at runtime. See [Skills](skills.md) for details.

## Adding New Tools

To add a new tool:

1. Create a service file in `OpenRocky/OpenRocky/Runtime/Tools/` (e.g., `OpenRockyMyNewService.swift`)
2. Register the tool definition in `OpenRockyToolbox.swift` under both `realtimeToolDefinitions()` and `chatToolDefinitions()`
3. Add the dispatch handler in the toolbox's execution logic
4. Follow the naming convention: `OpenRocky{Name}Service` for the class, lowercase-hyphenated for the tool ID

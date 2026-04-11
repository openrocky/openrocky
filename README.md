# OpenRocky

> English | [中文](README_CN.md)

**Rocky** is a voice-first AI Agent app for iPhone. **OpenRocky** is the open-source project behind it.

Rocky is not a mobile chat wrapper or a Linux container crammed into a phone. It organizes voice interaction, task execution, system bridging, and result review into a native iPhone agent experience.

## Screenshots

<p>
<img src="screenshots/screenshot_ios1.PNG" alt="Screenshot 1" width="200">
<img src="screenshots/screenshot_ios2.PNG" alt="Screenshot 2" width="200">
<img src="screenshots/screenshot_ios3.PNG" alt="Screenshot 3" width="200">
<img src="screenshots/screenshot_ios4.PNG" alt="Screenshot 4" width="200">
</p>

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

## Development

See [DEVELOP.md](DEVELOP.md) for build instructions, code style, project structure, and deployment details.

## Website

[https://openrocky.org](https://openrocky.org)

## Download

- **iOS TestFlight**: [https://testflight.apple.com/join/GZtbEpXN](https://testflight.apple.com/join/GZtbEpXN)

## Open Source

- **iOS**: [https://github.com/openrocky/openrocky](https://github.com/openrocky/openrocky)
- **Android**: [https://github.com/openrocky/openrocky_android](https://github.com/openrocky/openrocky_android)

## Community

- **Author X / Twitter**: [@everettjf](https://x.com/everettjf)
- **Telegram**: [@openrocky](https://t.me/openrocky)
- **Discord**: [https://discord.gg/SvvsaDA4nE](https://discord.gg/SvvsaDA4nE)

## Feedback

- **iOS**: [Submit iOS Feedback](https://github.com/openrocky/openrocky/issues/new)
- **Android**: [Submit Android Feedback](https://github.com/openrocky/openrocky_android/issues/new)

## WeChat

Follow our WeChat public account for updates:

<img src="wx.png" alt="WeChat" width="200">

## Star History

[![Star History Chart](https://api.star-history.com/svg?repos=openrocky/openrocky&type=Date)](https://star-history.com/#openrocky/openrocky&Date)

## License

See [LICENSE](LICENSE) for details.

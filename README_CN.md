# OpenRocky

> [English](README.md) | 中文

**Rocky** 是一款语音优先的 iPhone AI Agent 应用。**OpenRocky** 是其背后的开源项目。

Rocky 不是一个移动端聊天壳子，也不是把 Linux 容器塞进手机。它将语音交互、任务执行、系统桥接和结果回顾组织成一个原生的 iPhone Agent 体验。

## 截图

<p>
<img src="screenshots/screenshot_ios1.PNG" alt="截图 1" width="200">
<img src="screenshots/screenshot_ios2.PNG" alt="截图 2" width="200">
<img src="screenshots/screenshot_ios3.PNG" alt="截图 3" width="200">
<img src="screenshots/screenshot_ios4.PNG" alt="截图 4" width="200">
</p>

## 命名约定

- **Rocky** — 产品名，用于主屏幕、Siri、App Store 及所有用户可见的文案
- **OpenRocky** — 开源项目名，用于 GitHub 仓库、Xcode 工程、代码前缀（`OpenRocky*`）及 Swift 包名

类似 Chrome 与 Chromium、VS Code 与 VS Code OSS 的关系。

## 特性

- **语音优先** — 语音是主要交互方式，而非聊天列表
- **30+ 原生 iOS 工具** — 通讯录、日历、健康、天气、定位、提醒事项、相机、相册、浏览器、加密等
- **多 AI 服务商** — 支持 OpenAI、Anthropic、Gemini、Azure、Groq、xAI、OpenRouter、DeepSeek、豆包、aiProxy
- **实时语音** — 通过 OpenAI、Gemini、豆包的实时 API 进行实时语音对话
- **自定义技能** — 内置技能 + 用户可导入的自定义技能
- **本地执行** — 通过 `ios_system` 在设备上运行受控的 Shell 和 Python
- **角色与灵魂** — 可配置的 AI 人格和声音

## 架构

```
用户语音 → 语音引擎 → AI 服务商 → ROS 运行时 → 执行层 → 结果 → UI + 语音
```

### ROS (Rocky OS) 运行时

核心执行引擎，组织以下模块：

- **会话 (Sessions)** — 对话和任务上下文，带状态机管理
- **工具 (Tools)** — 30+ iOS 原生桥接服务，注册在 `OpenRockyToolbox` 中
- **技能 (Skills)** — 内置技能和可导入的自定义技能，通过 `OpenRockySkillStore` 管理
- **语音 (Voice)** — OpenAI、Gemini、豆包的实时语音桥接
- **角色与灵魂 (Characters & Souls)** — 人格和声音配置
- **记忆 (Memory)** — 跨会话的持久化上下文

### 三层执行架构

1. **iOS 原生桥接** — Swift 代码调用系统 API（通讯录、日历、健康等）
2. **AI 工具层** — 通过 AI 服务商 API 分发的操作
3. **本地执行** — 通过 `ios_system` 在沙盒中运行受控的 Shell/Python

### 服务商架构

三层抽象：**服务商 (Provider)** → **账户 (Account)** → **模型 (Model)**。配置在 `OpenRocky/OpenRocky/Providers/` 中。

## 开发

详见 [DEVELOP.md](DEVELOP.md)，包含构建说明、代码风格、项目结构和部署详情。

## 官网

[https://openrocky.org](https://openrocky.org)

## 下载

- **iOS TestFlight**: [https://testflight.apple.com/join/GZtbEpXN](https://testflight.apple.com/join/GZtbEpXN)

## 开源仓库

- **iOS**: [https://github.com/openrocky/openrocky](https://github.com/openrocky/openrocky)
- **Android**: [https://github.com/openrocky/openrocky_android](https://github.com/openrocky/openrocky_android)

## 社区

- **作者 X / Twitter**: [@everettjf](https://x.com/everettjf)
- **Telegram**: [@openrocky](https://t.me/openrocky)
- **Discord**: [https://discord.gg/SvvsaDA4nE](https://discord.gg/SvvsaDA4nE)

## 反馈

- **iOS**: [提交 iOS 反馈](https://github.com/openrocky/openrocky/issues/new)
- **Android**: [提交 Android 反馈](https://github.com/openrocky/openrocky_android/issues/new)

## 微信公众号

关注微信公众号，获取最新动态：

<img src="wx.png" alt="微信公众号" width="200">

## Star History

[![Star History Chart](https://api.star-history.com/svg?repos=openrocky/openrocky&type=Date)](https://star-history.com/#openrocky/openrocky&Date)

## 许可证

详见 [LICENSE](LICENSE)。

# OpenRocky

[![Website](https://img.shields.io/badge/Website-openrocky.org-blue)](https://openrocky.org)
[![TestFlight](https://img.shields.io/badge/TestFlight-Join%20Beta-0D96F6?logo=apple&logoColor=white)](https://testflight.apple.com/join/GZtbEpXN)
[![Discord](https://img.shields.io/badge/Discord-Join-5865F2?logo=discord&logoColor=white)](https://discord.gg/SvvsaDA4nE)
[![Telegram](https://img.shields.io/badge/Telegram-@openrocky-26A5E4?logo=telegram&logoColor=white)](https://t.me/openrocky)
[![License](https://img.shields.io/badge/License-Apache%202.0-yellow)](LICENSE)
[![Android](https://img.shields.io/badge/Android-Internal%20Testing-green?logo=android&logoColor=white)](https://github.com/openrocky/openrocky_android)

> [English](README.md) | 中文

**Rocky** 是一款语音优先的 iPhone AI Agent 应用。不是聊天壳子，也不是把 Linux 容器塞进手机。Rocky 将语音交互、任务执行、系统桥接和结果回顾组织成一个原生的 iPhone Agent 体验。

> **Rocky** 是面向用户的产品名。**OpenRocky** 是开源项目名 — 类似 Chrome 与 Chromium 的关系。

<p>
<img src="screenshots/screenshot_ios1.PNG" alt="截图 1" width="200">
<img src="screenshots/screenshot_ios2.PNG" alt="截图 2" width="200">
<img src="screenshots/screenshot_ios3.PNG" alt="截图 3" width="200">
<img src="screenshots/screenshot_ios4.PNG" alt="截图 4" width="200">
</p>

## 特性

- **语音优先** — 语音是主要交互方式，而非聊天列表
- **30+ 原生 iOS 工具** — 通讯录、日历、健康、天气、定位、提醒事项、相机、相册、浏览器、加密等
- **多 AI 服务商** — OpenAI、Anthropic、Gemini、Azure、Groq、xAI、OpenRouter、DeepSeek、豆包、aiProxy
- **实时语音** — 通过 OpenAI、Gemini、豆包的实时 API 进行语音对话
- **自定义技能** — 内置技能 + 用户可导入的自定义技能
- **本地执行** — 通过 `ios_system` 在设备上运行受控的 Shell 和 Python
- **角色与灵魂** — 可配置的 AI 人格和声音

## 架构

```
用户语音 → 语音引擎 → AI 服务商 → ROS 运行时 → 执行层 → 结果 → UI + 语音
```

**ROS (Rocky OS) 运行时** 是核心执行引擎：

| 模块 | 说明 |
|------|------|
| **会话 (Sessions)** | 对话和任务上下文，带状态机管理 |
| **工具 (Tools)** | 30+ iOS 原生桥接服务，注册在 `OpenRockyToolbox` 中 |
| **技能 (Skills)** | 内置技能和可导入的自定义技能，通过 `OpenRockySkillStore` 管理 |
| **语音 (Voice)** | OpenAI、Gemini、豆包的实时语音桥接 |
| **角色与灵魂 (Characters & Souls)** | 人格和声音配置 |
| **记忆 (Memory)** | 跨会话的持久化上下文 |

**三层执行架构：**

1. **iOS 原生桥接** — Swift 代码调用系统 API（通讯录、日历、健康等）
2. **AI 工具层** — 通过 AI 服务商 API 分发的操作
3. **本地执行** — 通过 `ios_system` 在沙盒中运行受控的 Shell/Python

**服务商架构：** 服务商 → 账户 → 模型（支持 10+ 后端）

## 快速开始

### 体验 Rocky

通过 [TestFlight](https://testflight.apple.com/join/GZtbEpXN) 下载最新 Beta 版。

### 从源码构建

参见 **[DEVELOP.md](DEVELOP.md)**，包含环境要求、构建说明、项目结构和部署详情。

## 相关仓库

| 平台 | 仓库 |
|------|------|
| iOS | [openrocky/openrocky](https://github.com/openrocky/openrocky) |
| Android | [openrocky/openrocky_android](https://github.com/openrocky/openrocky_android) |

## 社区

- **Discord** — [加入服务器](https://discord.gg/SvvsaDA4nE)
- **Telegram** — [@openrocky](https://t.me/openrocky)
- **X / Twitter** — [@everettjf](https://x.com/everettjf)
- **微信公众号** — 扫码关注获取最新动态

  <img src="wx.png" alt="微信公众号" width="150">

## 参与贡献

发现 Bug 或有功能建议？[提交 Issue](https://github.com/openrocky/openrocky/issues/new)。参见 [DEVELOP.md](DEVELOP.md) 搭建开发环境。

## Star History

[![Star History Chart](https://api.star-history.com/svg?repos=openrocky/openrocky&type=Date)](https://star-history.com/#openrocky/openrocky&Date)

## 许可证

Apache 2.0 — 详见 [LICENSE](LICENSE)。

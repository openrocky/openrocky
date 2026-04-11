# OpenRocky

> [English](README.md) | 中文

**Rocky** 是一款语音优先的 iPhone AI Agent 应用。**OpenRocky** 是其背后的开源项目。

Rocky 不是一个移动端聊天壳子，也不是把 Linux 容器塞进手机。它将语音交互、任务执行、系统桥接和结果回顾组织成一个原生的 iPhone Agent 体验。

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

## 项目结构

```
OpenRocky/                  # iOS 应用（Xcode 项目）
  OpenRocky/OpenRocky/      # 应用源码
    App/                    # 入口
    Features/               # UI 界面（首页、聊天、语音、设置、服务商）
    Models/                 # 数据模型
    Providers/              # AI 服务商配置与客户端
    Runtime/                # ROS 运行时核心
      Tools/                # 30+ 原生桥接服务
      Skills/               # 技能系统
      Voice/                # 实时语音客户端
    Theme/                  # 视觉主题
  OpenRockyTests/            # 单元测试（Swift Testing）
  OpenRockyUITests/          # UI 测试
Packages/               # 本地 Swift 包
  SwiftOpenAI/          # OpenAI API 与实时会话桥接
  LanguageModelChatUI/  # 基于 UIKit 的聊天详情视图
  MarkdownViewLocal/    # Markdown 渲染
  OpenRockyIOSSystem/       # ios_system 二进制框架
  OpenRockyPython/          # iOS 上的 Python 运行时
scripts/                # 构建与部署脚本
website/                # 文档站点（Docusaurus）
```

## 环境要求

- Xcode 26+
- iOS 26.0+ 部署目标
- Swift 6.0 严格并发模式
- macOS 构建环境（`ios_system` 不支持 iOS 模拟器）

## 构建

```bash
# 真机构建
xcodebuild build -scheme OpenRocky -project OpenRocky/OpenRocky.xcodeproj -destination 'generic/platform=iOS'

# 运行测试（模拟器）
xcodebuild test -scheme OpenRocky -project OpenRocky/OpenRocky.xcodeproj -destination 'platform=iOS Simulator,name=iPhone 16'

# 配置 Python 运行时（OpenRockyPython 包需要）
scripts/setup_python.sh
```

## 部署到 TestFlight

```bash
# 完整部署流程
./scripts/deploy.sh

# 或分步执行
ASC_API_KEY_ID=... ASC_API_ISSUER_ID=... ASC_API_KEY_P8_PATH=... scripts/testflight.sh all
```

## 开发

本项目由 [everettjf](https://github.com/everettjf) 在 [Claude Code](https://claude.ai/code) 和 [Codex](https://openai.com/codex) 的协助下开发。

### 代码风格

- 4 空格缩进，左花括号不换行
- 类型使用 `PascalCase`，属性/方法使用 `camelCase`
- 所有应用类型以 `OpenRocky` 为前缀
- SwiftUI + `@Observable` 宏，async/await 并发
- 提前返回、guard 语句、组合优于继承

### 测试

使用 Swift Testing 框架（`@Test`、`#expect`）。测试覆盖会话状态机、工具注册、服务商清单、技能存储和角色系统提示词。

## 许可证

详见 [LICENSE](LICENSE)。

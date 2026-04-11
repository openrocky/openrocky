# Contributing to OpenRocky

Thank you for your interest in contributing to OpenRocky!

## Getting Started

1. Fork the repository on [GitHub](https://github.com/openrocky/OpenRocky)
2. Clone your fork locally
3. Set up the development environment following the [Getting Started](https://openrocky.org/docs/getting-started) guide
4. Create a branch for your changes

## Development Requirements

- macOS with Xcode 26+
- iOS physical device (ios_system does not support Simulator)
- Swift 6.0, iOS 26.0+ deployment target

## Build & Test

```bash
# Build
xcodebuild build -scheme OpenRocky -project OpenRocky/OpenRocky.xcodeproj -destination 'generic/platform=iOS'

# Run tests
xcodebuild test -scheme OpenRocky -project OpenRocky/OpenRocky.xcodeproj -destination 'platform=iOS Simulator,name=iPhone 16'
```

## Areas for Contribution

- **iOS App** -- SwiftUI features, UI improvements, bug fixes
- **Runtime** -- Execution layer, skill/tool implementations
- **Documentation** -- Improving docs, adding guides, translations
- **Testing** -- Unit tests, integration tests

## Naming Convention

- **Rocky** — the product name for all user-facing contexts (home screen, Siri, App Store, permission dialogs)
- **OpenRocky** — the project name for code and infrastructure (Xcode project, class prefixes, package names, GitHub repo)

When writing user-visible strings (e.g. alert text, usage descriptions), use "Rocky". When writing code identifiers, use the `OpenRocky` prefix.

## Code Style

- 4-space indentation, opening brace on same line
- PascalCase for types, camelCase for properties/methods
- All app types prefixed with `OpenRocky`
- SwiftUI for UI, `@Observable` macro, async/await concurrency
- Early returns and guard statements preferred

## Pull Requests

- Keep PRs focused on a single change
- Include a clear description of what and why
- Ensure the project builds and tests pass
- Reference related issues in the PR description

## Communication

- [Discord](https://discord.gg/SvvsaDA4nE) -- Community discussions
- [Telegram](https://t.me/openrocky) -- Updates and chat
- [GitHub Issues](https://github.com/openrocky/OpenRocky/issues) -- Bug reports and feature requests

## License

By contributing, you agree that your contributions will be licensed under the [Apache License 2.0](LICENSE).

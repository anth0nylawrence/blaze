# Repository Guidelines

## Project Structure & Module Organization
- `Blaze/` is the Swift Package. Source lives in `Blaze/Sources/` organized by feature: `App/`, `UI/`, `Engine/`, `Core/`, `Data/`, `DesignSystem/`, `LanguageServices/`, `Terminal/`, `Security/`, `UIGallery/`.
- Tests are in `Blaze/Tests/` with unit tests in `BlazeTests/` and CLI integration tests in `IntegrationTests/`; fixtures live in `Blaze/Tests/Fixtures/NDJSON/`.
- App assets are in `Blaze/Resources/Assets.xcassets/`.
- Specs and research live in `docs/`, JSON schemas/templates in `references/`, and helper scripts in `scripts/` and `Blaze/dev/`.

## Build, Test, and Development Commands
- `swift build` builds the Swift package.
- `swift test` runs the full XCTest suite.
- `./Blaze/dev/run-mac.sh` builds and launches the macOS app (use `--release`, `--clean`, `--no-open`).
- `swift package resolve` refreshes dependencies when `Package.resolved` is missing.

## Coding Style & Naming Conventions
- Use Swift 5.9 style with 4-space indentation and standard Swift API Guidelines.
- Name types in PascalCase (`SessionStore`, `ToolPromptCard`); functions and properties in lowerCamelCase.
- Use role suffixes consistently: `*Adapter`, `*Store`, `*Coordinator`, `*Service`, `*Provider`.
- Match SwiftUI view file names to the view type (`ChatTimelineView.swift`, `FileTreeView.swift`).

## Testing Guidelines
- Tests use XCTest; keep unit tests fast and deterministic in `Blaze/Tests/BlazeTests/`.
- Integration tests in `Blaze/Tests/IntegrationTests/` require the Claude CLI (`npm install -g @anthropic/claude-code`) and may write traces; set `BLAZE_CI_TRACE_DIR` in CI.
- Run a specific test with `swift test --filter AskUserQuestionRoundTripTests`.

## Commit & Pull Request Guidelines
- Commit messages are short, imperative, and capitalized (`Add ...`, `Fix ...`, `Wire ...`), with optional phase tags in parentheses.
- PRs should include a brief description, tests run, and UI screenshots/recordings for visual changes; link relevant specs in `docs/` when applicable.

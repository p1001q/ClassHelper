# ClassHelper

ClassHelper is a personal macOS application for one university student that turns recorded lectures into structured learning notes with minimal manual work. The repository is currently at the bootstrap stage: it contains the verified Xcode scaffold and Canonical specifications, but the lecture-processing features are not implemented yet.

## Canonical stack

- Swift 6 and SwiftUI, minimum macOS 14
- Swift structured concurrency and native macOS frameworks, including AVAudioEngine and Keychain
- GRDB-backed SQLite for operational state
- OpenAI transcription and Responses APIs behind provider boundaries
- Local Markdown as the canonical learning artifact
- One-way Notion publication through the Notion API
- Unified Logging with privacy redaction

## Canonical documentation

Read these documents in order:

1. [`docs/00_Project_Overview.md`](docs/00_Project_Overview.md) — project identity, scope, and document map
2. [`docs/01_Product_Philosophy.md`](docs/01_Product_Philosophy.md) — decision principles
3. [`docs/02_Product_Requirements.md`](docs/02_Product_Requirements.md) — product behavior and acceptance criteria
4. [`docs/03_Technical_Design.md`](docs/03_Technical_Design.md) — architecture and technical contracts
5. [`docs/04_AI_Prompt_Specification.md`](docs/04_AI_Prompt_Specification.md) — AI prompt and output contracts
6. [`docs/05_Codex_Development_Guide.md`](docs/05_Codex_Development_Guide.md) — implementation and verification rules
7. [`docs/06_GitHub_Autonomous_Workflow.md`](docs/06_GitHub_Autonomous_Workflow.md) — GitHub collaboration and merge workflow

Repository-level agent instructions are in [`AGENTS.md`](AGENTS.md).

## Verified local commands

These commands were verified with Xcode 26.6 on Apple silicon. The explicit developer directory also works when the system-selected developer tools point to the standalone Command Line Tools.

Build:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build \
  -project ClassHelper.xcodeproj \
  -scheme ClassHelper \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /private/tmp/ClassHelperBootstrapSwift6Build \
  CODE_SIGNING_ALLOWED=NO
```

Unit tests:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project ClassHelper.xcodeproj \
  -scheme ClassHelper \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /private/tmp/ClassHelperBootstrapSwift6UnitTests \
  -only-testing:ClassHelperTests \
  CODE_SIGNING_ALLOWED=NO
```

UI tests use local ad-hoc signing so the runner can launch the app:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project ClassHelper.xcodeproj \
  -scheme ClassHelper \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /private/tmp/ClassHelperBootstrapSwift6UITestsSigned \
  -only-testing:ClassHelperUITests
```

Never commit credentials, real lecture recordings or transcripts, generated user notes, Recovery artifacts, runtime databases, or diagnostics containing lecture data. GitHub work after this one-time bootstrap follows [`docs/06_GitHub_Autonomous_Workflow.md`](docs/06_GitHub_Autonomous_Workflow.md).

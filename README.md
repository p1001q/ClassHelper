# ClassHelper

ClassHelper는 한 명의 대학생이 녹음한 강의를 최소한의 수작업으로 구조화된 학습 노트로 변환하는 개인용 macOS 애플리케이션입니다. 현재 저장소에는 검증된 Xcode 기본 구조와 Canonical 명세가 준비되어 있으며, 강의 처리 기능은 아직 구현되지 않았습니다.

## Canonical 기술 구성

- Swift 6, SwiftUI, 최소 지원 macOS 14
- Swift 구조화된 동시성과 AVAudioEngine·Keychain을 포함한 네이티브 macOS 프레임워크
- 작업 상태 저장을 위한 GRDB 기반 SQLite
- 제공자 경계 뒤에서 사용하는 OpenAI transcription 및 Responses API
- Canonical 학습 산출물인 로컬 Markdown
- Notion API를 통한 단방향 Notion 게시
- 개인정보를 가리는 Unified Logging

## Canonical 문서

다음 문서를 순서대로 읽으세요.

1. [`docs/00_Project_Overview.md`](docs/00_Project_Overview.md) — 프로젝트 정체성, 범위, 문서 지도
2. [`docs/01_Product_Philosophy.md`](docs/01_Product_Philosophy.md) — 의사결정 원칙
3. [`docs/02_Product_Requirements.md`](docs/02_Product_Requirements.md) — 제품 동작과 Acceptance Criteria
4. [`docs/03_Technical_Design.md`](docs/03_Technical_Design.md) — 아키텍처와 기술 계약
5. [`docs/04_AI_Prompt_Specification.md`](docs/04_AI_Prompt_Specification.md) — AI prompt 및 출력 계약
6. [`docs/05_Codex_Development_Guide.md`](docs/05_Codex_Development_Guide.md) — 구현과 검증 규칙
7. [`docs/06_GitHub_Autonomous_Workflow.md`](docs/06_GitHub_Autonomous_Workflow.md) — GitHub 협업 및 Merge 절차

저장소 수준의 agent 지침은 [`AGENTS.md`](AGENTS.md)에 있습니다.

## 검증된 로컬 명령

다음 명령은 Apple silicon 환경의 Xcode 26.6에서 검증했습니다. 시스템의 개발자 도구가 독립 실행형 Command Line Tools를 가리키는 경우에도 명시된 developer directory를 사용하면 실행할 수 있습니다.

빌드:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build \
  -project ClassHelper.xcodeproj \
  -scheme ClassHelper \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /private/tmp/ClassHelperBootstrapSwift6Build \
  CODE_SIGNING_ALLOWED=NO
```

단위 테스트:

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

UI 테스트는 테스트 실행기가 애플리케이션을 실행할 수 있도록 로컬 ad-hoc signing을 사용합니다.

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project ClassHelper.xcodeproj \
  -scheme ClassHelper \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /private/tmp/ClassHelperBootstrapSwift6UITestsSigned \
  -only-testing:ClassHelperUITests
```

인증 정보, 실제 강의 녹음이나 transcript, 생성된 사용자 note, Recovery artifact, runtime database 또는 강의 데이터가 포함된 진단 정보는 절대 Commit하지 마세요. 최초 저장소 구성 이후의 GitHub 작업은 [`docs/06_GitHub_Autonomous_Workflow.md`](docs/06_GitHub_Autonomous_Workflow.md)를 따릅니다.

# ClassHelper

> Codex Development Guide

**Status:** Canonical  
**Authority:** Implementation workflow, task decomposition, verification procedure, and Codex working/reporting rules  
**Depends on:** `00_Project_Overview.md`, `01_Product_Philosophy.md`, `02_Product_Requirements.md`, `03_Technical_Design.md`, `04_AI_Prompt_Specification.md`

---

## 1. Purpose and authority boundary

This document tells Codex how to implement and verify ClassHelper. It governs work order, task size, permitted edits, evidence, testing, stopping, and reporting. It does not define or revise product scope, product behavior, architecture, provider/model choices, persistence semantics, prompts, schemas, provenance, rendering, or acceptance policy.

The five upstream canonical documents are the authoritative source. Code and tests implement them; this guide only operationalizes the work. A convenient implementation is not a reason to reinterpret an upstream rule.

### 1.1 Document authority and precedence

Use the document responsible for the disputed subject:

1. `00_Project_Overview.md` — project identity, target, scope, intended experience, phases, documentation map.
2. `01_Product_Philosophy.md` — decision principles and non-negotiable constraints.
3. `02_Product_Requirements.md` — product behavior, states, artifacts, recovery policy, stages, and acceptance criteria.
4. `03_Technical_Design.md` — architecture, frameworks, APIs, persistence, security, retry, recovery, and verification mechanics.
5. `04_AI_Prompt_Specification.md` — prompt/schema contract, grounding, provenance, uncertainty, validation, correction retry, rendering, and prompt/schema versions.
6. `05_Codex_Development_Guide.md` — workflow only.

This ordering expresses dependency, not permission for a broad upstream document to overwrite a downstream decision inside the downstream document's assigned authority. When two statements appear inconsistent, first apply the responsibility map in `00 §Documentation Responsibilities` and each document's authority boundary. If a real conflict remains, the earlier upstream canonical document wins, but Codex MUST stop and report the exact sections; it MUST NOT select an interpretation, edit a canonical document, or encode one side in code.

Existing code, tests, comments, README files, tickets, and external documentation never outrank 00–04. Official API documentation may constrain adapter mechanics; it cannot change ClassHelper policy. If an official constraint makes the canonical design impossible, stop and report.

---

## 2. Mandatory reading before work

Before the first implementation task, and after any upstream canonical revision, read the current files completely in this order:

1. `00_Project_Overview.md`
2. `01_Product_Philosophy.md`
3. `02_Product_Requirements.md`
4. `03_Technical_Design.md`
5. `04_AI_Prompt_Specification.md`
6. this guide
7. repository-level instructions such as `AGENTS.md` and `README.md`

For every later task, re-read the exact canonical sections governing the requested behavior and their referenced upstream sections. Do not rely on memory, summaries, prior chat, or test names as the contract. Record the filenames and section numbers used in the completion report.

---

## 3. Delivery stages and implementation order

### 3.1 Stage boundary

Complete and accept the **Core Local MVP** before implementing the **Notion Publication Stage**. Notion credentials, publication, and publication tests MUST NOT block Core Local MVP completion. Publication consumes a verified canonical local note and must not reshape the local pipeline.

Within a stage, implement small vertical slices. Each slice must establish one observable behavior across the minimum required layers, with focused tests. A slice is not permission to stub away durability or safety at a boundary it claims to complete.

### 3.2 Recommended sequence

The recommended order is:

1. **Project scaffold** — Swift 6/macOS 14 app and test targets, source layout from `03 §5`, build configuration, dependency setup, and test seams. No feature behavior is invented here.
2. **Domain state** — three independent state axes, stable session identity/time, typed commands/errors, legal transitions, and duplicate command gates.
3. **Persistence** — GRDB/SQLite schema, constraints, WAL/foreign keys, forward-only migrations, repositories, transaction boundaries, and fail-closed database startup.
4. **Recovery foundation** — immutable `session.json`, recovery paths, artifact inventory/validation, launch reconciliation, verified successor-before-predecessor deletion, resumable Discard, and unrecoverable cleanup.
5. **Audio capture** — permission/device/disk checks; Start/Pause/Resume/Stop including Stop from Pause; fixed recovery CAF; bounded callback path; subtitle conversion seam; capture failures and durable Stop.
6. **Transcription** — optional Realtime subtitles isolated from the canonical path; Stop-time transcription from retained local audio; WAV preparation/chunk checkpoints; transcript structural/hash/lexical verification; stage-aware retry and cleanup.
7. **Note generation** — title and note adapters, exact 04 messages/envelopes/schemas, complete-input preflight, deterministic validation, exactly one eligible correction retry, title fallback, rendering, and validated draft retention.
8. **Canonical save** — deterministic path/slug, SQLite reservation, same-session adoption or safe replacement, different-session suffixing, exclusive no-clobber install, final read-back verification, `LOCAL_COMPLETE`, and successor-driven cleanup.
9. **Recovery UI** — visible stage/reason, permitted Retry/Discard/prerequisite actions, quit warning, relaunch items, and independence of new recordings from older sessions.
10. **Notion publication** — setup/Keychain, local-note-only conversion, deterministic markers, complete pagination, duplicate-safe reconciliation, limit-safe batches, unknown-success recovery, divergence refusal, and publication-state isolation.
11. **Final acceptance** — automated regression, failure/crash evidence, AC-22/AC-23 real-lecture review for Core Local MVP, then AC-17–20 destination tests for the Notion stage.

This sequence is scheduling guidance only. It MUST NOT alter component boundaries or technical decisions in 03. A prerequisite may be built earlier in a minimal form, but Notion production behavior remains outside the Core Local MVP stage.

---

## 4. Task decomposition and work-unit contract

### 4.1 One clear goal

One Codex task has one outcome that can be stated and verified in one sentence. Prefer a small vertical slice, for example:

- “Persist and reject invalid `READY → RECORDING` transitions with unit tests.”
- “Save a new canonical note without clobbering another session's file.”
- “Route a lexically invalid transcript to transcription recovery before audio deletion.”

Do not combine capture, transcription, saving, recovery UI, and Notion publication into one change. Split work when it crosses unrelated failure domains, independent acceptance criteria, or multiple architectural components that can be verified separately.

### 4.2 Required task input

Before editing, write down:

- one goal and the user-visible or internal outcome;
- governing 00–04 sections and acceptance criteria;
- expected input/state and output/state;
- permitted files/modules and explicitly excluded areas;
- invariants and failure paths affected;
- planned tests and observable pass condition;
- external API assumptions requiring current official verification.

If these cannot be stated without guessing, investigate. If canonical material does not resolve a policy choice, stop and report instead of inventing one.

### 4.3 Allowed change scope

Change only the smallest coherent set of production files, tests, fixtures, and narrowly necessary project configuration. A related test change is part of the same work unit. A prerequisite refactor is allowed only when necessary for the stated goal, behavior-preserving, small, and called out in advance or in the report.

Do not perform drive-by cleanup, renaming, formatting of unrelated files, dependency upgrades, architecture changes, or speculative abstractions. When the requested task is too large, divide it into ordered work units and complete only the authorized unit.

### 4.4 Completion criteria

A work unit is complete only when:

- its stated behavior and directly related failure paths are implemented;
- every governing invariant remains true;
- all applicable focused tests pass using verified project commands;
- all applicable integration/failure/UI/contract tests for the touched boundary pass;
- when the work unit creates the first runnable test configuration, project creation, target/scheme discovery, build configuration, test-target creation, and configuration inspection provide the verification available at that stage;
- any test that cannot run is reported exactly as `NOT AVAILABLE` or `NOT RUN`, with the reason;
- changed code and tests have been self-reviewed from the final diff when Git metadata exists;
- when Git metadata does not exist, `git status`, `git diff`, and working-tree verification are reported `NOT AVAILABLE`, and repository-relative file inventory, created/modified file lists, file-content comparison, and project-configuration inspection provide the required replacement review; this exception applies only to absent Git metadata and never permits omission of Git verification when a Git repository exists;
- no unexplained warning, skipped assertion, ignored failure, secret, user data, or unintended file remains;
- documentation/reporting names any remaining limitation without presenting the task as fully complete.

### 4.5 Failure and stop boundary

Stop the work unit before further edits when a condition in Section 12 occurs. Preserve current evidence, make no speculative workaround, and report the blocker. A failing focused test is normally a reason to diagnose and continue; it becomes a stop condition when resolving it requires a product decision, risky migration, data-destructive action, or out-of-scope change.

---

## 5. Investigation before changes

Codex MUST inspect, in order:

1. the relevant canonical sections, their cross-references, and acceptance criteria;
2. repository instructions and the actual project/package/scheme configuration;
3. existing implementation, call sites, state transitions, persistence boundaries, adapters, and UI consumers;
4. existing focused tests, fixtures, test doubles, and nearby failure cases;
5. the current diff and working-tree status to distinguish user changes from task changes when Git metadata exists; when Git metadata does not exist, report those checks `NOT AVAILABLE` and instead inspect the repository-relative file inventory, created/modified file list, file contents, and project configuration; this replacement review applies only to absent Git metadata and cannot justify skipping status/diff inspection in an existing Git repository;
6. current official API documentation when implementing or changing Apple, OpenAI, Notion, GRDB, Swift/Xcode, or other version-sensitive mechanics.

Use primary official documentation for API mechanics. Record the checked page and relevant version/date when it changes an adapter assumption. Do not use blog posts, remembered SDK shapes, sample code, or external knowledge to supplement product policy.

Search for existing types and conventions before creating new ones. Trace both success and failure paths. Do not infer behavior from a type name alone. Never guess an endpoint, model ID, request field, format, limit, event name, Notion version, framework API, Xcode scheme, or test command.

---

## 6. File and repository rules

- Preserve existing repository conventions unless they conflict with 00–04.
- Make minimal, localized edits; add new files only in the 03-defined source layout or the project's established equivalent.
- Do not refactor unrelated code or reformat unrelated files.
- Do not hardcode usernames, machine paths, API keys, Notion tokens, credentials, or other secrets.
- Keep secrets in Keychain and momentary memory only as specified by 03. Do not place them in source, build settings committed to Git, fixtures, SQLite, recovery data, notes, or logs.
- Do not add generated files, derived build output, dependency caches, recordings, transcripts, canonical notes containing real lecture data, or large binaries to version control.
- Do not modify generated files by hand. Change their declared source only when that source is within task scope, then regenerate with the project's verified process.
- Preserve pre-existing user changes. Do not overwrite or “clean up” a dirty worktree. If an unexpected overlapping change cannot be safely separated, stop and report.
- Git status, log, and diff inspection are allowed. Do not commit, amend, push, create/update a PR, tag, merge, or publish unless the user explicitly requests that action.
- Do not run `git init` unless the user explicitly requests it. Whenever Git metadata is absent, report Git verification `NOT AVAILABLE` and use the replacement review in §§4.4 and 5; this exception applies only to absent Git metadata and never permits omission of status/diff inspection when a Git repository exists.
- Destructive Git commands are a separate prohibited category with no approval exception in the normal workflow. Do not run `git reset --hard`, destructive checkout/restore, `git clean`, force push, hook bypass, forced branch rewriting, or equivalent operations that can discard or rewrite user work.

Canonical documents are read-only during implementation. Codex MUST NOT automatically edit 00–04 to make code or tests pass. A requested canonical revision is a separate documentation task with its own review.

---

## 7. ClassHelper implementation invariant checklist

For every task, mark each relevant invariant as **applies/pass**, **not applicable**, or **blocked**. The checklist points back to 02–04 and does not replace them.

### 7.1 Architecture and authority

- Swift 6 native macOS 14 application and SwiftUI/AppKit interoperability remain as selected in `03 §2–5`.
- Mutable subsystems remain actor-isolated; views do not call providers or mutate persistence directly.
- `AppCoordinator` accepts idempotent intents; local processing and publication retain their separate serial work queues.
- Provider mechanics remain behind `TranscriptionClient`, `NoteGenerationClient`, and `NotionClient` boundaries.
- SQLite through GRDB is the sole operational state authority. `session.json` contains immutable identity/time only and recovery files are not a shadow database.
- Keychain stores OpenAI and Notion secrets. No persisted artifact contains secrets. Logs, operational metadata, error messages, diagnostics, completion reports, and version-controlled files or fixtures contain neither secrets nor real user lecture content. Recovery artifacts and canonical Markdown may contain lecture content only at the paths and lifecycle stages explicitly authorized by 02 and 03.

### 7.2 Identity, persistence, recovery, and save

- One UUID v4 and immutable lecture time identity survive Pause/Resume/Stop, retries, crashes, canonical recognition, and publication.
- The recording, local-processing, and publication state axes remain independent; returning to `READY` does not erase or merge older work.
- State changes and asynchronous calls respect the 03 transaction boundaries; network calls never run inside a database transaction.
- Recovery preserves the most advanced verified artifact. There is no age-based cleanup for unresolved recoverable data.
- Successor verification and durable stage persistence precede predecessor deletion; deletion is verified and crash-reconcilable.
- A database open/migration/integrity failure fails closed and deletes nothing.
- Discard and unrecoverable cleanup follow resumable, verified deletion protocols; canonical Markdown is never cleanup input.
- Canonical save uses a same-directory temporary file, synchronization, validation, exclusive no-clobber installation, final read-back, and only then `LOCAL_COMPLETE`.
- A valid same-session target is adopted; only the recorded incomplete same-session target may be safely replaced. A different or unparseable target is unchanged and receives deterministic suffix handling.
- Local Markdown remains canonical. Notion failure never changes it, local state, or its bytes.

### 7.3 Audio and transcription

- `AVAudioEngine` capture writes the fixed recovery CAF through work outside the tap callback; the callback performs no I/O, conversion, allocation, locks, task/actor hop, network, database, parsing, or UI work.
- Bounded-buffer overrun/device/write/configuration failure is visible capture failure, never silent loss.
- Pause retains the same session and Stop works from Pause.
- Realtime is subtitle-only. It never becomes the final transcript or affects whether final transcription is required.
- The canonical transcript is always produced after Stop from verified retained local audio, with current supported upload mechanics confirmed by adapter contract tests.
- Transcript schema/hash and 04 lexical sufficiency checks all pass before verified state is persisted or audio/chunks are deleted. Invalid/no-lexical output remains a transcription failure with `Transcript 재생성`.

### 7.4 Generation and rendering

- Only the complete verified finalized transcript is used; no live subtitles, raw audio, previous Notion content, external retrieval, or silent truncation enters generation.
- Title and note use their distinct exact User-envelope prompt/schema version pairs and JSON serialization; transcript text remains untrusted data.
- Prompts, strict schemas, role order, renderer strings, provenance, uncertainty, and validation gates match 04 exactly.
- A content-correction-eligible completed response receives exactly one automatic correction retry with the unchanged complete User envelope and allowlisted code/path feedback only.
- Provider retries are separate from correction retry. Refusal, incomplete/content-filter output, transport/auth/rate-limit/timeout/server errors are not content-correction retries.
- Title failure uses the deterministic immutable-start-time fallback and does not block note generation.
- Runtime gates are only the deterministic gates in `04 §11.4/§12`. Semantic grounding/provenance quality remains fixture and AC-23 review; no heuristic semantic gate or extra AI verifier is added.
- The renderer injects the five front-matter keys, matching H1, five ordered H2 sections, exact empty/uncertainty wording, and visible `**AI 보충 설명:**` labels. Model metadata and evidence IDs do not enter canonical Markdown.
- System, title prompt, title schema, note prompt, note schema, validation-retry prompt, and renderer versions remain independently recorded as required by `04 §13`; they are not added to canonical front matter.

### 7.5 Notion publication

- Implement only after Core Local MVP acceptance. Publish only from verified `LOCAL_COMPLETE` Markdown; never regenerate or import Notion edits.
- Keep one selected parent, one marked date page per immutable local date, and one marked toggle per stable session ID.
- Fully paginate and verify exact parent/markers; search or title alone never proves identity or absence.
- Persist returned identities before continuing; retry reconciles unknown success and appends only a verified missing suffix.
- Divergent/user-authored content causes visible failure without overwrite, deletion, rebuild, or conflict resolution. Cleanup is restricted to exact IDs from the same incomplete attempt ledger.
- Conversion preserves order and meaning without silent truncation and enforces the current official Notion limits centralized by 03.

---

## 8. Testing policy

### 8.1 Order and scope

Run tests in this order, stopping to diagnose a failure before broadening the run:

1. **Focused unit tests** for changed pure logic, state transitions, validation, rendering, classification, and boundaries.
2. **Focused integration tests** using temporary support/output locations, real SQLite where applicable, fixtures, and local protocol fakes.
3. **Failure-injection/crash tests** for every changed durability, deletion, retry, no-clobber, or unknown-success boundary.
4. **Focused UI tests** for changed controls, state visibility, recovery action, warning, or completion messaging.
5. **Provider contract tests** when an adapter, request/response shape, model/format/limit, pagination, API version, or credential boundary changes. Live provider contract tests are opt-in, require explicit user authorization, and use dedicated credentials/destinations. Without that authorization, use local protocol fakes only and report the live contract test as `NOT RUN`.
6. **Full automated regression** when the work unit is otherwise green and any full-regression condition below applies.
7. **Real-lecture acceptance** only at the milestone required by 02: AC-22 and AC-23 before Core Local MVP acceptance; AC-17–20 against the configured Notion destination before Notion-stage acceptance.

Automated tests do not replace the human evidence required by AC-22/AC-23. Real lecture content and reviewer material must not enter production bundles or ordinary logs; retain only the redacted worksheet described by 03.

### 8.2 Full-regression conditions

Run the complete available automated suite before declaring a milestone complete and whenever a change affects shared domain state, database schema/migration, recovery reconciliation/deletion, audio buffer/capture behavior, transcript assembly, generation schema/renderer, canonical save/path identity, Notion conversion/reconciliation, common networking/retry code, concurrency, project configuration, dependencies, or more than one feature boundary. Also run it when focused tests reveal an unexpected cross-module dependency.

If the full suite is impractical or unavailable, do not claim it passed. Report exactly what ran, what did not, and why.

### 8.3 Failure and flaky-test handling

- Never ignore, delete, weaken, skip, quarantine, or disable a failing test merely to obtain green status.
- First reproduce a failure with the smallest relevant command; inspect whether the test, implementation, environment, fixture, or canonical expectation is wrong.
- A test that conflicts with 00–04 must be reported and corrected only within the authorized task; canonical policy is not changed to satisfy it.
- A suspected flaky test must be rerun enough to capture both outcomes, with seed/order/timing/environment recorded when available. Diagnose shared state, clocks, concurrency, network, filesystem, and nondeterminism.
- Do not add blind retries or loosen assertions as a flaky-test fix. A bounded retry is acceptable only if the product or official API contract requires it and the assertion still proves the intended behavior.
- Unresolved flakiness is an unresolved issue and blocks claims covered by that test.

### 8.4 Test data and isolation

Use synthetic or explicitly approved redacted fixtures. Tests must use temporary Application Support/output directories, isolated SQLite databases, fake clocks/filesystems/network adapters where appropriate, and dedicated provider resources for explicitly authorized opt-in live contracts. Never print request bodies, transcript/note content, credentials, raw paths, or user data. This restriction does not prohibit normal application processing, authorized recovery/canonical storage, or user display of transcript/note content.

---

## 9. Verification commands

There may be no Xcode or SwiftPM project yet. Therefore this document does not prescribe a command that may not exist.

After the project is created, Codex MUST discover and record actual commands from the repository's `README`, `Package.swift`, Xcode project/workspace, shared schemes, and CI configuration. Confirm target and scheme names from project metadata rather than guessing. Record the exact command and working directory in the completion report.

`swift test` is an example only when a real `Package.swift` defines the relevant package/tests. `xcodebuild test` is an example only after the actual project/workspace, shared scheme, destination, and configuration have been verified. Neither is a mandatory command by virtue of appearing here.

For each work unit:

1. record the verified focused test command(s);
2. record any build/static-analysis/format command the repository actually configures;
3. record the verified full-suite command when Section 8.2 requires it;
4. capture exit status and a concise pass/fail/skip count or equivalent result;
5. distinguish “not run,” “not available,” and “failed”; never label any of them “passed.”

If the work unit creates the first runnable project/test configuration and no test foundation exists yet, verify everything available at that stage: project creation, target/scheme discovery, build configuration, test-target creation, and configuration inspection. Report unavailable tests as `NOT AVAILABLE` and tests that exist but were not executed as `NOT RUN`, with the reason. This exception is limited to the initial scaffold work that creates the test foundation; it never permits omission of an existing runnable test. Do not invent placeholder scripts or commands to satisfy the report format.

---

## 10. Codex work and response protocol

### 10.1 During work

- State the active goal and relevant boundary before editing.
- Keep the user informed when investigation finds a material assumption, blocker, unexpected change, or test failure.
- Do not claim success before inspecting the final diff and test results when Git metadata exists, or before completing the defined replacement review and inspecting test results when Git metadata does not exist. The replacement review applies only to absent Git metadata and cannot justify skipping final-diff inspection in an existing Git repository.
- Do not perform external state changes—commit, push, PR, publication, destructive cleanup, or provider-resource changes—without explicit authorization when required.

### 10.2 Required completion report

Every implementation completion report uses these fields:

```markdown
## 목표
<one-sentence outcome>

## 읽은 문서와 근거
- <canonical file §section / AC>
- <official API reference and checked version/date, if applicable>

## 변경 파일
- `<repository-relative source/test/document/config path>` — <why it changed>

## 구현 내용
- <observable behavior and failure behavior>

## 관련 Invariant 확인
- <invariant> — APPLIES/PASS
- <invariant> — NOT APPLICABLE; <reason>
- <invariant> — BLOCKED; <reason>

## 테스트
- `<verified command or test>` — PASS/FAIL/NOT AVAILABLE/NOT RUN; <result summary or reason>

## 미해결 사항
- 없음
  또는
- <risk, blocker, or unverified condition>

## Canonical 충돌 여부
- 없음
  또는
- <exact conflicting sections; implementation stopped>
```

Do not hide partial completion in prose. If tests did not run or a stop condition occurred, lead with that limitation.

Repository-relative source, test, document, and configuration paths are required in completion and blocker reports and are not treated as protected raw paths. Do not report a user-home absolute path, the actual output-root path, an actual Recovery artifact or canonical-note path, or any sensitive path containing a session ID. Redact those paths or describe them by category, for example `Services/Audio/RecordingController.swift` and `<Recovery>/<session>/audio.caf`.

---

## 11. Prohibited actions

Codex MUST NOT:

- expand scope or add hypothetical extensibility;
- add hidden fallback, false completion, silent recovery, silent truncation, or lossy chunk-summary-merge;
- use external knowledge to fill gaps in product policy or lecture content;
- change an API, provider, endpoint, model, audio format, API version, prompt, schema, validator, renderer, or retry rule arbitrarily;
- add a hosted backend, application-managed cloud storage/state, sync engine, editor, transcript/audio library, multi-user/account/collaboration support, mobile/web client, OCR, PDF/screen capture, diarization, analytics, or other out-of-scope feature;
- make Notion authoritative, regenerate content for publication, import Notion edits, or add bidirectional synchronization;
- automatically edit a canonical document, or reinterpret an acceptance criterion to match implementation;
- delete, disable, skip, weaken, or conceal a test failure;
- log or expose in diagnostics or work/completion reports credentials, headers/bodies, prompts/responses, transcript/note content, user data, user-home absolute paths, actual output-root paths, actual Recovery artifact or canonical-note paths, session-ID-bearing sensitive paths, or other protected data; redact protected paths or use category-based forms such as `<Recovery>/<session>/audio.caf`. Repository-relative source/test/document/config paths are permitted and required where §§10.2 and 12 call for them. This does not prohibit normal application processing, storage authorized by 02 and 03, or user display of transcript/note content;
- persist secrets outside Keychain or put real lecture artifacts/large binaries/generated build output in version control;
- overwrite another session's canonical file or user-authored Notion content;
- commit, amend, push, open/update a PR, tag, merge, or publish without an explicit user request;
- execute a destructive Git operation prohibited by Section 6.

---

## 12. Stop-and-report conditions

Stop before committing to an implementation direction and report evidence when any of these occurs:

1. **Canonical conflict or ambiguity:** two governing canonical sections prescribe incompatible behavior, or a required policy decision is absent.
2. **Official API impossibility:** current official Apple/OpenAI/Notion/GRDB/Swift/Xcode constraints make the canonical design impossible or invalidate a required request/format/limit. Include the official source and affected sections.
3. **Data-loss or privacy risk:** a proposed action could delete the sole recoverable artifact, overwrite another session/user-owned content, leak lecture data or a secret, falsely mark completion, or bypass read-back verification.
4. **Migration risk:** a database/recovery/prompt-schema/renderer/publication-version change lacks a forward-only migration and tests from every released local schema, could orphan data, or encounters an unknown newer recovery schema.
5. **Unexpected existing change:** the working tree contains overlapping user edits, generated changes, dependency/configuration drift, or a surprising broad code change that cannot be safely attributed or isolated.
6. **Scope expansion required:** completion would require a hosted service, cloud storage, editor, multi-user behavior, unsupported feature, canonical change, or unrelated architectural redesign.
7. **Verification cannot support the claim:** required focused/full/contract/acceptance tests are unavailable or repeatedly flaky, and the unverified behavior is material to completion.

The report must state the goal, evidence, exact repository-relative source/test/document/config files and canonical sections, data at risk, safe work already completed, and the smallest user or design decision needed. Protected paths must be redacted or category-based as required by §10.2; do not include user-home absolute paths, actual output-root/Recovery/canonical-note paths, or session-ID-bearing sensitive paths. Do not conceal the problem behind a fallback or continue into adjacent work.

---

## 13. Self-review and definition of done

### 13.1 Self-review after every work unit

Mark every item **PASS**, **NOT APPLICABLE**, or **BLOCKED**, adding a reason for the latter two.

- [ ] When Git metadata exists, working-tree status and the final diff were inspected and the final diff contains only files required by the stated goal. When Git metadata does not exist, those Git checks are `NOT AVAILABLE` and the repository-relative inventory, created/modified file list, file contents, and project configuration were inspected instead; this replacement review was not used to omit Git checks for an existing repository.
- [ ] The cited 00–04 sections and acceptance criteria were re-read and remain unchanged.
- [ ] Success, failure, retry, crash/relaunch, concurrency, and cleanup paths relevant to the change were traced.
- [ ] Relevant Section 7 invariants are marked and satisfied.
- [ ] No hidden fallback, silent truncation, false completion, or speculative policy was introduced.
- [ ] State transitions are durable/idempotent and preserve the same session identity where applicable.
- [ ] Successor verification occurs before predecessor deletion; no sole recovery source is endangered.
- [ ] No persisted artifact contains secrets. Logs, operational metadata, error messages, diagnostics, completion reports, and version-controlled files or fixtures contain neither secrets nor real user lecture content. Recovery artifacts and canonical Markdown contain lecture content only where 02 and 03 authorize it; test fixtures are synthetic or explicitly approved redacted data.
- [ ] Applicable focused tests ran first; applicable integration/failure/UI/contract/full tests followed and results were inspected. Initial scaffold verification follows §4.4 and §9 only when no runnable test foundation exists.
- [ ] Live provider contract tests had explicit user authorization and dedicated credentials/destinations, or local protocol fakes were used and the live test was reported `NOT RUN`.
- [ ] No failing or flaky test was ignored, weakened, or disabled.
- [ ] The applicable Git or replacement review was performed without altering unrelated user work; absence of Git metadata was not used to omit any available review, and an existing repository's status/diff checks were not skipped.
- [ ] No `git init`, commit, amend, push, PR, tag, merge, or publication occurred without explicit user request, and no prohibited destructive Git action occurred.
- [ ] The completion report is exact about passed, failed, `NOT AVAILABLE`, and `NOT RUN` verification and any unresolved issue.

### 13.2 Definition of done for a work unit

A work unit is done when its single goal is implemented with the smallest coherent change, its canonical evidence is cited, directly affected acceptance behavior and failure paths are tested, all applicable required tests are green, final self-review passes, and no unresolved issue undermines the claimed outcome. When Git metadata exists, final self-review includes the required working-tree and final-diff inspection; when Git metadata does not exist, Git verification is reported `NOT AVAILABLE` and the defined replacement review must pass. The replacement applies only to absent Git metadata and cannot justify omitting Git checks in an existing repository. For an initial scaffold that creates the runnable test foundation, only the stage-available verification in §4.4 and §9 may substitute for tests that are accurately reported `NOT AVAILABLE` or `NOT RUN`; this is not a basis for omitting existing tests.

### 13.3 Definition of done for stages

**Core Local MVP** is done only when AC-01–16 and AC-21–24 pass, including recorded AC-22 and AC-23 real-lecture evidence, and no Notion dependency is required.

**Notion Publication Stage** is done only after Core Local MVP acceptance and AC-17–20 additionally pass against the configured destination, including duplicate/unknown-success behavior and five sessions on one date. A Notion failure never revokes local completion or Core Local MVP acceptance.

Project completion claims must identify the exact accepted stage; “done” must not collapse local and publication status.

---

## 14. Document versioning and status

This guide begins as:

```text
**Status:** Canonical Candidate
```

While it is a candidate, review it against every requirement in 00–04 and this guide's requested scope. A Codex final review must return **PASS** with no mandatory changes before promotion. Promotion changes only the status line to:

```text
**Status:** Canonical
```

Do not rewrite unrelated content during promotion. Later workflow changes require a separate reviewed revision. This guide cannot promote itself by assertion and cannot change 00–04 through its own versioning.

---

## 15. Representative task request template

```markdown
# 작업 목표
<one observable outcome>

# Stage
Core Local MVP | Notion Publication Stage

# Canonical 근거
- `02_Product_Requirements.md §...`, AC-...
- `03_Technical_Design.md §...`
- `04_AI_Prompt_Specification.md §...` (if applicable)

# 입력/시작 상태
<fixture, persisted state, artifact, or user action>

# 기대 결과/종료 상태
<observable behavior, state, and retained/deleted artifacts>

# 허용 변경 범위
- `<module/path>`

# 제외 범위
- <explicitly excluded behavior or module>

# 필수 검증
- <focused unit/integration/failure/UI/contract cases>
- <full-regression condition if applicable>

# 중단 조건
- Canonical 충돌, data-loss/migration risk, official API impossibility, or unexpected overlapping changes

# Git/외부 작업 권한
- commit/push/PR/publication: 요청 없음
```

### Example

```markdown
# 작업 목표
검증된 transcript가 없는 recoverable session에서 같은 session ID와 retained audio로 `Transcript 재생성`을 수행한다.

# Stage
Core Local MVP

# Canonical 근거
- `02_Product_Requirements.md §5.4, §9.4`, AC-11/12/14
- `03_Technical_Design.md §7.3, §9.4, §14`
- `04_AI_Prompt_Specification.md §3.2`

# 입력/시작 상태
`RECOVERABLE_FAILED`, usable `audio.caf`, no verified `transcript.json`

# 기대 결과/종료 상태
Retry reuses the session ID, runs transcript finalization, and deletes audio only after all transcript verification gates pass.

# 허용 변경 범위
- transcription pipeline, repository transition, recovery tests, recovery action wiring

# 제외 범위
- note generation, canonical save, Notion publication

# 필수 검증
- success, invalid lexical result, provider failure, repeated retry failure, crash before/after verified-stage persistence and audio deletion

# Git/외부 작업 권한
- commit/push/PR: 요청 없음
```

---

## 16. Representative completion report template

```markdown
## 목표
Retained audio에서 same-session transcript retry를 구현했습니다.

## 읽은 문서와 근거
- `02_Product_Requirements.md §5.4, §9.4`, AC-11/12/14
- `03_Technical_Design.md §7.3, §9.4, §14`
- `04_AI_Prompt_Specification.md §3.2`
- <official API page/version/date, when adapter mechanics changed>

## 변경 파일
- `Services/Transcription/TranscriptRetryCoordinator.swift` — retry orchestration
- `Persistence/SessionStore.swift` — persistence transition
- `Tests/Transcription/TranscriptRetryTests.swift` — focused and failure-injection coverage

## 구현 내용
- 기존 session ID와 verified artifact inventory를 재사용했습니다.
- schema/hash/lexical verification과 durable verified-state persistence 뒤에만 audio cleanup이 실행됩니다.
- 실패 후 recovery source가 남으면 `RECOVERABLE_FAILED`로 돌아갑니다.

## 관련 Invariant 확인
- Same-session identity survives retry — APPLIES/PASS
- Successor verification precedes predecessor deletion — APPLIES/PASS
- Notion publication invariants — NOT APPLICABLE; Core Local MVP transcription retry only

## 테스트
- `<actual verified focused command>` — PASS; <summary>
- `<actual verified failure-injection command>` — PASS; <summary>
- `<actual verified full-suite command>` — PASS/NOT AVAILABLE/NOT RUN; <summary or reason>
- `git status` / `git diff` — PASS when Git metadata exists; when Git metadata does not exist, `NOT AVAILABLE` with repository-relative inventory, created/modified file list, file-content comparison, and project-configuration inspection summarized instead; this replacement review applies only to absent Git metadata and cannot justify skipping Git checks in an existing repository

## 미해결 사항
- 없음

## Canonical 충돌 여부
- 없음
```

---

## 17. Conformance checklist for this guide

- It defines workflow and Codex behavior only.
- It preserves the authority and responsibility boundaries of 00–04.
- It separates Core Local MVP from the Notion Publication Stage.
- It makes tasks small, evidence-based, minimally scoped, testable, and stoppable.
- It turns 03/04 invariants into references and review gates without rewriting their contracts.
- It requires actual discovered build/test commands and never assumes a project already exists.
- It prohibits automatic commit/push/PR, destructive Git, scope growth, hidden fallback, silent truncation, policy invention, canonical auto-editing, ignored tests, and sensitive logging.
- It requires explicit stop-and-report for canonical conflict, official API impossibility, data-loss/privacy risk, migration risk, and unexpected existing changes.
- It requires self-review, stage-specific definition of done, and exact work reporting.

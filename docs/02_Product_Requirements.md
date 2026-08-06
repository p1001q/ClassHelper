# ClassHelper

> Product Requirements

**Status:** Canonical
**Authority:** Functional behavior and product-level policy  
**Depends on:** `00_Project_Overview.md`, `01_Product_Philosophy.md`

---

## 1. Purpose

This document defines what ClassHelper must do: its user-visible workflow, product states and transitions, local artifacts, recovery behavior, phased scope, Notion publication, and acceptance criteria.

This document does not select frameworks, APIs, models, database libraries, retry algorithms, encryption mechanisms, or prompt wording. Those decisions belong to `03_Technical_Design.md` and `04_AI_Prompt_Specification.md`.

If this document conflicts with `00_Project_Overview.md` or a non-negotiable principle in `01_Product_Philosophy.md`, the upstream canonical document wins and this document must be corrected.

---

## 2. Product invariants

1. The local Markdown learning note is the canonical product artifact.
2. A transcript is an intermediate artifact, not the final product.
3. Lecture audio exists only to support transcription and recovery. It is not a user-facing archive.
4. Notion is a one-way publication destination. It never becomes the authority for a learning note.
5. A local note is complete independently of Notion publication.
6. Failures and uncertainty must be visible; the product must never report success for an unverified output.
7. Recovery must not depend on an application-managed cloud file store or hosted backend.
8. The product is for one user on one Mac. Multi-user behavior, synchronization, collaboration, and generalized knowledge management are out of scope.

---

## 3. Definitions

### 3.1 Lecture Session

A Lecture Session is one user-initiated recording attempt and all processing associated with it. It begins when Start Recording succeeds. It reaches a terminal outcome only when:

- the canonical local note has been saved and verified (`LOCAL_COMPLETE`);
- the user explicitly discards a recoverable session (`DISCARDED`); or
- no usable source remains and recovery is impossible (`UNRECOVERABLE_FAILED`).

Stopping active recording does not end the Lecture Session; it begins post-processing.

### 3.2 Transcript

Text derived from lecture audio and used as source material for title and note generation. Live subtitle text may be incomplete and does not replace the finalized transcript unless the finalization step validates it for downstream use.

### 3.3 Learning Note

The structured study document generated from the finalized transcript and saved as canonical local Markdown.

### 3.4 Recovery Bundle

The minimum locally retained material needed to retry an incomplete session. Depending on the last successful stage, it contains available audio, transcript, generated draft, session metadata, and failure information. Its physical encoding belongs to `03_Technical_Design.md`.

### 3.5 Local completion

The learning-note Markdown file exists at its final path, can be read back, contains all required sections and metadata, and is not an incomplete temporary file.

### 3.6 Publication

Creation or completion of one session toggle in the appropriate Notion date page from a locally complete learning note. Publication is one-way and optional to local completion.

---

## 4. Scope and delivery boundaries

### 4.1 Core Local MVP

The Core Local MVP includes:

- manual Start, Pause, Resume, and Stop controls;
- lecture audio capture from the selected/default Mac microphone;
- speech-to-text processing and optional live subtitles;
- transcript finalization;
- AI-generated title and structured learning note;
- automatic canonical Markdown storage using the rules in this document;
- visible product state and failure reason;
- crash-safe recovery and user-initiated retry or discard;
- successful exercise with a real lecture.

The Core Local MVP is complete without Notion credentials and without successful Notion publication.

### 4.2 Notion Publication Stage

After the Core Local MVP is accepted, the Notion stage adds:

- initial connection and destination selection;
- one-way publication of a locally complete note;
- visible publication state;
- retry after a publication failure;
- duplicate-safe behavior for repeated publication attempts.

The Notion stage does not change the canonical local file and does not add import, sync, conflict resolution, or Notion-to-local updates.

### 4.3 Explicitly out of scope

- automatic or scheduled recording;
- background lecture detection;
- multiple simultaneous recordings;
- speaker diarization;
- OCR, PDF analysis, or screen capture;
- audio library or permanent recording archive;
- transcript library as a user-facing product;
- manual transcript or note editor;
- cloud file storage or hosted application state;
- bidirectional or real-time Notion synchronization;
- multi-user accounts, collaboration, or public distribution;
- mobile, Windows, or web clients;
- features whose only purpose is hypothetical future extensibility.

---

## 5. State model

ClassHelper must expose three independent product-state axes. They may be implemented differently, but the behavior below must remain representable.

### 5.1 Application recording state

This state describes the current recording controls, not historical sessions.

| State | Meaning | Allowed user actions |
|---|---|---|
| `READY` | No active capture; a new recording may start | Start; open recovery item |
| `RECORDING` | Audio capture is active | Pause; Stop |
| `PAUSED` | The active recording is retained but capture is suspended | Resume; Stop |
| `STARTING` / `STOPPING` | A control request is being committed | No duplicate control request |
| `BLOCKED` | Recording cannot start because a required permission, device, or local condition is unavailable | Resolve cause; retry Start |

`PAUSED → Stop` is required. A failed Start must return to `READY` or `BLOCKED` without creating a misleading active session.

Once Stop has safely ended capture, the application returns to `READY` even while that session is being processed or awaits recovery. Therefore a prior failed or processing session must not permanently block a new lecture. The application may limit concurrent post-processing to protect reliability, but queued sessions must remain distinct and visible.

### 5.2 Per-session local processing state

| State | Meaning |
|---|---|
| `CAPTURING` | Recording is active or paused |
| `FINALIZING_TRANSCRIPT` | Capture has stopped and the transcript is being finalized |
| `GENERATING_NOTE` | Title and note are being generated from the finalized transcript |
| `SAVING_LOCAL` | The Markdown artifact is being written and verified |
| `LOCAL_COMPLETE` | Canonical local Markdown exists and has passed completion checks |
| `RECOVERABLE_FAILED` | Processing stopped, but sufficient local material exists to retry |
| `UNRECOVERABLE_FAILED` | No sufficient material exists to produce the note |
| `DISCARDED` | The user explicitly abandoned a recoverable session |

`LOCAL_COMPLETE`, `UNRECOVERABLE_FAILED`, and `DISCARDED` are terminal for local processing. A retry is a continuation of the same Lecture Session and must retain its stable session identity.

### 5.3 Per-session Notion publication state

| State | Meaning |
|---|---|
| `NOT_APPLICABLE` | Notion stage is unavailable or publication is not configured |
| `QUEUED` | Publication is intended and waiting to run |
| `PUBLISHING` | A publication attempt is active |
| `PUBLISHED` | The session toggle in the destination date page has been confirmed complete |
| `PUBLISH_FAILED` | Publication failed and may be retried |

Publication state is valid only after `LOCAL_COMPLETE`. A session can be `LOCAL_COMPLETE` and `PUBLISH_FAILED` at the same time. Notion failure must never change local processing back to failed.

### 5.4 Required local transitions

```text
Start succeeds
  → CAPTURING

Stop from RECORDING or PAUSED
  → FINALIZING_TRANSCRIPT
  → GENERATING_NOTE
  → SAVING_LOCAL
  → LOCAL_COMPLETE
```

Every processing stage may transition to `RECOVERABLE_FAILED` if sufficient recovery material exists, otherwise to `UNRECOVERABLE_FAILED`.

A retry from `RECOVERABLE_FAILED` resumes at the earliest necessary stage based on the last verified artifact:

- usable audio but no finalized transcript → `FINALIZING_TRANSCRIPT`;
- finalized transcript but no valid note → `GENERATING_NOTE`;
- valid generated note not safely saved → `SAVING_LOCAL`;
- local note already verified → `LOCAL_COMPLETE` and, independently, retry publication if needed.

A failed retry returns to `RECOVERABLE_FAILED` when recovery remains possible; it becomes `UNRECOVERABLE_FAILED` only when the retained material is absent, corrupt, or insufficient. The number of failed attempts alone must not make a session unrecoverable.

From `RECOVERABLE_FAILED`, the user may choose Discard after seeing that retained recovery material will be deleted. This transitions to `DISCARDED`.

### 5.5 Required publication transitions

```text
LOCAL_COMPLETE + publication enabled
  → QUEUED
  → PUBLISHING
  → PUBLISHED
```

Any publication attempt may transition to `PUBLISH_FAILED`. Retry transitions `PUBLISH_FAILED → QUEUED`. A successful retry must update or complete the same session toggle and must not create a duplicate toggle.

---

## 6. Functional requirements

### 6.1 Initial setup

- The application must request microphone permission before the first recording that needs it.
- Missing or denied permission must produce a visible, actionable blocked state.
- Local output root selection must be completed before a session can reach `SAVING_LOCAL`.
- Notion setup is optional for the Core Local MVP and must not block local use.
- Notion setup must allow the user to connect and choose exactly one parent page for publication.
- Credentials and secrets must never be written into learning-note Markdown or recovery content.

### 6.2 Recording controls

- Start begins a new Lecture Session only after capture is confirmed.
- Pause suspends new audio capture without ending the session.
- Resume continues the same session.
- Stop must work from both `RECORDING` and `PAUSED`.
- Repeated clicks during `STARTING` or `STOPPING` must not create duplicate sessions or finalize twice.
- Elapsed recording status and the current recording state must remain visible.
- Live subtitles are optional and may be turned on or off without affecting audio capture or the final transcript.
- Closing the subtitle view must not stop recording.

### 6.3 Transcription

- The product must produce a finalized transcript suitable for downstream note generation.
- Korean lecture speech and embedded English technical terms are the expected input.
- A transient network or provider failure during recording must not silently terminate capture when local capture can continue.
- Incomplete live subtitle output must not be treated as a finalized transcript.
- If finalization cannot complete, the session must follow the recovery rules in Section 9.

### 6.4 Note generation

- Generation must use the finalized transcript as its lecture-content source.
- It must produce exactly one title and one learning-note body for the session.
- Unsupported certainty must not be invented. Unclear or missing source material must remain visibly uncertain according to `04_AI_Prompt_Specification.md`.
- Any AI-added clarification must be distinguishable from lecture content and must not alter the lecturer's claim.
- Generation failure must not produce a file that appears locally complete.

### 6.5 Local saving

- Local saving is automatic after successful note generation.
- A note becomes canonical only after the final file can be read back and passes the structural checks in this document.
- Partial writes must not appear under the final filename.
- A Lecture Session has exactly one canonical local file. On a save retry, if the computed path already contains a valid note whose `session_id` matches the current session, that file remains canonical and must not be duplicated.
- If a matching-session file is incomplete or invalid, the retry must safely replace or complete that same canonical target only after the replacement passes verification; it must not create a second canonical note for the session.
- Only when the computed path belongs to a different `session_id` does the new filename receive the next deterministic numeric suffix: `-2`, `-3`, and so on. The other session's file must remain unchanged.
- The application must display or provide access to the final file location.

### 6.6 Notion publication

- Publication may begin only from a verified local note.
- The published content must be derived from that local note, not independently regenerated.
- Local completion must remain successful if Notion is offline, unconfigured, unauthorized, rate-limited, or otherwise fails.
- The user must be shown `PUBLISH_FAILED` with a retry action and a useful reason.
- Retrying must reuse the known date-page and session-toggle identities when available.
- Changes made directly in Notion are outside ClassHelper's authority and must never be imported over the local note.

---

## 7. Canonical local organization

### 7.1 Output root

On first use, the user chooses a writable local output root. The default offered location is:

```text
~/Documents/ClassHelper
```

The chosen root is remembered locally. The application must not hard-code a user name or machine-specific absolute path.

### 7.2 Note directory

Canonical notes are stored by lecture date:

```text
<output-root>/notes/YYYY/MM/DD/
```

The lecture date is the local calendar date in the user's configured timezone when recording started. Crossing midnight does not split a session or change its directory.

### 7.3 Filename

```text
YYYY-MM-DD_HH-mm_<title-slug>.md
```

- `HH-mm` is the local recording start time.
- `<title-slug>` is derived from the generated title.
- The slug preserves readable Korean and English letters and numbers.
- Filesystem separators, control characters, leading/trailing whitespace, and characters invalid on the target filesystem are removed or replaced with `-`.
- Consecutive separators collapse to one `-`.
- If AI title generation fails, or the title becomes empty after normalization, use the deterministic title `강의_YYYY-MM-DD_HH-mm`, using the local recording start date and time. The filename slug is derived from that fallback title by the same normalization rules.
- Collision suffixes appear before `.md`, for example `..._lecture-2.md`.

### 7.4 Recovery location

Recovery Bundles are application working data and must not be mixed with canonical notes. They reside in the application's local support-data area under a stable session identifier. The OS-specific absolute location and on-disk encoding belong to `03_Technical_Design.md`.

---

## 8. Learning-note structure

Every canonical Markdown file must use this order:

```markdown
---
classhelper_schema: 1
session_id: <stable session identifier>
lecture_started_at: <ISO 8601 timestamp with offset>
generated_at: <ISO 8601 timestamp with offset>
title: <generated title>
---

# <generated title>

## 핵심 요약
...

## 주요 개념
...

## 상세 내용
...

## 예시 및 적용
...

## 불확실하거나 확인이 필요한 내용
...
```

Requirements:

- All front matter keys are required and appear once.
- The H1 title must equal the front matter `title`.
- All five H2 sections are required, even when a section has no supported content.
- An empty-content section must say that no supported content was identified; it must not be omitted or filled with invented material.
- `불확실하거나 확인이 필요한 내용` must explicitly say `없음` when no uncertainty was identified.
- The note must not embed credentials, raw audio, or the full transcript.
- Prompt wording, detailed formatting within sections, and AI output validation schemas belong to `04_AI_Prompt_Specification.md`.

---

## 9. Failure, recovery, and retention lifecycle

### 9.1 General rule

At every stage, ClassHelper must preserve the most advanced verified local artifact needed to resume without repeating already completed work. It must show:

- the affected Lecture Session;
- the failed stage;
- whether recovery is possible;
- the available action: Retry, Discard, or resolve a prerequisite.

The product must not claim that recovery is possible unless sufficient retained material exists.

### 9.2 Recording or transcription interruption

- If network transcription fails while local capture remains viable, recording continues and the user is informed that transcription recovery will be needed.
- If capture itself fails, the application stops the active recording state and preserves all usable captured audio.
- If usable audio or a finalized transcript remains, the session becomes `RECOVERABLE_FAILED` after capture ends.
- If no usable audio or transcript remains, the session becomes `UNRECOVERABLE_FAILED`.

### 9.3 Application exit or crash

- A normal quit during active recording or processing must warn that the session is incomplete and require confirmation.
- Forced termination or crash must not cause a recoverable session to disappear.
- On next launch, incomplete session data must be inspected before cleanup.
- Sufficient material becomes a visible `RECOVERABLE_FAILED` session with Retry and Discard.
- Insufficient or corrupt material becomes a visible `UNRECOVERABLE_FAILED` session with its reason.

### 9.4 Transcription, generation, or local-save failure

- If a finalized transcript was not produced, usable captured audio must be retained, the failed transcription stage and reason must be shown, and the user must be offered a `Transcript 재생성` action. That action retries transcription from the retained audio for the same session.
- Once a finalized transcript is produced and verified, retained audio that is no longer required for recovery must be deleted immediately.
- A finalized transcript must be retained when generation fails.
- When note generation fails, the failed stage and reason must be shown and the user must be offered a `학습노트 재생성` action. That action retries from the retained finalized transcript for the same session and must not retranscribe audio.
- A valid generated note and its source transcript must be retained when final saving or verification fails.
- Retry resumes at the earliest necessary stage defined in Section 5.4.
- An unverified or partial Markdown file must never be presented as canonical.
- Once the canonical local Markdown has been saved and read-back verified, the finalized transcript and generated temporary recovery sources must be deleted immediately.

### 9.5 Publication failure

- The canonical local note remains unchanged and `LOCAL_COMPLETE`.
- The publication state becomes `PUBLISH_FAILED`.
- Audio and transcript retention must not be extended solely because publication failed.
- Retry uses the canonical local note.

### 9.6 Retention and deletion policy

| Material | Successful local completion | Recoverable failure | Discard or unrecoverable failure |
|---|---|---|---|
| Canonical Markdown | Retain indefinitely until the user deletes it outside or through a future approved feature | Not yet applicable | Not created |
| Finalized transcript | Delete immediately after local Markdown has been saved and read-back verified | Retain until note/save retry succeeds or the user discards | Delete when it cannot support recovery or the user confirms discard |
| Captured audio | Delete immediately after a finalized transcript has been produced and verified | Retain while no finalized transcript exists so transcription can be retried; otherwise delete immediately | Delete when it cannot support recovery or the user confirms discard |
| Generated draft/temp file | Delete after the canonical file is verified | Retain only if it can resume saving | Delete on discard or after failure acknowledgement |
| Minimal session/publication metadata | Retain locally as needed to identify the note, report state, and prevent duplicate publication | Retain | Retain only a minimal failure/discard record; no audio or transcript |

There is no automatic age-based deletion, including no 24-hour deletion rule, for an unresolved Recovery Bundle. Required recovery data is preserved until the relevant retry succeeds or the user explicitly confirms Discard. This prevents silent loss while the user is away. The application must keep unresolved recovery items visible. Successful retry deletes the preceding-stage recovery source immediately: verified transcript deletes audio, and verified canonical Markdown deletes transcript and generated temporary sources. Publication failure never justifies retaining audio or transcript after local completion because publication retries use the canonical Markdown.

---

## 10. Notion destination structure

### 10.1 Destination

ClassHelper publishes under one user-selected Notion parent page. Beneath that parent it creates or reuses one date page per local lecture date. Each Lecture Session is represented by exactly one toggle inside that date page.

For example, five recordings started on the same local calendar date produce five session toggles in that date's single page, not five date pages.

### 10.2 Date pages and session identity

- The date page represents the local calendar date on which recording started and must use one deterministic date identity and display title for that date.
- Crossing midnight does not move a session to another date page.
- Each recording creates one toggle whose visible title is the canonical learning-note title.
- The stable `session_id` is the identity key for the toggle, even if it is stored as non-visible publication metadata.
- ClassHelper must retain enough local publication identity metadata to resolve the same date page and toggle after interruption.
- Before creating a toggle, the application must resolve any known page/toggle identity and session identity. Retrying the same session updates or completes the same toggle; it must not append a second toggle.

### 10.3 Toggle body

- The toggle title comes from the canonical note title.
- YAML front matter is not copied into the visible page body.
- Each required H2 note section becomes a Notion heading followed by its content.
- Publication must preserve the meaning and ordering of the canonical note. It must not ask AI to regenerate or improve the content.
- Exact Notion block conversion and the non-visible session-identity representation belong to `03_Technical_Design.md`.

---

## 11. User-visible completion rules

- `LOCAL_COMPLETE` is the primary completion result.
- When Notion is not configured, the UI may show local completion with publication `NOT_APPLICABLE`.
- When Notion is configured, verified local completion automatically queues publication; there is no per-session Publish action or `NOT_REQUESTED` state.
- The user's normal session actions are only Start, Pause, Resume, and Stop. After Stop, transcript finalization, note generation, local saving, and configured Notion publication proceed automatically until completion or a visible failure.
- When Notion is configured, local completion and publication status must both be visible.
- “Done” may be shown without qualification only when local processing is complete and automatic publication is `PUBLISHED`, or publication is `NOT_APPLICABLE`.
- If local processing is complete but publication failed, the UI must say that the note is saved locally and Notion publication failed.
- Manual intervention in the normal pipeline is limited to retrying the failed stage or explicitly discarding a recoverable session. A Notion failure provides only a manual Retry action; it does not require regenerating the local note.
- A recoverable or unrecoverable failure must never be grouped under completed sessions without its failure label.

---

## 12. Acceptance criteria

### AC-01 — Start and stop

Given the application is `READY` with microphone permission and a usable input device, when Start succeeds and Stop is invoked, exactly one Lecture Session is created and moves from `CAPTURING` to `FINALIZING_TRANSCRIPT`.

### AC-02 — Pause and stop

Given an active session is `PAUSED`, when Stop is invoked, capture ends safely and the same session moves to `FINALIZING_TRANSCRIPT`; Resume is not required first.

### AC-03 — Duplicate control protection

Given Start or Stop is already being committed, repeated activation does not create an additional session, duplicate finalization, or duplicate output file.

### AC-04 — Subtitle independence

Given recording is active, toggling live subtitles off and on does not pause or stop capture and does not change the final transcript requirement.

### AC-05 — Complete local path

Given a usable real-lecture recording and available inference services, the session proceeds through all required local states and produces one readable Markdown file at `<root>/notes/YYYY/MM/DD/YYYY-MM-DD_HH-mm_<title-slug>.md`.

### AC-06 — Note structure

Given a locally complete note, parsing the file finds all five required front matter keys exactly once, one matching H1 title, and all five required H2 sections in the specified order.

### AC-07 — No false completion

Given generation, writing, or read-back validation fails, no partial file under the final filename is reported as canonical and the session is not `LOCAL_COMPLETE`.

### AC-08 — Canonical filename identity and collision

Given a valid file already exists at the computed path with the same `session_id`, retry recognizes it as that session's one canonical note and creates no duplicate. Given an incomplete same-session target, retry safely completes or replaces that target and leaves exactly one verified canonical note. Given the path belongs to a different `session_id`, saving leaves that file byte-for-byte unchanged and writes the current session using the next available numeric suffix.

### AC-09 — Network loss during recording

Given transcription connectivity fails while local audio capture can continue, capture remains active, the interruption is visible, and stopping produces either a retryable session with sufficient material or an explicitly unrecoverable failure.

### AC-10 — Crash recovery

Given the application is forcibly terminated during capture or local processing after recoverable material exists, relaunch exposes the same stable session ID as `RECOVERABLE_FAILED` and offers Retry and Discard.

### AC-11 — Stage-aware retry

Given a session has usable audio but no finalized transcript, the visible transcription error offers `Transcript 재생성`, and Retry starts at `FINALIZING_TRANSCRIPT` from that audio. Given a session has a verified finalized transcript and note generation failed, the visible note-generation error offers `학습노트 재생성`, and Retry starts at `GENERATING_NOTE` from that transcript without requiring a new recording or retranscription.

### AC-12 — Repeated retry failure

Given a retry fails but retained material remains usable, the session returns to `RECOVERABLE_FAILED`; it does not become unrecoverable solely because of an attempt count.

### AC-13 — Explicit discard

Given a recoverable session, when the user confirms Discard after the deletion warning, its audio, transcript, and generated temporary content are removed and its local state becomes `DISCARDED`.

### AC-14 — Successful stage cleanup

Given a finalized transcript has been produced and verified, source audio that is no longer needed for recovery is removed immediately. Given the canonical Markdown has then been saved and read-back verified, the session reaches `LOCAL_COMPLETE` and the finalized transcript and temporary generation sources are removed immediately, regardless of whether Notion is configured or succeeds.

### AC-15 — New session independence

Given an older session is processing or `RECOVERABLE_FAILED`, the application can return to `READY` and start a distinct new recording without losing or merging the older session.

### AC-16 — Core Local MVP independence

Given no Notion credentials are configured, every Core Local MVP acceptance criterion can pass and a session can reach `LOCAL_COMPLETE` with publication `NOT_APPLICABLE`.

### AC-17 — Automatic publication source and hierarchy

Given a verified local note and valid Notion configuration, local completion automatically queues publication without a Publish action. Publication creates or reuses the recording date page beneath the selected parent, then creates or confirms exactly one toggle for the session whose title and visible body preserve the canonical note's required sections without YAML front matter.

### AC-18 — Publication failure isolation

Given Notion publication fails, the local file remains byte-for-byte unchanged, local state remains `LOCAL_COMPLETE`, publication state becomes `PUBLISH_FAILED`, and Retry is available.

### AC-19 — Duplicate-safe publication retry

Given a prior attempt created or partially populated a session toggle but confirmation was interrupted, Retry resolves the known date-page/toggle identity or stable `session_id`, updates or completes that same toggle, and does not create a second toggle for the Lecture Session. Five distinct sessions on one date produce one date page containing exactly five distinct session toggles.

### AC-20 — One-way authority

Given a published Notion date page or session toggle is edited, a later ClassHelper action neither imports those edits into the Markdown file nor overwrites the local note based on Notion content.

### AC-21 — Retention policy

Given an unresolved recoverable session remains unused over time, automated cleanup—including a 24-hour rule—does not delete recovery data needed for retry. Deletion occurs when the next artifact is verified and makes the source unnecessary, when the user confirms Discard, or when the data cannot support recovery.

### AC-22 — Transcript quality on a real lecture

Before the Core Local MVP is accepted, use at least one approximately 50-minute, primarily Korean university lecture containing English technical terms. Select five representative, non-overlapping source intervals totaling at least ten minutes and prepare a human reference for the lecturer's intelligible speech and technical terms.

The finalized transcript passes only if all of the following are true:

- each interval's principal concept or claim is identifiable without listening to the audio;
- at least 90% of the distinct intelligibly spoken English technical terms in the reference sample are present in recognizable form, allowing capitalization, spacing, and conventional transliteration differences;
- no sampled interval reverses the lecturer's meaning through a missing or inserted negation, incorrect numeric value, or swapped technical entity;
- unintelligible source audio is marked or omitted as uncertain rather than replaced with confident invented speech.

The reviewer records the selected timestamps, reference terms, detected terms, and pass/fail result. Failure of any condition blocks Core Local MVP acceptance.

### AC-23 — Learning-note grounding and quality

Using the finalized transcript from AC-22, a human reviewer evaluates the generated note against the following reproducible checks:

- every principal concept found in the five reference intervals is represented in `핵심 요약`, `주요 개념`, or `상세 내용`, unless the note explicitly marks the source as uncertain;
- for a sample of at least ten factual claims drawn across the note, every claim labeled or presented as lecture content is supported by an identifiable transcript passage; zero unsupported sampled lecture claims are allowed;
- every AI-added clarification in the sample is visibly distinguishable from lecture content using the provenance convention defined by `04_AI_Prompt_Specification.md`;
- every material uncertainty identified in the five intervals appears in `불확실하거나 확인이 필요한 내용`, and the note does not resolve it by guessing;
- section content is non-empty or uses the required no-supported-content statement, and the note remains useful as a study aid without requiring the transcript to understand its main concepts.

The reviewer records transcript evidence for the sampled claims and a pass/fail result for each check. Failure of any condition blocks Core Local MVP acceptance.

### AC-24 — Fallback title

Given title generation fails or normalizes to an empty value, processing continues using `강의_YYYY-MM-DD_HH-mm` from the local recording start time, and the canonical filename follows the unchanged `YYYY-MM-DD_HH-mm_<title-slug>.md` pattern.

### AC-25 — Phased acceptance

Before the Core Local MVP is accepted, AC-01 through AC-16 and AC-21 through AC-24 must pass, including the real-lecture evidence required by AC-22 and AC-23. Any unmet criterion blocks Core Local MVP acceptance.

Before the Notion stage is accepted, AC-17 through AC-20 must additionally pass against the configured parent-page destination. Notion-stage failure does not revoke Core Local MVP acceptance or local completion.

---

## 13. Downstream decisions

The following remain intentionally delegated and must not change the product behavior above:

- application architecture, frameworks, and process boundaries;
- STT and language-model providers;
- streaming, buffering, and local recovery encoding;
- secure credential storage;
- atomic-write and retry mechanisms;
- Notion API block conversion details;
- prompt text, AI schemas, and uncertainty labels;
- automated test implementation and development commands.

There are no unresolved product-policy questions in this canonical candidate.

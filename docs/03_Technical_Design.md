# ClassHelper

> Technical Design

**Status:** Canonical
**Authority:** Application architecture, APIs, local persistence, security, recovery, retry, and verification mechanics  
**Depends on:** `00_Project_Overview.md`, `01_Product_Philosophy.md`, `02_Product_Requirements.md`  
**Defers to:** `04_AI_Prompt_Specification.md` for prompt text, AI output schemas, provenance labels, and hallucination safeguards

---

## 1. Purpose and authority boundary

This document defines how ClassHelper implements the product behavior fixed by the three upstream canonical documents. It does not change product requirements, add user-facing features, or reinterpret acceptance criteria.

The design is optimized for one user, one Mac, and one 2–3 month university term. Reliability, recoverability, and implementation simplicity take precedence over generalized extensibility. The local Markdown note remains canonical; local operational data exists only to support processing, recovery, status reporting, and duplicate-safe publication.

If this document conflicts with `02_Product_Requirements.md`, the product requirements win and this document must be corrected.

---

## 2. Decision summary

| Area | Selected design | Reason |
|---|---|---|
| Application | Native macOS app in Swift 6 and SwiftUI, minimum macOS 14 | One codebase, native microphone/Keychain/file APIs, no bundled web runtime |
| Concurrency | Swift structured concurrency; mutable subsystems isolated behind actors | Prevents duplicate controls and data races without a separate worker process |
| Audio | `AVAudioEngine` input tap; CAF containing 16 kHz mono Linear PCM 16-bit little-endian as the recovery source, separately converted 24 kHz mono PCM subtitle stream, and WAV upload artifacts | Separates durable capture, Realtime transport, and supported final-transcription upload formats |
| STT | OpenAI transcription service behind `TranscriptionClient`; Realtime is subtitle-only and retained-audio transcription is always canonical | Live feedback cannot alter the authoritative transcript; every final result is reproducible from local audio |
| Note generation | OpenAI Responses API behind `NoteGenerationClient`; structured output defined by 04 | Keeps provider code replaceable and validation explicit |
| Operational store | SQLite via GRDB, with explicit schema and migrations | Small, durable, transactional state ledger; simpler crash reasoning than ad hoc JSON |
| Recovery artifacts | Actual recovery files plus minimal immutable `session.json` under Application Support | SQLite is the only operational state authority; recovery metadata is not duplicated |
| Canonical save | Same-directory temporary file, flush, validation, exclusive no-clobber install or verified same-session replace, read-back verification | Prevents partial canonical files and supports same-session upsert without overwriting another artifact |
| Secrets | macOS Keychain; non-secret settings in Application Support/UserDefaults | Credentials never enter notes, logs, SQLite, or recovery bundles |
| Notion | Direct HTTPS API client; local publication ledger plus deterministic markers | One-way publication with duplicate-safe retry and no server component |
| Logging | Unified Logging with privacy redaction plus bounded local diagnostic metadata | Useful diagnosis without retaining lecture content or secrets |
| Packaging | Direct, non-distributed personal build with App Sandbox disabled; standardized local output-root URL | Matches current scope; distribution and a future sandbox/bookmark migration are separate design work |

---

## 3. Considered alternatives

### 3.1 Native SwiftUI versus Electron or a local web stack

**Selected: SwiftUI + AppKit interoperability.** Native Swift has direct access to microphone permission, `AVAudioEngine`, Keychain, file coordination, security-scoped bookmarks, and macOS lifecycle events. It also avoids shipping Node, a browser engine, and a local service for a single-window personal app.

Electron/Tauri would make cross-platform UI easier, but other platforms are explicitly out of scope. Python with a GUI framework would speed prototypes but complicate signing, microphone lifecycle, secure credential storage, crash-safe background work, and distribution. Those costs exceed the benefit for this scope.

### 3.2 SQLite versus SwiftData, Core Data, or JSON files

**Selected: SQLite through GRDB.** Session state and publication identity require transactional compare-and-set updates, unique constraints, and predictable migrations. GRDB exposes SQLite directly and remains small.

SwiftData is attractive for UI binding but makes the durable state machine and conflict constraints less explicit. Core Data is mature but heavier than needed. A JSON file per session is suitable only for immutable identity metadata, not for scheduling, state, hashes, uniqueness, queries, or concurrent updates. SQLite is the sole operational state authority.

### 3.3 Cloud STT versus Apple Speech or local Whisper

**Selected: a cloud transcription adapter, initially OpenAI, with local audio as the retry source.** This best fits Korean lectures containing English technical terms and permits streaming subtitles and post-recording transcription through one provider boundary.

Apple Speech reduces external transfer but its long-form behavior and technical-term accuracy must still pass AC-22 and may vary by OS. A bundled local Whisper runtime improves privacy and offline use but adds model distribution, CPU/battery load, and packaging complexity. Either can replace the adapter only after the same real-lecture acceptance test passes; no product behavior depends on the provider.

### 3.4 One process versus helper service

**Selected: one app process.** A helper/XPC service would isolate crashes but creates lifecycle, IPC, signing, and recovery complexity. Durable artifacts are written before state transitions, so a single process can recover safely on relaunch. A helper becomes justified only by observed capture reliability problems, not hypothetical scale.

---

## 4. System context and component architecture

```text
SwiftUI Views
    │ intents / observable snapshots
    ▼
AppCoordinator (@MainActor)
    ├── RecordingController actor ── AVAudioEngine / AudioFileWriter
    ├── SessionPipeline actor
    │     ├── TranscriptionClient ── OpenAI Audio/Realtime API
    │     ├── NoteGenerationClient ── OpenAI Responses API
    │     ├── NoteValidator
    │     └── CanonicalNoteStore ── chosen output root
    ├── PublicationWorker actor ── NotionClient ── Notion API
    ├── RecoveryManager actor ── Application Support bundles
    ├── SessionRepository actor ── SQLite
    ├── CredentialStore ── macOS Keychain
    └── Diagnostics ── Unified Logging
```

Views never call providers or mutate persisted state directly. `AppCoordinator` translates user intents into idempotent commands and publishes read-only UI snapshots. Long-running work is owned by actors and survives view recreation.

The application may capture one active session at a time. After Stop, the recording state returns to `READY`; completed captures enter a FIFO local-processing queue with concurrency `1`. This allows a new recording while an older session processes, avoids merging sessions, and prevents several long AI jobs from competing for memory and network. Publication uses a separate serial queue and cannot block local processing.

---

## 5. Source layout

```text
ClassHelper/
├── App/
│   ├── ClassHelperApp.swift
│   ├── AppCoordinator.swift
│   └── AppLifecycle.swift
├── Features/
│   ├── Recording/
│   ├── Sessions/
│   ├── Recovery/
│   ├── Settings/
│   └── Publication/
├── Domain/
│   ├── LectureSession.swift
│   ├── RecordingState.swift
│   ├── LocalProcessingState.swift
│   ├── PublicationState.swift
│   ├── SessionCommand.swift
│   └── DomainError.swift
├── Services/
│   ├── Audio/
│   ├── Transcription/
│   ├── Generation/
│   ├── Notes/
│   ├── Notion/
│   ├── Credentials/
│   └── Diagnostics/
├── Persistence/
│   ├── Database/
│   ├── RecoveryBundle/
│   └── OutputRoot/
├── Support/
│   ├── Clock.swift
│   ├── FileSystem.swift
│   ├── Hashing.swift
│   └── RetryPolicy.swift
└── Tests/
    ├── Unit/
    ├── Integration/
    ├── FailureInjection/
    ├── UI/
    └── Fixtures/
```

Provider protocols live beside their domain-facing interfaces. Concrete OpenAI and Notion HTTP types stay in `Services`, so tests use deterministic fakes without network access.

---

## 6. Identity, time, and durable records

### 6.1 Session identity

On a successful Start commitment, ClassHelper creates one UUID v4 and stores its lowercase canonical string as `session_id`. The ID is generated before audio writing begins but the session becomes user-visible only after the input device and audio file are both open and the engine has started. If Start fails before that commit, the provisional row and empty bundle are removed; no misleading session remains.

Pause, Resume, Stop, every retry, canonical-file recognition, and Notion publication reuse this ID. A retry never creates a new session.

### 6.2 Time identity

At Start commitment the app stores:

- `lecture_started_at`: an absolute `Date` encoded as ISO 8601 with offset;
- `lecture_timezone`: IANA time-zone identifier;
- `lecture_local_date`: precomputed `YYYY-MM-DD`;
- local `year/month/day/hour/minute` filename components.

These immutable values prevent a time-zone change or midnight crossing from moving the session. `generated_at` records successful note generation time and is replaced only when note generation itself is retried.

### 6.3 SQLite records

`sessions` contains identity, immutable lecture time, three state axes, last verified stage, canonical path, title, failure category/code, `discard_requested`, and attempt timestamps. `artifacts` contains session ID, kind, relative bundle path, validation state, and created time. `transcript_chunks` contains session ID, chunk index, source sample start/end, relative JSON artifact path, content hash, and validation state; it never contains transcript text. `publications` contains session ID, destination parent ID, date key, date page ID, toggle block ID, conversion version, publication hash, phase, and last error. A publication-attempt ledger contains the attempt ID and exact block IDs returned for blocks created during that still-incomplete attempt. `settings` contains only non-secret configuration and schema versions, including the standardized local URL of the initially selected output root.

Key constraints:

```sql
PRIMARY KEY sessions(session_id)
UNIQUE publications(session_id)
UNIQUE publications(destination_parent_id, date_key, session_id)
CHECK local_state IN (...02-defined values...)
CHECK publication_state IN (...02-defined values...)

CREATE UNIQUE INDEX sessions_canonical_path_unique
    ON sessions(canonical_path) WHERE canonical_path IS NOT NULL;
```

SQLite runs in WAL mode with foreign keys enabled. Each mutable subsystem is actor-isolated, and state transitions use short transactions plus unique constraints. Row versions are used only where a compare-and-set is genuinely required across an asynchronous boundary; they are not attached mechanically to every command or record. SHA-256 is likewise limited to boundaries that require content identity: source audio associated with a canonical transcript, final canonical Markdown verification, upload chunks when resumability needs them, and transformed Notion publication content. A second Start/Stop/Retry is rejected or becomes a no-op from the persisted state and actor command gate. Network calls never occur inside a database transaction; the attempt is persisted, the call runs, and its result is committed only if the expected operation is still current.

---

## 7. On-disk organization and recovery bundle

### 7.1 Application support paths

Use `FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)` and bundle identifier `com.classhelper.app` rather than a hard-coded username:

```text
~/Library/Application Support/com.classhelper.app/
├── classhelper.sqlite
├── classhelper.sqlite-wal
├── classhelper.sqlite-shm
├── Recovery/
│   └── <session_id>/
│       ├── session.json              # immutable identity/time only
│       ├── audio.caf                 # 16 kHz mono Linear PCM 16-bit LE recovery source
│       ├── transcript-upload/        # temporary WAV chunks when needed
│       ├── transcript-chunks/        # validated partial transcript JSON artifacts
│       ├── transcript.json           # only until canonical note verification
│       ├── note-draft.json           # only while save recovery needs it
│       └── staging/                  # non-canonical temporary files
└── Diagnostics/
```

Recovery data never resides below the canonical output root and is never exposed as a note library.

### 7.2 Minimal immutable session metadata

`session.json` contains only its schema version, session ID, immutable lecture start instant, lecture time zone, and immutable local date/time components. It contains no mutable state, stage, path inventory, byte count, hash, failure, transcript text, note body, token, or API key. It is created atomically at Start commitment and is never rewritten during normal processing.

SQLite is the only source of operational truth. The recovery folder is not a shadow database and cannot reconstruct all operational history if SQLite is lost. On launch, the app compares SQLite rows with `session.json` identity and the actual presence and parseability of recovery files. If SQLite open, migration, or integrity checking fails, the app fails closed: it starts neither recording nor local/publication processing, deletes no Recovery file, and displays a local database error with safe diagnostic detail. It does not infer mutable state from recovery artifacts or invoke an undefined backup/repair policy.

### 7.3 Artifact validation and deletion order

- Audio is usable when the container opens, duration is positive, format is supported, and the file reaches a finalized header after Stop or crash repair.
- Transcript JSON is usable when it matches its schema, belongs to the session, contains finalized ordered segments, and its source-audio hash matches.
- Note draft is usable when the 04 schema validates and renders to a 02-compliant Markdown document.
- Canonical Markdown is verified by parsing it from the final path and checking required front matter, matching session ID/title, H1, five ordered H2 sections, and UTF-8 readability.

Deletion is sequenced as a transaction-like protocol: verify the successor; persist the successor and last verified stage in SQLite; delete the predecessor; verify deletion. If the process dies between these steps, relaunch may temporarily find both artifacts and safely deletes only the predecessor whose successor verifies. It never deletes both based only on a state label.

There is no time-based cleanup for unresolved bundles.

Discard is a resumable deletion protocol. One SQLite transaction first sets `discard_requested = true`; the app then deletes each audio, transcript, chunk, draft, and temporary artifact and verifies each absence; a final transaction removes nonessential artifact rows, retains only minimal identity and discard metadata, sets `DISCARDED`, and clears the request flag. If the app stops mid-protocol, launch reconciliation sees `discard_requested`, continues verified deletion, and never resumes transcription, generation, saving, or publication for that session.

`UNRECOVERABLE_FAILED` is finalized with the same deletion discipline: delete and verify removal of unusable or unnecessary audio, transcript, chunk, draft, and temporary artifacts, then retain only the minimal identity and failure record. No canonical Markdown exists for this state and canonical Markdown is never part of either cleanup protocol.

---

## 8. Audio capture

### 8.1 Capture format and pipeline

`RecordingController` owns one `AVAudioEngine`. Before Start commits, it reads the selected/default input node and verifies that the actual input format has a finite positive sample rate and at least one valid channel. An invalid input format blocks Start. It then installs a tap and routes each captured buffer through a preallocated, fixed-capacity ring buffer or buffer pool.

1. Outside the tap callback, a dedicated conversion/writer worker uses an explicit `AVAudioConverter` to write one fixed local recovery format: CAF container, 16 kHz, mono, Linear PCM signed 16-bit little-endian. This file is the recovery authority and is never sent to an API merely because it is the local container.
2. `RealtimeAudioConverter` converts bounded buffer copies to mono 24 kHz PCM in the exact representation required by the configured Realtime transcription model, then sends them to `StreamingTranscriber` for screen subtitles only.

After Stop closes and verifies the recovery source, `FinalTranscriptionPreparer` converts it to an upload format supported by the current OpenAI Audio Transcriptions API, initially lossless PCM WAV. For long recordings it creates ordered WAV chunks under `transcript-upload/`; these are disposable derivatives, while `audio.caf` remains the recovery authority until the canonical transcript verifies.

The input tap callback only copies into and enqueues a slot from the preallocated fixed-capacity ring buffer/buffer pool. File I/O, `AVAudioConverter` work, locks, memory allocation, Swift `Task` creation or actor hops, networking, database writes, UI updates, parsing, and file-container finalization are prohibited in the callback. The storage conversion and the Realtime 24 kHz mono PCM conversion run on separate workers outside the callback; neither may block the callback. Exact Realtime sample representation and accepted upload containers are adapter configuration verified against current official documentation and contract tests before implementation.

The writer uses a bounded channel. Buffer overrun, device removal, write failure, or engine configuration change is a capture failure, not silent audio loss. The controller stops safely, finalizes what is usable, and reports the correct recovery result.

### 8.2 Start, pause, resume, and stop commitment

- **Start:** acquire the command gate; validate permission/device/free space/output setup; create provisional ID/bundle; open audio file; start engine; atomically persist `CAPTURING`; expose `RECORDING`.
- **Pause:** stop accepting input buffers while retaining engine/session/file identity; flush the writer; persist `PAUSED`. No synthetic silence is needed.
- **Resume:** restart buffer acceptance into the same file and streaming session; persist `RECORDING`.
- **Stop from recording or paused:** enter `STOPPING`; remove tap; stop engine; drain and close writer; finalize audio header and hash; persist `FINALIZING_TRANSCRIPT`; release command gate; expose application `READY`.

Stop is idempotent through a per-session `stop_committed_at` field. A second invocation observes the committed transition and returns the existing result.

### 8.3 Permission and interruption handling

Microphone authorization is requested through the macOS capture-device API. Denial, no input device, insufficient disk, or an unwritable support directory maps to application `BLOCKED` with an actionable reason. A streaming/network failure never stops the local writer. A local capture failure never gets hidden by continued streaming.

---

## 9. Transcription streaming, finalization, and retry

### 9.1 Provider boundary

```swift
protocol TranscriptionClient {
    func openLiveSession(configuration: LiveConfig) async throws -> LiveTranscriptStream
    func transcribe(audio: URL, context: TranscriptContext) async throws -> FinalTranscript
}
```

The initial implementation uses an OpenAI transcription-capable Realtime connection for live subtitles and OpenAI Audio Transcriptions for the Stop-time canonical transcript. Provider model IDs, supported input formats, service routes, and API versions are centralized adapter configuration with contract-tested defaults, not endpoint assumptions scattered through UI or domain code.

### 9.2 Live stream semantics

Converted 24 kHz PCM frames are assigned local sequence numbers before transmission. Delta and completion events may update the transient subtitle view. Realtime text is never stored as the finalized transcript, never enters note generation, and never participates in the decision of whether the retained recording needs final transcription.

The live connection has a bounded reconnect policy with full jitter: 1, 2, 4, 8, then 16 seconds, capped at 30 seconds. Reconnect attempts continue only while capture is active and do not replay unbounded audio into a fresh session. Any disconnect, dropped frame, or provider error may make subtitles incomplete, but the local recording continues unaffected. The UI may label subtitles as temporarily unavailable; it does not imply that the official transcript is at risk while local capture remains healthy.

Pausing stops audio frames. Resuming keeps the same ClassHelper session; the provider connection may be reopened if it expired. Subtitle visibility affects only rendering, never streaming or capture.

### 9.3 Stop-time canonical transcript

ClassHelper always creates the official transcript after Stop from the verified local recovery audio. Realtime output is never eligible for canonical adoption, even when its connection was uninterrupted.

The preparer converts the retained CAF to supported lossless WAV. Long audio is split on silence near configured boundaries into ordered, optionally overlapping chunks that remain below the provider adapter's current upload constraints. Every result is atomically written as a JSON artifact under `Recovery/<session_id>/transcript-chunks/` and read-back validated before its checkpoint is committed. SQLite stores only chunk index, source sample start/end, artifact path, content hash, and validation state; transcript text remains solely in the JSON artifact. A retry sends only missing or invalid chunks.

Timestamp provenance is explicit. When the selected provider/model response supports timestamps, validated provider timestamps may be retained. When it does not, segments receive approximate ranges derived from the chunk's local source sample bounds and sample rate; they are labeled approximate and are not presented as provider timestamps. Assembly must work without provider timestamps by ordering local sample ranges and reconciling normalized text overlap. It removes only demonstrable boundary duplication and preserves uncertain text rather than guessing.

The implementation centralizes current provider upload constraints in the adapter and tests boundary behavior. It must not assume a 50-minute file fits one request or that a native local container is accepted for upload.

### 9.4 Verification and cleanup

The assembled transcript records source-audio hash, ordered segments with timestamp provenance (`provider` or `local_approximate`), detected/declared primary language `ko`, and prompt/context metadata version. The official result is atomically installed as `transcript.json` and read-back validated. Structural verification cannot itself prove AC-22 quality; that criterion remains a recorded human real-lecture test.

Only after `transcript.json` is atomically written, read back, schema-validated, and its source-audio hash matches does the pipeline persist the verified transcript stage. Applying the transaction-like deletion protocol in Section 7.3, it then immediately deletes `audio.caf`, disposable WAV derivatives, and every `transcript-chunks/*.json` artifact; verifies their absence; and removes the corresponding `transcript_chunks` SQLite rows in a short transaction. The verified `transcript.json` is the successor that makes all of those artifacts unnecessary. If transcript installation or verification fails, the CAF recovery source, required chunk artifacts, and their checkpoint rows remain and the session becomes `RECOVERABLE_FAILED` with `Transcript 재생성`.

Retries use the same session and audio/chunk checkpoints. Authentication/configuration errors wait for user correction. HTTP 408/409/429 and 5xx/network timeouts use bounded exponential backoff with server `Retry-After`; automatic attempts stop after the current run's configured budget, but the retained data and user Retry remain indefinitely. Attempt count never determines unrecoverability.

---

## 10. Note generation and validation

`SessionPipeline` reads only a verified transcript and sends it to `NoteGenerationClient`. The initial implementation uses an OpenAI text model through the Responses API with a strict structured output. Exact prompt, schema, provenance convention, uncertainty wording, and model-specific safeguards are owned by `04_AI_Prompt_Specification.md`.

The technical layer additionally enforces:

- exactly one title and one body object;
- all required sections exactly once and in order;
- title normalization and deterministic fallback from immutable lecture start time;
- no credential fields, raw audio, or full transcript in rendered Markdown;
- bounded size and valid UTF-8;
- H1 equals front-matter title;
- session/time metadata injected by code, never trusted from model output.

Provider/schema/grounding validation failure retains the verified transcript, records `RECOVERABLE_FAILED`, and offers `학습노트 재생성`. The generated draft is persisted only after it validates enough to resume `SAVING_LOCAL`. It is never presented as canonical.

---

## 11. Atomic canonical Markdown save and same-session upsert

### 11.1 Path derivation

App Sandbox is disabled for the entire current scope. When the user first selects the output root, the app stores its standardized local file URL and checks directory existence and write access on every use. It does not create or resolve a security-scoped bookmark in this version. Public distribution, enabling App Sandbox, and migration of the stored URL to a security-scoped bookmark are explicitly out of scope and require a separate security and persistence design review. The immutable lecture local components form:

```text
<output-root>/notes/YYYY/MM/DD/YYYY-MM-DD_HH-mm_<title-slug>.md
```

Slug normalization follows 02 exactly and is implemented as a pure, table-tested function. Directory creation is idempotent.

### 11.2 Target resolution

For the unsuffixed candidate and then `-2`, `-3`, ...:

1. If absent, reserve it as this session's target in SQLite; the partial unique index on non-null `sessions.canonical_path` prevents two sessions from reserving the same target.
2. If present and parses with the same `session_id`, adopt it as this session's canonical target.
3. If present with a different session ID, do not modify it and test the next suffix.
4. If present but cannot be parsed, treat it as belonging to an unknown/different artifact; do not overwrite it automatically and use the next suffix. Only a target already recorded for this same session may be replaced as an incomplete same-session target.

Target selection and stored `canonical_path` are stable across retries. Once chosen, a later regenerated title does not create a second path for the same session.

### 11.3 Write protocol

Render complete UTF-8 bytes in memory and validate them. In the final directory create `.<filename>.<session_id>.tmp` using exclusive creation, write all bytes, call file synchronization, close, reopen, and validate including session ID. For a new target, use the volume's atomic exclusive rename/no-replace operation when supported. Otherwise use a same-directory exclusive file-creation/link-based equivalent that provides no-clobber installation. A general rename that can overwrite an existing target is prohibited.

If the target appears during installation, parse it again and verify its `session_id`. A different or unparseable session target is left byte-for-byte unchanged, the reservation is released or moved transactionally, and suffix selection restarts. Replacement is allowed only when SQLite already records that exact target for the same session and the existing file parses as that session's incomplete target; no other existing file may be replaced. Synchronize the parent directory where supported, reopen the final path, validate again, and hash it.

Only after final read-back verification does SQLite transition to `LOCAL_COMPLETE`. A crash before rename leaves only a hidden temp file; a crash after rename is recognized on launch from its session front matter. Partial bytes never appear under a new final filename.

After local completion, delete transcript, draft, and staging data immediately. As a defensive cleanup, also delete and verify the absence of any residual `transcript-chunks/*.json` or WAV artifacts and remove every corresponding `transcript_chunks` row before cleanup is considered complete. Minimal session and publication metadata remain. If Notion is configured, commit publication `QUEUED` in the same SQLite transaction that commits `LOCAL_COMPLETE`; the publication worker starts afterward.

---

## 12. Notion publication

### 12.1 Authentication and destination

The initial personal implementation uses a Notion internal integration token entered during setup and shared access to one selected parent page. The token is stored in Keychain; SQLite stores only the parent page ID and display label. If a future distribution path requires OAuth, it may replace token acquisition without changing publication identity or behavior.

The client sends an explicit supported `Notion-Version` header held in one adapter constant. API upgrades require contract tests before changing it.

### 12.2 Deterministic representation

- Date key: immutable `lecture_local_date` (`YYYY-MM-DD`).
- Date page title: `YYYY-MM-DD`.
- One child page under the configured parent per date.
- One toggle block per session, title equal to canonical note title.
- Toggle children are the five canonical H2 sections converted in order; YAML front matter is omitted.
- Markdown headings, paragraphs, bullet/numbered lists, quotes, code, and emphasis convert deterministically. Unsupported constructs degrade to plain paragraph text without AI regeneration.

The date page contains a visible plain-text or code-styled marker:

```text
classhelper:date:YYYY-MM-DD
```

The session toggle contains a visible plain-text or code-styled marker as its first child:

```text
classhelper:session:<session_id>
```

Markers must remain explicit and inspectable. Hidden links, custom-scheme links with zero-width labels, and other invisible encodings are prohibited. Markers are implementation metadata, never YAML front matter or lecture claims.

### 12.3 Duplicate-safe publication protocol

Notion offers no cross-request transaction or custom idempotency key for this hierarchy, so the worker uses a persisted state machine and remote reconciliation before every create:

1. Read and validate the verified canonical Markdown; refuse publication if its session ID differs. Convert it to the deterministic limit-safe publication plan and compute `publication_hash` from that transformed plan.
2. Resolve the stored date page ID. If absent/stale, enumerate the configured parent's direct children with Retrieve block children, following `next_cursor` until `has_more = false`. Inspect direct child-page candidates and paginate each candidate's direct children the same way to verify the exact `classhelper:date:YYYY-MM-DD` marker. General search may help discover candidates but is never evidence that a page is absent; every adoption is revalidated against the exact parent ID and marker. A matching title alone is insufficient. If exactly one marked page exists, store its ID; if none after complete pagination, create a page containing the marker and immediately persist the returned ID. If multiple marked pages exist, fail visibly rather than guessing.
3. Resolve the stored toggle ID. If absent/stale, paginate all direct children of the exact date page with Retrieve block children until `has_more = false`, then paginate each candidate toggle's direct children until `has_more = false` and verify the exact session marker. Revalidate parent ID and marker before adoption. If found, persist the ID. If more than one is found, choose no new block, record a duplicate-conflict error, and require diagnosis; never append another.
4. If no toggle exists, append a shell toggle containing the session marker as its first child. Persist the returned block ID before adding note content.
5. Re-read every direct child of the toggle through complete cursor pagination. Add missing section blocks in limit-safe batches only when the remote sequence is a verified prefix of the desired sequence. Each publication attempt compares the desired transformed-content hash and remote block sequence.
6. Confirm the marker, title, five section headings, ordered body representation, and desired transformed-content hash. Persist `PUBLISHED` only after confirmation.

Because a request may succeed remotely while the response is lost, steps 2 and 3 always precede creation on retry. The marker makes the unknown-success window discoverable. The same session is updated/completed; a second toggle is never intentionally appended.

For a partially populated toggle, the publisher does not blindly append the full body. It reads all existing children and appends only the missing suffix when the complete remote sequence is a verified desired prefix after the marker. If the existing children diverge from the desired prefix, or contain any divergent/user-authored child, the attempt stops as `PUBLISH_FAILED`; it does not archive, delete, rebuild, overwrite, or attempt conflict resolution.

The only cleanup exception is an incomplete block created in the same publication attempt whose exact returned block ID is already recorded in that attempt's local ledger. The worker may clean up only those exact IDs before the attempt completes; it must revalidate their parent and must not infer ownership from position, title, or marker alone. Once `PUBLISHED`, every remote edit is user-owned: ClassHelper never deletes, overwrites, rebuilds, or resolves it. Retry may only continue appending from a fully verified safe prefix.

### 12.4 Limit-safe Markdown conversion

The converter enforces the current Notion request constraints before any request is sent:

- each rich-text `content` string is at most 2,000 characters;
- each array and each block-child append batch contains at most 100 elements;
- each serialized request body is at most 500 KB, with safety headroom for JSON escaping and envelope metadata;
- each request contains fewer than 1,000 total block elements across all nested block arrays.

Long paragraphs split at semantic boundaries in this order: paragraph/sentence boundary, whitespace, then a Unicode-scalar-safe hard boundary. Long list items split into deterministic continuation blocks without changing order or introducing new list semantics. Long code blocks split into consecutive code blocks without changing character order. A single oversize construct is never truncated silently. The converter preserves section, block, list-item, inline-text, and code ordering and records a deterministic conversion version.

The `publication_hash` is SHA-256 over a canonical serialization of the fully transformed, limit-safe publication plan, including the explicit date/session markers, toggle title, ordered block sequence, and conversion version—not over raw Markdown. Batch boundaries are transport details and do not alter the hash. Any converter or marker representation change produces a new desired hash and requires reconciliation against the existing owned toggle.

### 12.5 Retry and isolation

Publication runs only from `LOCAL_COMPLETE`. Network timeouts, 408/409/429, and 5xx wait for `max(server Retry-After, jittered exponential backoff)`; 401/403, missing parent, ambiguous identity, or divergent remote children fail immediately with an actionable reason. Automatic retries are bounded per run. User Retry moves `PUBLISH_FAILED → QUEUED` and repeats complete pagination and reconciliation.

No publication failure changes local state, modifies canonical bytes, or retains audio/transcript. Switching the configured parent affects future publication attempts; an already persisted session destination is not silently moved during retry.

---

## 13. Credential and privacy design

The user enters their own personal OpenAI project API key in Settings. The app stores it as a macOS Keychain generic-password item under a bundle-scoped service/account such as `openai-api-key`, accessible only while the user is logged in. The key is never hardcoded in source, build settings, assets, configuration checked into version control, or the application bundle. Reads occur just before a request and values remain in memory only as long as needed. Replacement and deletion go through `CredentialStore`.

Direct client-to-OpenAI use is an explicit security tradeoff accepted only because this is a non-distributed, single-user app running on the key owner's Mac and a hosted backend is outside product scope. Setup recommends a dedicated OpenAI project, the least necessary access, and project usage/spend limits. If the app is distributed to other users, managed centrally, or sandboxed for release, this trust boundary is no longer accepted by default and the authentication/deployment design must be revisited before distribution.

Secrets are prohibited from:

- SQLite and `session.json`;
- canonical Markdown, transcripts, drafts, and filenames;
- logs, error descriptions, analytics, screenshots, and test fixtures.

HTTP logging records host, endpoint category, status, duration, retry count, and provider request ID; it does not record headers or bodies. Transcript and note content are logged only as byte/character counts and hashes. Unified Logging privacy annotations mark session identifiers and paths private.

The app has no analytics SDK, hosted backend, crash-upload service, or application-managed cloud storage. Audio/transcript data sent to configured inference providers is limited to the stage that needs it. Provider privacy/data-retention configuration is documented in setup and validated before acceptance, but this app cannot claim deletion from provider systems beyond their published controls.

---

## 14. Crash recovery and launch reconciliation

On launch, `RecoveryManager` runs before starting queued work:

1. Open/migrate SQLite with WAL and foreign keys enabled and run the configured integrity check. Any failure enters the fail-closed database-error mode defined in Section 7.2; no later step runs.
2. Resume every `discard_requested` protocol first, deleting and verifying remaining artifacts and finalizing only minimal `DISCARDED` metadata. Such a session never re-enters recovery processing.
3. Enumerate recovery directories, validate minimal immutable `session.json`, and inspect final-note paths referenced by session rows.
4. Repair/validate a capture file when possible; compute hashes only at the identity boundaries defined in Section 6.3.
5. Reconcile each SQLite session with actual file presence and structure, not with a duplicate manifest or merely its last state.
6. Remove abandoned hidden temp files only after proving they are not the sole usable same-session draft.
7. Convert any interrupted nonterminal operation to a visible result: verified final note → `LOCAL_COMPLETE`; sufficient audio/transcript/draft → `RECOVERABLE_FAILED`; no sufficient source → finalize `UNRECOVERABLE_FAILED` only after unusable/unnecessary artifacts are deleted and their absence verified, retaining a minimal failure record.
8. Reconcile `LOCAL_COMPLETE` sessions with Notion state; interrupted `PUBLISHING` becomes `PUBLISH_FAILED` or is remotely confirmed before retry.

The app never automatically resumes microphone capture after a crash. It never automatically discards a recovery bundle. Processing may resume only through the visible Retry action, except safe publication reconciliation from a local-complete note.

Normal quit checks active capture and local processing. If either exists, the UI presents the warning required by 02. On confirmed quit, capture is stopped/finalized where possible and durable state is flushed before termination. OS kill remains recoverable through the same launch audit.

---

## 15. Error model and user-facing mapping

Errors are typed by stage and recovery consequence rather than raw provider message:

```text
CaptureError(permissionDenied, deviceUnavailable, diskFull, writerFailed, interrupted)
TranscriptionError(offline, timeout, rateLimited, unauthorized, providerRejected, invalidResult)
GenerationError(offline, timeout, unauthorized, invalidSchema, invalidContent)
SaveError(outputUnavailable, collisionConflict, writeFailed, verificationFailed)
PublicationError(unconfigured, unauthorized, inaccessibleParent, rateLimited,
                 ambiguousDatePage, duplicateSessionMarker, conversionFailed, verificationFailed)
RecoveryError(missingArtifact, corruptArtifact, schemaUnsupported)
```

Each stored failure has: stable non-secret code, stage, recoverable Boolean computed from verified artifacts, brief safe detail, provider request ID if available, and timestamp. The UI derives permitted actions from state plus artifact inventory:

- audio only → `Transcript 재생성`;
- verified transcript → `학습노트 재생성`;
- valid draft → local save Retry;
- local complete + publication failure → Notion Retry;
- recoverable local failure → Discard after deletion confirmation;
- prerequisite error → resolution guidance.

Raw localized provider messages are never treated as policy and are not shown when they could expose request data.

---

## 16. Logging and diagnostics

Use `os.Logger` categories: `lifecycle`, `recording`, `pipeline`, `persistence`, `transcription`, `generation`, and `publication`. Every event includes a private short session correlation value, stage, attempt number, duration, and outcome. State transitions are logged as old/new values; invalid transitions are assertion failures in debug builds and safe errors in release builds.

SQLite stores only the latest actionable failure and small attempt metadata needed for the UI. It is not an event-sourcing system. There is no transcript/audio logging and no indefinite rotating debug file. During development, an opt-in diagnostic export may be assembled manually only from redacted metadata; building a user-facing export feature is outside current scope.

Metrics needed for acceptance are local test records: capture duration/drop count, STT chunk coverage, transcript test sample evidence, generation validation outcome, canonical path/hash, and Notion identity reconciliation result.

---

## 17. Testing strategy

### 17.1 Unit tests

- all valid and invalid transitions across the three independent state axes;
- duplicate Start/Stop/Retry command gates and the limited compare-and-set boundaries that genuinely use row versions;
- UUID/time-zone/midnight identity behavior;
- Korean/English slug normalization, fallback title, suffix selection;
- note rendering/parsing and every `02_Product_Requirements.md §8` structural invariant;
- retry classification and delay selection as `max(Retry-After, jittered exponential backoff)`;
- Markdown-to-Notion conversion, 2,000-character rich-text splitting, 100-element arrays/batches, at-most-500-KB request sizing, fewer-than-1,000 block elements, Unicode-safe paragraph/list/code splitting, semantic order preservation, and transformed-content hashing;
- recovery artifact precedence, deletion eligibility, resumable Discard, unrecoverable cleanup, and database fail-closed behavior;
- audio input-format validation, fixed CAF/PCM properties, ring-buffer capacity/overrun behavior, and a callback instrumentation guard that detects allocation, locks, I/O, Task/actor hops, network, DB, or UI work;
- chunk JSON schema/hash validation, SQLite metadata-only checkpoints, timestamp provenance, timestamp-free sample-range assembly, and verified chunk artifact/row deletion after official transcript success;
- partial unique `canonical_path` reservation, suffix races, and no-clobber installation behavior on volumes with and without exclusive rename.

Property-based tests generate filenames, session IDs, Markdown section content, and crash points to assert that one session never gains two canonical files and a different session's file is never modified.

### 17.2 Integration tests

Use temporary Application Support/output directories, a real SQLite database, fixture audio, and local HTTP protocol fakes. Cover the complete local pipeline, actual-input conversion into the fixed 16 kHz mono PCM CAF, 24 kHz mono Realtime conversion, streaming disconnect without canonical-transcript impact, CAF-to-WAV canonical transcription, chunk JSON checkpoint resume with and without provider timestamps, immediate chunk JSON/WAV/checkpoint-row cleanup after verified `transcript.json`, defensive residual cleanup at `LOCAL_COMPLETE`, invalid AI schema, output-root loss, concurrent same-path reservation, same-session replacement, different-session TOCTOU collision, both no-clobber installation strategies, Keychain abstraction, and Notion unknown-success reconciliation.

Provider contract tests are opt-in and use dedicated test pages/credentials. They verify current audio formats and request/response shapes; Retrieve block children cursor pagination through every page for the configured parent, date page, and toggle; the rule that search cannot prove absence; rich-text/array/request-size/total-block limits; block batching; rate-limit delay mapping; and API version headers without becoming the normal unit suite. Pagination fixtures place the only matching date marker or session toggle after the first page and assert it is found without duplicate creation.

### 17.3 Failure-injection and crash tests

Inject termination or I/O failure after every durability boundary:

- session row before/after audio open;
- audio buffers before/after flush;
- transcript temp write/rename/verification and successor-driven deletion of audio, WAV chunks, transcript chunk JSON, and checkpoint rows;
- each partial transcript JSON write/rename/checkpoint and timestamp-free assembly;
- draft persistence;
- canonical reservation, exclusive install/no-clobber race, final reparse, read-back, and source deletion;
- Discard request persistence, each file deletion, deletion verification, and final state commit;
- unrecoverable cleanup before minimal failure-record commit;
- SQLite open/migration/integrity failures, asserting no work starts and no Recovery file is deleted;
- Notion pagination, date-page create, toggle create, each content batch, same-attempt ledger cleanup, divergent-child refusal, and confirmation.

Relaunch must produce exactly the state justified by artifacts, never false completion, never silent loss of recoverable data, never resume a requested Discard, and never create a duplicate canonical file/toggle. A Notion retry with a verified prefix appends only its suffix; a divergent prefix fails without modifying any remote child, and `PUBLISHED` content is never changed.

### 17.4 UI tests

Verify control availability in `READY/STARTING/RECORDING/PAUSED/STOPPING/BLOCKED`, Stop from Pause, subtitle independence, failure labels/actions, quit warning, new-session independence, local-complete plus publication-failed messaging, and Discard confirmation.

### 17.5 Real-lecture acceptance

Automated tests do not replace AC-22 or AC-23. Before Core Local MVP acceptance, run the specified approximately 50-minute Korean lecture test and store a redacted reviewer worksheet outside production bundles containing the five intervals, reference/detected technical terms, claim evidence, uncertainty checks, and pass/fail. Before Notion-stage acceptance, run AC-17–20 against the configured destination, including response-loss retry and five sessions on one date.

---

## 18. Configuration and versioning

Build-time configuration includes bundle identifier, minimum macOS version, provider base URLs, model identifiers, Notion API version, upload/chunk limits, and retry ceilings. Secrets are never build settings committed to source.

Persisted structures carry independent versions:

- SQLite migration number;
- immutable `session.json` schema;
- transcript schema and source hash;
- `classhelper_schema: 1` for canonical Markdown;
- publication-conversion version and transformed-content hash;
- prompt/schema version supplied by 04.

Migrations are forward-only and tested from every released local schema. An unknown newer recovery schema is not deleted; it becomes visible as an unsupported recoverable item pending an app update.

---

## 19. Security, reliability, and scope checklist

- Local Markdown is the only canonical learning artifact.
- Audio survives every network failure until a transcript is verified, then is deleted immediately.
- Transcript survives generation/save failure until canonical Markdown is verified, then is deleted immediately.
- Partial transcript chunk JSON, WAV derivatives, and their SQLite checkpoint rows are deleted and verified immediately after the official transcript succeeds, with defensive residual cleanup at local completion.
- Recovery data has no age-based expiry and is removed only at the 02-defined lifecycle points.
- Recording, local processing, and publication states remain independent.
- Session UUID and immutable lecture time survive every retry and crash.
- A same-session save adopts/replaces one recorded target; another session's file is never overwritten.
- Canonical-path uniqueness and exclusive no-clobber installation prevent reservation and TOCTOU races.
- A Notion retry fully paginates exact parents and requires explicit date-page and session markers before adopting or creating anything; search/title alone is insufficient.
- Divergent or published Notion children are never deleted or overwritten; cleanup is limited to exact same-attempt ledger IDs.
- Discard and unrecoverable cleanup are crash-resumable, verified deletion protocols; a database failure starts no work and deletes nothing.
- The user's personal OpenAI project key and Notion token exist only in Keychain and memory during use; neither is hardcoded or bundled.
- App Sandbox is disabled in the current scope; the initially selected output root is stored as a standardized local URL.
- SQLite is the sole operational state authority; recovery folders contain only actual recovery files and immutable identity metadata.
- Logs omit lecture content, request bodies, credentials, and raw paths.
- No hosted backend, cloud file store, sync engine, editor, diarization, or other out-of-scope feature is introduced.

---

## 20. External technical references

Implementation must be checked against current official documentation immediately before coding or updating provider adapters. The links below are starting points, not frozen assumptions about routes, model formats, limits, event names, or API versions:

- Apple AVAudioEngine: <https://developer.apple.com/documentation/AVFAudio/audio-engine>
- OpenAI audio and speech guide: <https://platform.openai.com/docs/guides/audio>
- OpenAI Realtime guide: <https://platform.openai.com/docs/guides/realtime>
- Notion Create a page: <https://developers.notion.com/reference/post-page>
- Notion request limits: <https://developers.notion.com/reference/request-limits>
- Notion working with page content: <https://developers.notion.com/docs/working-with-page-content>
- Notion Retrieve block children: <https://developers.notion.com/reference/get-block-children>

These references constrain adapter mechanics only. Upstream product behavior remains authoritative if a provider API changes.

---

## 21. Downstream handoff

`04_AI_Prompt_Specification.md` must define the title/note prompts, exact structured-output schema, source-grounding rules, AI-clarification provenance convention, uncertainty representation, empty-section wording, and validation examples. It must fit the generation and validation boundary described here without changing the required note structure or lifecycle.

Implementation workflow, task decomposition, verification commands, and rules for Codex belong to `05_Codex_Development_Guide.md`.

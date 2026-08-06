# ClassHelper

> Project Overview

**Status:** Canonical

## Project Summary

ClassHelper is a personal macOS desktop application that transforms university lectures into structured learning notes with minimal manual effort.

The application is designed for **one user taking a university class that runs for a 2–3 month academic term**. The 2–3 month period describes the expected duration of a class or term, not the length of a university degree program. ClassHelper is not intended to be a commercial product or a general-purpose note-taking application.

The project's primary objective is to reduce the repetitive work between attending a lecture and obtaining an organized study note.

**The learning note is the primary product outcome; transcription is an intermediate processing artifact.**

---

## Problem Statement

The current workflow is repetitive and inefficient.

After each lecture, the user typically:

1. Records the lecture.
2. Finds and uploads the recording.
3. Generates a transcript.
4. Sends the transcript to an AI again.
5. Generates a learning note.
6. Manually creates a Notion page.
7. Copies the generated content.
8. Organizes recordings and notes manually.

Because this workflow is tedious, recordings frequently accumulate without being reviewed.

---

## Desired User Experience

The intended normal workflow is:

```text
Start Recording
      ↓
Pause / Resume (optional)
      ↓
Stop Recording
      ↓
Automatic Processing
      ↓
Generate Learning Note
      ↓
Automatically Save Local Markdown
      ↓
Publish One-Way to Notion
      ↓
Done
```

During a normal lecture, the user should generally interact with only three controls:

- Start Recording
- Pause / Resume
- Stop Recording

After initial setup, the application should automate the remaining routine steps when processing succeeds. Failures and uncertain results should remain visible to the user rather than being silently treated as complete.

---

## Target User

This application is designed for exactly one user.

Profile:

- University student
- macOS user
- Uses the built-in MacBook microphone
- Uses Notion as the primary study workspace
- Prioritizes convenience and automation over extensibility

---

## Environmental Assumptions

The intended operating environment is:

- Typical lecture duration: approximately 50 minutes
- Setting: in-person university classroom
- Primary language: Korean
- Secondary language content: English technical terminology
- Input device: built-in MacBook microphone
- Primary speaker: one lecturer
- Internet connection: normally available during processing

These assumptions describe the expected environment. Product behavior and implementation decisions are defined in the documents responsible for those topics.

---

## Project Scope

### Included

- Desktop application for macOS
- Lecture audio capture
- Speech-to-text transcription during the lecture
- Optional live subtitle display
- AI-generated lecture title
- AI-generated learning note
- Automatic saving of learning notes as local Markdown files
- One-way publication of learning notes from ClassHelper to Notion
- Date-based organization of generated learning notes
- Recoverable handling of failed lecture-processing sessions

One-way Notion publication does not include importing Notion edits, bidirectional synchronization, real-time synchronization, or conflict resolution.

### Explicitly Out of Scope

- Multi-user support
- User accounts
- Collaboration
- Bidirectional Notion synchronization
- OCR
- PDF analysis
- Screen capture
- Cloud file storage
- Meeting recording
- General-purpose knowledge management
- Public distribution

Cloud AI inference services, such as transcription and language-model APIs, are allowed. Application-managed cloud file storage and hosted backend services are outside the project scope.

---

## Development Strategy

The application will be built incrementally.

### Phase 1 — Reliable Lecture Capture and Transcription

- Record lecture audio.
- Produce a transcript for downstream processing.
- Provide recoverable handling when lecture processing fails.
- Establish stable end-to-end lecture processing before adding later outputs.

### Phase 2 — Learning Note and Local Output

- Generate the learning note.
- Automatically save the learning note as local Markdown.
- Organize generated learning notes by date.

### Phase 3 — Notion Publication

- Publish the learning note one-way to Notion.

Each phase should be exercised with a real university lecture before proceeding. Formal validation and acceptance criteria are defined in `02_Product_Requirements.md`.

---

## Documentation Responsibilities

This overview introduces the project and summarizes its boundaries. Detailed decisions belong to the document with authority over that topic.

| Document | Responsibility and authoritative content |
|---|---|
| `00_Project_Overview.md` | Project identity, problem, intended experience, target user, environmental assumptions, overall scope, development phases, and documentation map |
| `01_Product_Philosophy.md` | Product decision principles, including the roles of audio, automation, local data, cloud services, and AI |
| `02_Product_Requirements.md` | Functional requirements, state transitions, local file and Notion organization, failure behavior, MVP boundary, validation criteria, and acceptance criteria |
| `03_Technical_Design.md` | Application architecture, APIs, storage, security, and retry mechanisms |
| `04_AI_Prompt_Specification.md` | Title and learning-note prompts, output schemas, uncertainty handling, and hallucination safeguards |
| `05_Codex_Development_Guide.md` | Implementation workflow, task order, verification commands, AI working rules, and documentation precedence |

The overview may restate a core invariant when readers need it to understand the project, but the responsible downstream document remains authoritative for detailed policy and behavior.

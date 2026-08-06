# ClassHelper

> Product Philosophy

**Status:** Canonical

## Purpose

This document defines the principles that guide every design decision in ClassHelper.

It does **not** define features, workflows, state transitions, APIs, storage mechanics, or implementation details. Those belong to the authoritative downstream documents.

---

# Authority

This document governs design trade-offs only after satisfying non-negotiable requirements for safety, security, privacy, data integrity, approved project scope, and decisions owned by downstream documents.

It must never override the authoritative responsibility assigned to other project documents.

---

# Non-Negotiable Constraints

- Preserve factual accuracy.
- Never fabricate lecture content.
- Preserve user privacy.
- Minimize unnecessary data retention.
- Respect the approved project scope.
- Prefer explicit uncertainty over confident guessing.

---

# Principle 1 — Zero Friction

Routine manual work **within the approved project scope** should be automated whenever it can be done safely and reliably.

Automation must never reduce accuracy, user control, recoverability, or privacy.

---

# Principle 2 — The Learning Note Is the Product

The learning note is the primary user-facing outcome.

The canonical learning artifact is the **local Markdown learning note**.

Notion is a **one-way publishing destination** for that learning note and is never the authoritative source of project data.

Transcripts exist only as intermediate processing artifacts.

Their lifecycle is defined by `02_Product_Requirements.md`.

---

# Principle 3 — Learning Before Documentation

The objective is improved understanding rather than preserving every spoken sentence.

AI should reorganize information into a structure that supports later study.

---

# Principle 4 — AI Assists, It Does Not Replace

AI should clarify lecture content rather than rewrite it as a textbook.

AI may:
- explain concepts
- explain relationships
- explain importance
- add clearly identified AI-generated clarification

AI must never:
- invent lecture content
- change the lecturer's meaning
- hide uncertainty
- present AI clarification as lecturer statements

Presentation rules belong to `04_AI_Prompt_Specification.md`.

---

# Principle 5 — Never Hide Uncertainty

When confidence is insufficient, uncertainty should be communicated explicitly.

---

# Principle 6 — Audio Exists Only to Enable Learning

Lecture audio exists solely to enable transcription and learning-note generation.

Audio itself is not considered a long-term user artifact.

Specific retention behavior belongs to `02_Product_Requirements.md`.

---

# Principle 7 — Cloud Services Are Tools, Not Products

Cloud services may be used for inference and **one-way publication to Notion**.

Application-managed cloud file storage, hosted application state, and hosted backend persistence are outside the approved project scope.

Technical implementation belongs to `03_Technical_Design.md`.

---

# Principle 8 — Build Only What Is Needed

Do not implement hypothetical future requirements.

---

# Principle 9 — Simplicity Over Complexity

When multiple acceptable solutions exist, choose the simplest one that satisfies every non-negotiable constraint.

---

# Principle 10 — Single Source of Truth

Every important decision should have exactly one authoritative document.

High-level summaries may appear elsewhere, but detailed policy belongs to only one responsible document.

---

# Optimization Priorities

After satisfying every non-negotiable constraint, optimize in this order:

1. User experience
2. Automation
3. Learning quality
4. Simplicity
5. Development speed
6. Cost efficiency

---

# Definition of Success

ClassHelper succeeds when a user finishes a lecture and can later review a structured learning note with little or no manual post-processing during normal successful operation.

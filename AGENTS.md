# ClassHelper Agent Entry Point

Read the Canonical documents in this order before implementation work:

1. [`docs/00_Project_Overview.md`](docs/00_Project_Overview.md) — project identity, scope, intended experience, phases, and documentation map.
2. [`docs/01_Product_Philosophy.md`](docs/01_Product_Philosophy.md) — product principles and non-negotiable constraints.
3. [`docs/02_Product_Requirements.md`](docs/02_Product_Requirements.md) — product behavior, state axes, artifacts, recovery, stages, and acceptance criteria.
4. [`docs/03_Technical_Design.md`](docs/03_Technical_Design.md) — architecture, APIs, persistence, security, retry, recovery, and verification mechanics.
5. [`docs/04_AI_Prompt_Specification.md`](docs/04_AI_Prompt_Specification.md) — prompt and schema contracts, grounding, provenance, uncertainty, validation, and rendering.
6. [`docs/05_Codex_Development_Guide.md`](docs/05_Codex_Development_Guide.md) — implementation workflow, tests, Git safety, stopping, and reporting.
7. [`docs/06_GitHub_Autonomous_Workflow.md`](docs/06_GitHub_Autonomous_Workflow.md) — repository-scoped Issue, branch, commit, PR, review, risk, and merge workflow.

Use the document that owns the disputed topic. If a real Canonical conflict remains, stop and report the exact sections; do not choose an interpretation or edit a Canonical document. Follow all implementation, verification, Git-safety, path-redaction, stop-and-report, and completion-report rules in `05`. Follow `06` only when its repository-scoped Autonomous GitHub Mode is explicitly active; otherwise the default restrictions in `05` apply.

Never add secrets, credentials, real lecture audio, transcripts, generated user learning notes, Recovery artifacts, runtime databases, or diagnostics containing lecture data to Git. Tests may use only synthetic data or explicitly approved redacted fixtures. Use repository-relative paths in reports and redact protected runtime absolute paths as required by `05`.

Do not modify or promote Canonical documents automatically. Verify version-sensitive API behavior against current primary documentation. This repository bootstrap does not authorize ClassHelper feature implementation; later feature work requires its own explicitly scoped work item.

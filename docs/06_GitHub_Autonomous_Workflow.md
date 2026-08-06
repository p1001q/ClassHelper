# ClassHelper

> GitHub Autonomous Workflow

**Status:** Canonical
**Authority:** GitHub-based autonomous development workflow and collaboration artifact rules
**Depends on:** `00_Project_Overview.md`, `01_Product_Philosophy.md`, `02_Product_Requirements.md`, `03_Technical_Design.md`, `04_AI_Prompt_Specification.md`, `05_Codex_Development_Guide.md`

---

## 1. Purpose and authority boundary

This document defines how an authorized AI may operate the ClassHelper GitHub repository after the user completes the initial repository, local-workspace connection, and permission setup. It governs GitHub Issues, branches, commits, pull requests, review loops, merge decisions, audit records, and the collaboration artifacts that support those activities.

This document does not change product scope, product behavior, architecture, provider or model choices, persistence semantics, prompts, schemas, acceptance criteria, implementation safety, or testing policy. Those remain owned by `00`–`05`. In particular:

- `00`–`04` remain authoritative for the product and implementation contract.
- `05_Codex_Development_Guide.md` remains authoritative for implementation order, work-unit scope, safety, tests, stop-and-report, path redaction, final-diff inspection, replacement review when Git metadata is absent, and completion reporting.
- This document adds only a scoped exception to `05`'s default prohibition on GitHub writes.
- No Issue, PR, review tool, repository setting, or AI instruction outranks `00`–`06` or repository-level `AGENTS.md` instructions that conform to them.

When **Autonomous GitHub Mode** is inactive, every default restriction in `05` applies, including the requirement for an explicit user request before commit, push, PR, merge, or other external-state changes. When the mode is active, the one-time authorization described below is the explicit repository-scoped request for the listed GitHub operations. All non-listed actions still require separate authorization.

Canonical documents are read-only during implementation. A Canonical change is always a separate, user-approved documentation task and is High risk under this document.

---

## 2. Autonomous GitHub Mode

### 2.1 Activation

The mode activates only after the user gives a clear, one-time authorization for one identified repository and confirms that the initial setup in Section 12 is complete. Authorization is repository-scoped, not account-wide, organization-wide, or transferable to forks or other repositories.

The activation record must identify:

- repository owner/name or canonical remote URL;
- permitted local workspace;
- default branch (`main`);
- approved merge method;
- required checks and review services;
- whether Low-risk auto-merge is enabled;
- whether Medium-risk auto-merge may be evaluated or is always held;
- the stop-switch instruction.

Activation does not authorize paid usage, production deployment, live provider writes, use of credentials outside their approved purpose, Canonical edits, or bypass of repository controls.

### 2.2 Authorized operations

While active, the AI may autonomously perform the following operations within the authorized repository and the scope of an approved/canonically grounded work item:

- create, edit, label, assign, link, milestone, and close Issues;
- create an Issue branch from current `main`;
- make meaningful checkpoint commits;
- push the Issue branch;
- create, update, mark draft/ready, and maintain a PR;
- request review and re-review, conduct self-review, respond to CodeRabbit or an independent AI review, and rerun required CI/checks when needed;
- update the branch safely when repository policy requires current `main`;
- enable or complete auto-merge only when Sections 9 and 10 permit it;
- merge an eligible Low-risk PR using the repository-approved method;
- merge an eligible Medium-risk PR only when its Issue and PR contain an explicit, evidence-based auto-merge decision satisfying Section 9;
- close the linked Issue after verified merge when GitHub has not already closed it;
- delete the merged remote Issue branch.

The authorization covers repeated cycles of these operations until deactivation. Each cycle must still satisfy the exact-scope, test, review, risk, and audit gates in this document and `05`.

The independent review required by Sections 7 and 10 must be performed by a review agent or tool different from the implementation Agent conducting self-review. If CodeRabbit is unavailable, an independent AI review is mandatory. If neither is available, auto-merge is prohibited and the PR remains on HOLD or moves to stop-and-report when the missing gate cannot be satisfied safely.

### 2.3 Prohibited operations

Autonomous GitHub Mode never permits:

- destructive Git operations, including `git reset --hard`, destructive checkout/restore, `git clean`, or loss of user work;
- force push, forced history rewriting, or rewriting shared/protected history;
- hook bypass, including `--no-verify`;
- bypassing branch protection, rulesets, required checks, reviews, or resolved-conversation requirements;
- direct work on or direct push to `main`;
- exposure of secrets, credentials, request bodies, lecture content, protected paths, or user data in Git, Issues, PRs, reviews, CI logs, or reports;
- committing real lecture artifacts, transcripts, canonical notes containing user data, large binaries, dependency caches, or generated build output;
- automatic modification or promotion of a Canonical document;
- overriding acceptance criteria or changing policy to make an implementation pass;
- evading approval for external paid services, production/live provider writes, publication, deployment, or other real-service mutations;
- deleting unmerged branches or branches with unpreserved user work;
- merging a High-risk or unknown-risk PR without explicit user approval.

An Issue branch that has already been pushed and is shared or has an open PR may be updated from `main` only by merging `main` into it or by a repository/GitHub-supported non-destructive update method. Rebase and force push are prohibited for remote/shared branches. Rebase is permitted only for a local-only private branch that has never been pushed, and only when it preserves user work and every rule in `05`.

### 2.4 Deactivation and stop switch

The user may suspend or revoke the mode at any time with an instruction such as **“Autonomous GitHub Mode 중지”**. A repository permission change, revoked credential, explicit hold label, or repository-configured stop signal also deactivates or pauses the mode.

On stop:

1. do not start another external write;
2. allow an already-running non-destructive local command to finish only when stopping it would risk corruption;
3. do not merge, close, or delete a branch;
4. preserve the current branch and artifacts;
5. report the Issue, branch, PR, last completed check, pending action, and any risk without exposing protected data.

Reactivation requires a new explicit user instruction. The user never loses the ability to inspect, pause, or take over the workflow.

---

## 3. Branch strategy

ClassHelper uses a single stable branch model:

```text
main
└── issue branch
```

- `main` must remain stable and protected.
- A `develop` branch is not used.
- Direct work and direct pushes on `main` are prohibited; all changes reach `main` through a PR.
- Every Issue branch is created from the latest safely fetched `main`.
- One branch normally serves one Issue and one observable outcome.
- After merge is confirmed, the merged Issue branch is deleted.

### 3.1 Naming

```text
feat/<issue-number>-<kebab-slug>
fix/<issue-number>-<kebab-slug>
docs/<issue-number>-<kebab-slug>
refactor/<issue-number>-<kebab-slug>
test/<issue-number>-<kebab-slug>
chore/<issue-number>-<kebab-slug>
```

Examples:

```text
chore/1-create-macos-project
feat/10-session-state-axes
fix/23-prevent-canonical-clobber
test/31-transcript-crash-recovery
docs/42-github-workflow-clarification
```

Do not use `#` in a branch name. The number is a traceability aid; Issue linking and automatic closure are performed by `Closes #N` in the PR body.

The branch prefix describes the primary outcome, not every file changed. `style` is not a supported branch or commit type.

---

## 4. Issue convention

### 4.1 Scope rule

One Issue represents one observable outcome or small vertical slice. It must not combine unrelated failure domains, features, or acceptance criteria. Dependencies are linked rather than silently absorbed. Scope expansion discovered during implementation becomes a follow-up Issue unless it is a small, necessary, behavior-preserving prerequisite allowed by `05`.

Every implementation Issue must cite the exact Canonical section(s) and acceptance criteria that justify the work. An Issue without sufficient Canonical basis may be investigated, but implementation must not begin by guessing policy.

Representative titles:

```text
[Scaffold] Create macOS project
[Domain] Implement session state axes
[Fix] Prevent canonical note clobbering
```

### 4.2 Representative Issue template

```markdown
# Goal
<one observable outcome>

# Canonical Basis
- `02_Product_Requirements.md §...`, AC-...
- `03_Technical_Design.md §...`
- `04_AI_Prompt_Specification.md §...` (if applicable)
- `05_Codex_Development_Guide.md §...`

# Starting State
<fixture, persisted state, artifact, or user action>

# Expected Result
<observable behavior, terminal/intermediate state, and retained/deleted artifacts>

# Scope
## In
- <permitted module or behavior>

## Out
- <explicitly excluded module or behavior>

# Required Verification
- <focused success/failure tests>
- <integration, crash, UI, contract, or full-regression requirements>

# Risk
Low | Medium | High

<classification evidence and affected boundaries>

# Automation
Auto-merge: Yes | No | Evaluate after review
Reason: <policy-based reason>

# Dependencies / Blockers
- <Issue, prerequisite, authorization, or none>
```

For High risk, `Auto-merge: No` is mandatory. Unknown risk is recorded as High until resolved.

---

## 5. Commit convention

Format:

```text
<type>: <imperative summary> (#<issue-number>)
```

Rules:

- write in English;
- use imperative present tense;
- keep the subject concise and omit the final period;
- supported types are `feat`, `fix`, `docs`, `refactor`, `test`, and `chore`;
- do not use `style`;
- do not use vague subjects such as `WIP`, `update`, `fix stuff`, or `misc`;
- keep one logical change per commit;
- do not commit real user lecture artifacts or generated build output;
- do not create standalone generated-file commits when the declared source belongs in the same logical change.

Examples:

```text
chore: create macOS project scaffold (#1)
feat: add session state axes (#10)
fix: prevent cross-session note overwrite (#23)
test: cover transcript retry crash boundaries (#31)
docs: clarify autonomous merge gates (#42)
```

The AI should make meaningful checkpoint commits that preserve understandable progress and enable review. It must avoid noisy micro-commits, repeated fixup/squash spam, and artificial commits created only to appear active. Repository-approved squash merge may combine branch history at merge time while preserving the Issue and PR audit trail.

---

## 6. Pull request convention

### 6.1 Title

Use the category matching the primary outcome:

```text
[Feature] Add session state axes
[Fix] Prevent canonical note clobbering
[Test] Cover transcript crash recovery
[Docs] Clarify GitHub workflow
[Chore] Create macOS project scaffold
[Refactor] Isolate retry classification
```

### 6.2 Scope and draft policy

A PR normally resolves exactly one Issue. It must not expand scope to unrelated cleanup, formatting, dependencies, architecture, or product behavior.

Create the initial PR as Draft if any of the following is incomplete for the current exact head revision: implementation-Agent self-review, required CI/checks, or PR evidence/body completeness. If all three prerequisites already have actual current-exact-head evidence when the PR is created, the PR may be created as Ready. Draft status never weakens safety or verification requirements.

Before marking ready for review:

- the exact Issue scope is implemented or explicitly reported as blocked;
- applicable focused tests have run and their actual status is recorded;
- required broader tests have run, or are accurately marked `NOT RUN`/`NOT AVAILABLE` with a blocking reason;
- the pre-PR diff has been inspected as `PRE_PR_DIFF_CHECK`;
- no known secret, user data, generated output, unrelated change, or unresolved Canonical conflict is present;
- the PR body is current and the risk classification is justified.

After those prerequisites are complete for the current exact head, mark the PR Ready for review before requesting the official independent review. If a code change or new commit updates the PR, return it to Draft when supported and appropriate, or otherwise suspend merge evaluation; then repeat current-head self-review and required CI/checks, complete the PR evidence, and reconfirm Ready status before requesting independent re-review.

### 6.3 Representative PR template

```markdown
Closes #<N>

# Goal
<one observable outcome>

# Canonical Basis
- `02_Product_Requirements.md §...`, AC-...
- `03_Technical_Design.md §...`
- `04_AI_Prompt_Specification.md §...` (if applicable)
- `05_Codex_Development_Guide.md §...`

# Changes
- <repository-relative file/module and behavior>

# Failure Behavior
- <how affected failures, retry, crash, or cleanup behave>

# Verification
- `<actual verified command>` — PASS/FAIL/NOT AVAILABLE/NOT RUN; <summary/reason>

# Invariants
- <invariant> — APPLIES/PASS
- <invariant> — NOT APPLICABLE; <reason>
- <invariant> — BLOCKED; <reason>

# Review Findings
- P0: none | <finding and state>
- P1: none | <finding and state>
- P2: none | <finding, disposition, or follow-up Issue>
- P3: none | <finding and disposition>

# Current-Head Review Gates
- Exact head revision: `<commit SHA>`
- PR state: DRAFT | READY
- Self-review: PASS | BLOCKED
- Required CI/checks: PASS | FAIL | BLOCKED
- PR evidence/body: COMPLETE | INCOMPLETE
- Independent review: CodeRabbit | independent AI; PASS | BLOCKED
- Required conversations: RESOLVED | UNRESOLVED
- Clean review cycles: 0 | 1 | 2
- Review-fix cycles used: 0 | 1 | 2 | 3

# Risk
Low | Medium | High

<classification evidence>

# Merge Decision
Auto-merge eligible | Hold for user approval | Blocked

<decision evidence>

# Unresolved Issues
- None
  or
- <specific blocker/risk>
```

The PR body must contain actual commands and statuses, never guessed commands or unsupported PASS claims. Repository-relative code/configuration paths are permitted; protected paths and user data must be redacted according to `05`.

---

## 7. Review convention

Every PR receives all of the following for the current exact head revision, in this gate order:

1. implementation-Agent self-review of the current exact PR head against the Issue, `00`–`06`, and `AGENTS.md` after the PR is opened or updated;
2. required CI and repository checks;
3. completion of the PR evidence/body and transition or confirmation that the PR is Ready for review;
4. an independent review by CodeRabbit or an independent AI review agent/tool different from the implementation Agent.

If CodeRabbit is not installed or is temporarily unavailable, the independent AI review is mandatory. If neither review path is available, auto-merge is prohibited; the PR remains on HOLD or moves to stop-and-report when the required gate cannot be satisfied safely. CodeRabbit remains advisory and is never the sole authority. A new commit invalidates self-review, checks, independent-review results, and clean-cycle credit from the previous head for purposes of the current-head merge gate.

Review tools are advisory and lower priority than `00`–`06`, `AGENTS.md`, and the exact Issue contract. A reviewer suggestion that conflicts with them is rejected with the governing citation; it is never implemented merely to clear a conversation.

### 7.1 Severity

| Severity | Meaning | Examples | Merge effect |
|---|---|---|---|
| `P0` | Immediate stop | Canonical conflict, data-loss risk, secret or real lecture-data exposure, overwriting another session's file, deleting a sole recovery source, damage to user-authored Notion content | Immediately enter `STOPPED_AND_REPORTED`; no automatic fix, review-fix loop, or merge evaluation |
| `P1` | Merge blocker | Functional error, invalid state transition, retry/idempotency error, official API contract error, material test gap | Must resolve and reverify |
| `P2` | Recommended | Maintainability, small performance issue, unnecessary complexity | Fix when small/in-scope; otherwise follow-up Issue |
| `P3` | Optional | Naming, style, or nit | Does not block merge |

Representative comments:

```text
P0 — This replacement path can overwrite a different session's canonical note. Stop and preserve both files; see 02 §6.5 and 03 canonical-save invariants.

P1 — A retry can persist LOCAL_COMPLETE before read-back verification. Move the state transition after verification and add the crash-boundary test required by the Issue.

P2 — Retry classification is duplicated in two adapters. Consolidate it if the change remains local; otherwise open a follow-up Issue rather than expanding this PR.

P3 — Consider renaming `resultData` to reflect that it contains a validated transcript.
```

Every P0 immediately stops the cycle under `05 §12`, regardless of when it is found. P0 must not enter an automatic correction loop or merge evaluation. P0 and High risk are not synonyms: every P0 is an immediate stop condition, while a High-risk change that is not P0 may proceed through PR and review but must wait for explicit user merge approval.

Unresolved P1 findings or any failed required check prohibit merge. All required conversations must be resolved. P2 is fixed when the correction is small and within scope; otherwise it becomes a linked follow-up Issue. P3 may remain open only when repository policy does not require resolution, but it never independently blocks merge.

### 7.2 Bounded review-fix loop

P0 never enters a review-fix cycle. At most three review-fix correction cycles are allowed per PR for code-changing responses to P1, P2, or P3 review feedback:

```text
review → classify → minimally fix → retest → update evidence → re-review
```

A review-fix correction cycle is consumed whenever review feedback causes a code, test, or configuration-file change that produces a new commit or PR head revision, regardless of whether the finding is P1, P2, or P3. Multiple related corrections delivered in one new head consume one cycle; splitting trivial corrections across commits does not create additional allowance. Duplicate-comment cleanup, explanatory replies, and reconfirmation or reapproval without a code change do not consume a cycle.

The count is cumulative for the PR and is not reset by a new head. It must not be evaded by splitting minor fixes into multiple commits or by opening a replacement PR to continue the same review-fix work. After three cycles are consumed, do not make further review-driven code changes in the current work item: an unresolved P1 requires stop-and-report and prohibits merge; a P2 that is not merge-required becomes a linked follow-up Issue; and a P3 may remain unimplemented and does not block merge. If a nominal P2 is actually P1 or High risk, reclassify it and apply the corresponding rule.

The review-fix count is separate from the Medium-risk clean review-cycle count. Every correction that creates a new head resets the clean count to zero while preserving the cumulative review-fix count. Do not weaken tests, hide findings, or broaden the PR to force convergence.

---

## 8. Risk classification and merge policy

Risk is classified before implementation and reassessed from the final diff. The higher classification wins. If the risk cannot be established confidently, it defaults to High. Discovering a P0 during classification does not merely classify the work as High: it immediately triggers stop-and-report. A non-P0 High-risk boundary upgrades the risk to High, prohibits auto-merge, and may proceed to a reviewed PR awaiting user approval.

### 8.1 Low

Low risk is isolated behavior with no persistent schema or data deletion, security/privacy boundary, provider contract, real external write, or other High-risk boundary.

Examples may include narrow UI presentation, isolated pure logic, synthetic test coverage, or non-Canonical workflow documentation. Low risk may auto-merge when every Section 10 requirement passes.

### 8.2 Medium

Medium risk affects shared state, concurrency, recovery behavior, or multiple component boundaries but does not cross a listed High-risk boundary. It requires stronger affected-boundary tests and **two clean review cycles** on the same exact head revision.

A clean review cycle consists of all of the following for that exact head: (a) implementation-Agent self-review completed, (b) required CI/checks confirmed PASS, (c) an independent reviewer determines that no P0/P1 exists, and (d) all required conversations are resolved. Re-reading the same result or reconfirming the same approval/comment does not create another cycle.

The second clean cycle requires a separate independent review invocation or assessment after the first clean cycle, plus a fresh confirmation of required checks. It may examine the unchanged same head; a simple UI reapproval click is insufficient. Any new commit resets the clean count to zero and requires affected and all repository-required checks, self-review, and independent review on the new head. When a P1 is fixed, the resulting new head must complete both Medium-required clean cycles from zero. P0 immediately stops. Discovery of a non-P0 High-risk boundary upgrades the PR to High and prohibits auto-merge.

The Issue and PR must explicitly decide whether auto-merge is permitted, with evidence. If the decision is absent, evidence is incomplete, the repository is configured to hold Medium risk, or the change approaches a High boundary, merge waits for the user.

### 8.3 High

High risk includes:

- any Canonical document change or status promotion;
- database migration or schema change;
- recovery, audio, or transcript deletion lifecycle;
- Keychain, privacy, authentication, or security behavior;
- OpenAI or Notion adapter contract, model, API version, endpoint, request/response schema, or audio format;
- dependency major-version upgrade;
- real external-service writes or production/live provider testing;
- acceptance-criteria changes or reinterpretation;
- user-data destructive behavior.

The AI may automate the Issue, branch, implementation, tests, PR, review, and bounded corrections for High risk. Before waiting for final user approval, the PR must be Ready for review and contain the required current-head review evidence. Final merge always requires explicit user approval after a concise risk/evidence report. Repository auto-merge must not be enabled for the PR.

---

## 9. Merge policy

### 9.1 Risk decision

- **Low:** may auto-merge after all gates pass.
- **Medium:** may auto-merge only after explicit Issue/PR eligibility, stronger tests, and two valid clean review cycles recorded for the same exact current head revision, plus all gates; otherwise hold.
- **High or unknown:** never auto-merge; hold for explicit user approval.

User approval authorizes the final High-risk merge only after the reported revision and checks. A material code change after approval requires renewed review and approval.

### 9.2 Repository controls

Use only a repository-approved merge method. Squash merge is recommended so the final PR title provides a concise `main` history while the PR retains checkpoint commits and review evidence. The final PR title and linked Issue must preserve traceability.

Never bypass branch protection or rulesets. If GitHub refuses a merge, diagnose the unmet policy rather than using administrator bypass or a different route.

---

## 10. Auto-merge requirements

Every item must be true before auto-merge:

- [ ] The PR links exactly one intended Issue with `Closes #N` and implements its exact scope.
- [ ] The branch is updated with the latest `main` when repository policy requires it.
- [ ] All required CI and repository checks pass.
- [ ] All applicable focused, integration, failure, crash, UI, contract, and full-regression tests required by `05` and the Issue are green.
- [ ] Actual commands, statuses, and material results are recorded; no `NOT RUN`, `NOT AVAILABLE`, failure, or flakiness undermines the completion claim.
- [ ] Final diff and working-tree state have been inspected according to `05`.
- [ ] Implementation-Agent self-review is complete for the current exact head revision.
- [ ] An independent review by CodeRabbit or a different AI review agent/tool is complete for the current exact head revision; if neither is available, auto-merge is prohibited.
- [ ] No P0 was discovered; no P1 finding is unresolved; all required conversations are resolved.
- [ ] P2 findings are fixed or linked to justified follow-up Issues without hiding required work.
- [ ] No Canonical conflict or unauthorized acceptance-policy change exists.
- [ ] The final classification is Low with one valid clean cycle, or explicitly eligible Medium with two separately invoked valid clean cycles recorded for the same exact current head revision.
- [ ] The PR is not Draft and is Ready for review.
- [ ] The cumulative review-fix count is recorded and does not exceed three cycles.
- [ ] The diff contains no High-risk boundary, secret, protected user data, real lecture artifact, or generated build output.
- [ ] The repository-approved merge method is used and no protection/ruleset is bypassed.
- [ ] The audit record and PR Merge Decision are current for the exact head revision.

If any item is false or unknown, auto-merge is prohibited. The PR remains open and the cycle moves to hold or stop-and-report.

Any new commit invalidates prior-head self-review, checks, independent review, Ready-gate evidence, and clean-cycle credit for this checklist. Return the PR to Draft when supported and appropriate, or suspend merge evaluation, then complete the required gates again for the new exact head and reconfirm Ready before independent review. The cumulative review-fix count does not reset.

---

## 11. Failure handling

### 11.1 CI or test failure

Reproduce with the smallest relevant verified command, diagnose the implementation/test/environment cause, make the smallest in-scope correction, and rerun affected verification. Never hide, skip, disable, weaken, quarantine, or relabel a failure as passed. Follow `05 §8` for flaky tests and full-regression conditions.

### 11.2 Review failure

Classify findings P0–P3. A P0 immediately enters `STOPPED_AND_REPORTED` without an automatic correction or merge evaluation. Correct eligible P1/P2/P3 findings within the shared bounded loop in Section 7.2, retest, update the PR evidence, reconfirm Ready status, and request incremental independent re-review. A requested speculative refactor does not justify scope expansion.

### 11.3 Merge conflict

For an Issue branch that has already been pushed, is shared, or has an open PR, update it from current `main` only by merging `main` into the branch or using a repository/GitHub-supported non-destructive update method. Do not rebase or force push a remote/shared branch. Rebase is limited to a local-only private branch that has never been pushed. Reinspect the resolved diff and rerun affected and repository-required checks on the resulting exact head. If resolution overlaps user changes, changes behavior, threatens data, requires force, or makes risk uncertain, stop and report instead of choosing a side.

### 11.4 Mandatory stop-and-report

In addition to every condition in `05 §12`, stop and report when:

- an official API makes the Canonical design impossible;
- Canonical requirements are ambiguous or conflicting;
- there is a data-loss, privacy, secret, or cross-session overwrite risk;
- unexpected user changes overlap the work;
- a required credential is absent;
- a live provider test or real external write lacks explicit authorization;
- repository protection cannot be satisfied without bypass;
- any P0 is discovered, including a Canonical conflict, data-loss risk, secret or real lecture-data exposure, another session's file overwrite, sole recovery source deletion, or damage to user-authored Notion content;
- P1 remains after three review-fix correction cycles; after exhaustion, separate non-blocking P2 into a follow-up Issue and allow P3 to remain as Section 7.2 defines.

The report follows `05`'s evidence and path-redaction rules and records the safe work already completed. Do not substitute an undocumented fallback or silently continue to another Issue.

---

## 12. Initial GitHub setup checklist for the user

Git initialization itself remains a user-authorized action under `05`. Before Autonomous GitHub Mode is activated, the user completes or explicitly authorizes the initial repository boundary:

- [ ] Create the GitHub repository.
- [ ] Connect the intended local workspace to the repository remote.
- [ ] Choose private or public visibility knowingly; private is preferred when repository contents or development records could reveal sensitive context.
- [ ] Set `main` as the default branch.
- [ ] Enable GitHub Actions and Issues.
- [ ] Enable repository auto-merge if Low-risk automation is desired.
- [ ] Configure a ruleset or branch protection for `main`:
  - PR required;
  - required CI/status checks;
  - required conversation resolution;
  - direct push blocked;
  - force push disabled;
  - branch deletion disabled.
- [ ] Install and authorize Codex for only the intended repository and required permissions.
- [ ] Optionally install and authorize CodeRabbit.
- [ ] Add GitHub Actions secrets only when a verified workflow needs them, using least privilege.
- [ ] Never add local lecture data, transcripts, recordings, canonical user notes, or user-output paths as repository secrets or fixtures.
- [ ] Record the approved merge method, risk policy, and stop switch in the activation record.

Provider credentials and live destinations remain separately governed by `03`, `05`, and explicit live-write authorization. Repository access is not provider-write approval.

---

## 13. CodeRabbit policy

CodeRabbit is a secondary reviewer, not an authority and not the sole merge decision-maker. Its findings must be verified against the Issue, `00`–`06`, `AGENTS.md`, actual code, tests, and current official API documentation where relevant.

The recommended `.coderabbit.yaml` design should request:

- Korean review comments;
- a concrete cause, actual risk, and minimal in-scope fix for each finding;
- explicit priority for Canonical documents, `AGENTS.md`, and the linked Issue;
- no speculative refactoring or hypothetical extensibility;
- a high-level change summary;
- changed-file summaries;
- linked-Issue scope and acceptance assessment;
- automatic review and incremental review after updates;
- repository code-guideline awareness;
- web search when current official documentation is needed for version-sensitive mechanics.

The design should disable unless later deliberately chosen:

- poems;
- always-on sequence diagrams;
- chat auto-reply;
- reviewer auto-assignment;
- label auto-assignment.

A request-changes workflow may be enabled only after repository experience shows that its blocking output maps reliably to P0/P1. CodeRabbit alone must never determine risk, waive checks, approve Canonical changes, or merge a PR.

CodeRabbit configuration keys and schema are version-sensitive. During repository setup, verify the then-current official schema before creating `.coderabbit.yaml`. This document defines desired behavior, not possibly stale configuration keys.

---

## 14. Repository artifacts to generate later

This documentation task does not create repository automation files. During a separately authorized repository-setup task, generate and review as applicable:

```text
.github/ISSUE_TEMPLATE/implementation.yml
.github/pull_request_template.md
.github/workflows/ci.yml
.coderabbit.yaml
AGENTS.md
```

Optional setup artifacts include label definitions and ruleset/branch-protection documentation. Their contents must implement this document without copying product rules into a second authority or hardcoding stale external schemas.

---

## 15. Naming and code style boundary

Swift naming and formatting are owned by the implementation language, the project formatter/linter, and established repository conventions. Java/Spring MuseReview rules are not imported into ClassHelper.

Use Swift-appropriate conventions such as `PascalCase` for types and `lowerCamelCase` for functions and properties. Use `UPPER_SNAKE_CASE` only if Swift or established project conventions call for it. Do not impose a Java-specific prohibition on underscores or create workflow-only formatting rules that conflict with the project formatter.

Workflow artifacts use the GitHub naming rules in this document; source code follows the project's verified Swift conventions.

---

## 16. Reporting and audit trail

Each autonomous cycle leaves a concise, inspectable record containing:

- Issue number, Issue URL, goal, and final Issue state (`open` or `closed`);
- Canonical basis and acceptance criteria;
- branch name;
- checkpoint commits;
- PR number, PR URL, and exact head revision;
- actual checks/tests and statuses;
- self-review and external review iterations;
- cumulative review-fix cycles used and Medium clean-cycle count;
- P0–P3 findings and dispositions;
- initial and final risk classification;
- merge, hold, or stop decision with reason;
- merged-branch deletion or preserved-branch state;
- follow-up Issues and unresolved blockers.

The primary durable record is the linked Issue and PR, supplemented by the `05` completion or blocker report. Records must be short enough to inspect after the fact, exact enough to reproduce decisions, and redacted according to `05`. They must not contain actual user paths, secrets, or lecture content. Activity volume is not a substitute for traceability.

### 16.1 Autonomous cycle state machine

```text
MODE_INACTIVE
  └─ user repository-scoped authorization
      → READY

READY
  → ISSUE_DEFINED
  → BRANCH_CREATED
  → IMPLEMENTING
  → VERIFYING
  → PRE_PR_DIFF_CHECK
  → COMMITTING
  → PUSHING
  → PR_OPEN_OR_UPDATED
      ├─ any current-head Ready prerequisite incomplete
      │    → PR_OPEN_OR_UPDATED_DRAFT
      │    → SELF_REVIEW_CURRENT_HEAD
      │    → CI_CURRENT_HEAD
      │    → PR_EVIDENCE_COMPLETE
      │    → MARK_READY_FOR_REVIEW
      └─ all current-head Ready prerequisites already evidenced
           → PR_OPENED_READY
  → INDEPENDENT_REVIEW_CURRENT_HEAD
      ├─ P0 → STOPPED_AND_REPORTED
      ├─ P1/P2/P3 requiring code change and REVIEW_FIX_COUNT < 3 → CORRECTION_LOOP
      │    → increment REVIEW_FIX_COUNT; reset Medium clean count to 0
      │    → IMPLEMENTING → VERIFYING → PRE_PR_DIFF_CHECK
      │    → COMMITTING → PUSHING → PR_OPEN_OR_UPDATED_DRAFT
      │    → SELF_REVIEW_CURRENT_HEAD
      │    → CI_CURRENT_HEAD
      │    → PR_EVIDENCE_COMPLETE
      │    → MARK_READY_FOR_REVIEW
      │    → INDEPENDENT_REVIEW_CURRENT_HEAD
      ├─ REVIEW_FIX_COUNT = 3 and P1 remains → STOPPED_AND_REPORTED
      ├─ REVIEW_FIX_COUNT = 3 and non-blocking P2 remains → FOLLOW_UP_ISSUE; no further current-PR fix
      ├─ REVIEW_FIX_COUNT = 3 and P3 remains → PROCEED_WITHOUT_FIX
      ├─ non-P0 High/unknown → HOLD_FOR_USER_APPROVAL
      ├─ Low clean cycle 1 → MERGE_EVALUATION
      └─ Medium clean cycle 1 → MEDIUM_CLEAN_REVIEW_1

MEDIUM_CLEAN_REVIEW_1
  → separate independent review invocation/assessment on the same exact head
  → required checks confirmation on the same exact head
  → MEDIUM_CLEAN_REVIEW_2
      ├─ P0 → STOPPED_AND_REPORTED
      ├─ P1/P2/P3 requiring code change and REVIEW_FIX_COUNT < 3 → CORRECTION_LOOP; new head resets clean count to 0
      ├─ REVIEW_FIX_COUNT = 3 and P1 remains → STOPPED_AND_REPORTED
      ├─ REVIEW_FIX_COUNT = 3 and non-blocking P2 remains → FOLLOW_UP_ISSUE; no further current-PR fix
      ├─ REVIEW_FIX_COUNT = 3 and P3 remains → PROCEED_WITHOUT_FIX
      ├─ non-P0 High boundary → HOLD_FOR_USER_APPROVAL
      └─ valid clean cycle 2 → MERGE_EVALUATION

Any new commit
  → PR_OPEN_OR_UPDATED_DRAFT, or suspend merge evaluation when Draft transition is unavailable/unnecessary
  → reset clean count to 0
  → preserve cumulative REVIEW_FIX_COUNT
  → SELF_REVIEW_CURRENT_HEAD
  → CI_CURRENT_HEAD
  → PR_EVIDENCE_COMPLETE
  → MARK_READY_FOR_REVIEW
  → INDEPENDENT_REVIEW_CURRENT_HEAD

MERGE_EVALUATION
  ├─ Low + all gates → AUTO_MERGE
  ├─ eligible Medium + two clean cycles on the exact head + all gates → AUTO_MERGE
  ├─ High/unknown or Medium held → HOLD_FOR_USER_APPROVAL
  └─ failed/unknown gate → BLOCKED_OR_STOPPED

AUTO_MERGE or USER_APPROVED_MERGE
  → VERIFY_MERGED
  → CLOSE_ISSUE
  → DELETE_MERGED_BRANCH
  → RECORD_CYCLE
  → READY

Any state
  ├─ P0 → STOPPED_AND_REPORTED
  └─ stop switch → PAUSED_AND_REPORTED
```

### 16.2 Cycle checklist

- [ ] Confirm Autonomous GitHub Mode is active for this repository.
- [ ] Read the exact governing Canonical sections, `05`, `06`, and `AGENTS.md`.
- [ ] Define one Issue outcome, scope, verification, dependencies, and risk.
- [ ] Create the named branch from current `main`.
- [ ] Implement the smallest coherent change without disturbing user work.
- [ ] Run focused then required broader verification using discovered commands.
- [ ] Perform `PRE_PR_DIFF_CHECK`: inspect working-tree status and the pre-PR diff.
- [ ] Make meaningful checkpoint commit(s) and push the Issue branch.
- [ ] Open/update the PR with exact evidence and `Closes #N`.
- [ ] Complete official self-review on the current exact PR head.
- [ ] Confirm required CI/checks PASS on the current exact PR head.
- [ ] Complete the PR evidence/body, then mark or confirm the PR Ready for review.
- [ ] Only after the PR is Ready, obtain CodeRabbit or different-agent/tool independent review on the current exact PR head and resolve required conversations.
- [ ] For Medium risk, record two valid clean review cycles on the same exact head using separate independent assessments; do not count rereads or UI reapproval.
- [ ] On any new commit, update the PR, return it to Draft when supported and appropriate or suspend merge evaluation, reset clean-cycle credit, preserve the cumulative review-fix count, and repeat current-head self-review, required checks, evidence completion, Ready confirmation, and independent review.
- [ ] If P0 is discovered, stop and report immediately; for any P1/P2/P3 correction that creates a new head, increment the shared PR maximum-three review-fix count, retest, and update the audit record.
- [ ] At three review-fix cycles, stop for remaining P1, move non-blocking P2 to a follow-up Issue, and allow P3 to remain; do not evade the limit with split commits or a replacement PR.
- [ ] Reclassify final risk and evaluate every auto-merge gate.
- [ ] Auto-merge only when permitted; otherwise hold or stop-and-report.
- [ ] Verify merge before closing the Issue or deleting the merged branch.
- [ ] Record the final decision and proceed only if the mode remains active.

---

## 17. Canonical promotion

This document begins as:

```text
**Status:** Canonical Candidate
```

While it is a candidate, Codex reviews it against `00`–`05` and the requested GitHub-workflow scope. Promotion requires a Codex final review result of **PASS** with no mandatory changes.

- On **NEEDS CHANGES**, the reviewer reports findings and does not edit the file.
- On **PASS**, promotion changes only the status line to `**Status:** Canonical`.
- Promotion is a High-risk Canonical change and requires the user's separate approval; Autonomous GitHub Mode cannot perform it automatically.
- No unrelated content may be rewritten during promotion.

This document cannot promote itself, alter `00`–`05`, or convert GitHub automation into authority over product policy.

---

## 18. Conformance checklist

- It defines GitHub workflow and collaboration artifacts only.
- It preserves the product, technical, AI, implementation, test, safety, and reporting rules in `00`–`05`.
- It grants scoped GitHub write authority only while repository-scoped Autonomous GitHub Mode is active.
- It leaves destructive Git, control bypass, secrets, Canonical auto-edits, and unauthorized external writes prohibited.
- It uses `main` plus Issue branches, no `develop`, PR-only integration, and `Closes #N` linkage.
- It limits each Issue and PR to one observable outcome.
- It requires self-review, CI, independent review, bounded correction cycles, risk classification, and exact audit evidence.
- It auto-merges only eligible Low or explicitly eligible Medium risk after every gate passes.
- It holds High and unknown risk for explicit user approval.
- It retains the user's stop switch and never makes repository automation irreversible.

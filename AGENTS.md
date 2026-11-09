# AI Development Instructions

## Source of truth and workflow

The current repository on branch `main` is the source of truth. At the start of substantial work, inspect the current implementation, owning document, tests, branch, and available working-tree state. Preserve unrelated work. Never infer current behavior from conversation history alone.

Follow the seven-stage workflow in `docs/01-PROJECT.md` and current status in `docs/06-STATUS.md`. The canonical user-facing entry points are:

1. `scripts/k41-live-validation.sh` — Arch ISO readiness, read-only.
2. `scripts/k41-install-basic-arch.sh` — Arch base installation; destructive.
3. `scripts/k41-install-desktop.sh` — desktop setup from installed Arch TTY.
4. Desktop functional validation.
5. Desktop customization.
6. Desktop and hardware optimization.
7. Release.

The Stage 2 and Stage 3 entry points currently delegate to legacy implementation scripts. Keep wrappers thin; do not duplicate implementation. First-boot diagnostics are optional and are not a required gate between Stages 2 and 3.

## Documentation ownership

- `README.md`: concise project entry and canonical workflow.
- `AGENTS.md`: AI workflow, repository editing, safety, and reporting rules.
- `docs/00-START-HERE.md`: navigation and source-of-truth index.
- `docs/01-PROJECT.md`: purpose, seven stages, architecture, decisions.
- `docs/02-INSTALLATION.md`: Stage 1–3 live readiness, basic Arch installation, and desktop installation handoff.
- `docs/03-DESKTOP.md`: desktop setup, Stage 4 functional acceptance, Stage 5 customization.
- `docs/04-TESTING.md` and `tests/README.md`: automated test and acceptance principles.
- `docs/05-OPERATIONS.md`: security, recovery, Stage 6 optimization.
- `docs/06-STATUS.md`: current stage, status, evidence, and priorities.
- `docs/archive/`: historical material only; never cite archived instructions as current procedures.

Each topic has one owning document. Keep other documents concise and link to the owner. When workflow or implementation changes, update affected owners, summaries, tests, and cross-references together. Do not restore references to archived paths as active instructions.

## Required change process

Before edits:
1. Inspect current branch and repository state where available.
2. Read the owning document, affected implementation, and relevant tests.
3. Identify requirements, interfaces, safety constraints, and acceptance criteria.
4. Keep changes focused and preserve unrelated work.
5. Ask only when an ambiguity changes safety, scope, or a material architecture decision.

After edits:
1. Fetch/read every changed file again to verify the write.
2. Run relevant safe tests and report exact commands/results.
3. Review references and documentation consistency.
4. Update `docs/06-STATUS.md` when project state materially changes.
5. Report changed files, commit evidence, tests not run, limitations, and next gate.

## Truth and status

Use these labels precisely:
- **PLANNED**: not implemented.
- **IMPLEMENTED**: code exists and repository state confirms it.
- **TESTED**: named tests were actually executed.
- **VERIFIED**: behavior was confirmed with appropriate evidence.
- **RELEASED**: incorporated into an explicitly designated release.
- **NOT TESTED**: no adequate test evidence.

A file existing or wrapper delegating does not prove runtime behavior. Syntax checks do not prove correct execution. Fixture tests do not prove physical hardware compatibility. Never fabricate repository content, test output, upstream compatibility, or successful GitHub operations.

## Safety and security

- Never perform destructive disk operations without explicit user authorization and verified target identity.
- Keep storage operations fail-closed. Uncertain prerequisites, target identity, integrity, or configuration must stop the operation.
- Stage 1 readiness is read-only. Stage 2 installation can erase the selected internal SSD and requires backup, source review, target review, and explicit confirmations.
- Stage 3 desktop setup must run from installed Arch Linux TTY as the regular user via sudo; it must not run from the ISO, chroot, or graphical session.
- First-boot diagnostics are optional; do not reintroduce them as a mandatory gate before Stage 3.
- Never disable package signature/integrity verification or pipe remotely retrieved scripts directly into a shell.
- Build AUR packages as an unprivileged user after reviewing their recipe.
- Never place passwords, LUKS passphrases, recovery keys, tokens, cookies, or credentials in logs/reports.
- Do not execute privileged operations, change real system configuration, or perform destructive actions merely to validate a design.
- Do not use virtual machines for project validation; the user has explicitly ruled out VM testing.
- Use deterministic fixtures, mocks, static checks, and disposable loop-backed devices only for bounded automated tests. They do not replace physical X280 validation.

## Architecture and engineering

Use Bash unless another language has a documented material advantage. Quote expansions, validate inputs, handle errors, limit privileges, and use ShellCheck where available. Add tests alongside behavior changes where feasible. Keep canonical entry points thin and single-purpose. Avoid duplicated logic, unnecessary dependencies, and competing power-management services.

Verify version-sensitive package names, dependencies, and installation methods against official upstream documentation. Preserve the policy that bootstrap retrieves latest `main`, displays its resolved commit SHA, requires source review, and applies separate readiness and installer acknowledgements. A SHA identifies a revision; it does not prove safety.

## Scope and reporting

Do only the work requested. Do not merge pull requests, create releases/tags, or perform other consequential repository actions unless explicitly authorized. Never claim tests ran unless they actually ran. Report what changed, what was verified, what was not tested, risks, and the next concrete stage.

# AI Development Instructions

## Purpose

These instructions govern AI-assisted work in this repository. The repository and its reviewed files are the source of truth; conversation history or model memory must not override them.

## Project continuity and anti-drift

- The committed repository is the source of truth, not conversation summaries, model memory, or assumptions about earlier work.
- At the start of each substantial task, read the current implementation/status record, the owning domain document, the relevant approved requirements/decisions, and the actual code/tests being changed.
- Continue from the latest verified repository state. Do not recreate, replace, or bypass an existing module because a conversation summary describes it incompletely.
- Record material architecture decisions, evidence, test results, limitations, and the next gate in the owning documentation and status/changelog before ending the work.
- Clearly label design proposals as PLANNED until code exists; label code IMPLEMENTED only after repository verification; label behavior TESTED only after the stated test actually ran; label hardware behavior NOT TESTED until observed on the actual device.
- When repository evidence is missing or contradictory, stop and inspect it. Do not fill gaps with plausible-sounding implementation details.

## Required workflow

Before changing files:

1. Inspect the current branch, working-tree changes when available, and relevant repository files.
2. Read `README.md`, `docs/01-PROJECT-CHARTER.md`, `docs/02-REQUIREMENTS-AND-DECISIONS.md`, and `docs/03-ARCHITECTURE-AND-MODULES.md`. Read the relevant domain documents and tests before work that affects them.
3. Identify applicable requirement IDs, existing behavior, constraints, and acceptance criteria.
4. Keep the change focused. Preserve unrelated work and do not overwrite or delete content without inspecting it.
5. If a material requirement or safety decision is ambiguous, explain the ambiguity and ask before proceeding. Do not silently invent a project decision.

After changing files:

1. Verify every successful write by fetching or reading the resulting repository content again.
2. Run relevant checks when available and safe. State the exact checks run and their results.
3. Review the diff for unintended changes and consistency with related documentation.
4. Update status and changelog documentation when the change materially affects project state.
5. Report changed files, verification evidence, tests not run, limitations, and remaining work.

## Truth and status

- Never invent repository contents, upstream facts, command results, test results, or successful operations.
- Distinguish proposals and assumptions from approved decisions and verified facts.
- Use the status vocabulary defined in `docs/01-PROJECT-CHARTER.md`, including `NOT TESTED`; do not create competing definitions.
- A file existing does not prove its behavior works. Syntax checks do not prove runtime correctness; simulated tests do not prove hardware compatibility.
- Never mark a requirement or feature tested, verified, or released without appropriate evidence.

## Safety and security

- Never perform destructive disk operations without explicit authorization and verified target identification.
- Keep the installer fail-closed: uncertain prerequisites, target identity, integrity, or critical configuration must stop the relevant operation safely.
- Never bypass package signature or integrity verification.
- Never pipe remotely retrieved scripts directly into a shell.
- Build AUR packages as an unprivileged user; do not run package build steps as root.
- Never place passwords, LUKS passphrases, recovery keys, tokens, or other credentials in logs or reports.
- Do not execute privileged operations, modify real system configuration, or make destructive changes merely to validate a proposed design.
- Do not use virtual machines for project validation; the user has explicitly ruled out VM testing.
- Use deterministic fixtures, mocks, static checks, and disposable loop-backed devices only for bounded automated tests. These do not replace hardware validation.
- Preserve the real destructive installer path: the required end-to-end installation/erase test is performed on the actual ThinkPad X280 SSD after all safety gates pass, with explicit authorization and verified target identity. Never replace this acceptance step with a VM test or remove destructive operations merely to avoid VM testing.

## Architecture and implementation

- Follow `docs/03-ARCHITECTURE-AND-MODULES.md` and the owning domain document.
- Keep each module within its documented responsibility and privilege boundary. Do not add overlapping ownership of destructive operations or system configuration.
- Before implementing a module, ensure its contract and acceptance criteria are sufficiently clear; surface missing decisions rather than guessing.
- Prefer small, maintainable changes over premature frameworks, duplicated logic, or unnecessary dependencies.
- Verify current official upstream documentation for version-sensitive packages, dependencies, and installation methods. Record important sources and unresolved compatibility questions.
- Preserve the approved policy of retrieving the latest `main` commit for an installation attempt and displaying its resolved SHA. A SHA identifies a revision; it does not prove that the revision is safe.

## Documentation ownership and conflicts

- Give each topic one owning document. The owning document is the canonical location for the complete, authoritative treatment of that topic.
- Use this ownership map:
  - `AGENTS.md`: AI workflow, repository-editing rules, safety boundaries, and reporting requirements.
  - `docs/01-PROJECT-CHARTER.md`: project purpose, scope, goals, and guiding principles.
  - `docs/02-REQUIREMENTS-AND-DECISIONS.md`: requirement IDs and approved project decisions.
  - `docs/03-ARCHITECTURE-AND-MODULES.md`: current system architecture, module boundaries, and interfaces, consistent with approved requirements and decisions.
  - `docs/04-INSTALLATION-AND-DISK.md`: canonical storage, encryption, boot, swap/resume, and disk-recovery contract.
  - `tests/README.md`: canonical test commands, manifest, evidence artifacts, and test-layer limitations.
  - `docs/11-TESTING-AND-ACCEPTANCE.md`: concise project-wide acceptance principles and release gates.
  - `docs/12-IMPLEMENTATION-STATUS-AND-CHANGELOG.md`: concise current implementation matrix, latest commit-bound CI evidence, and outstanding validation gates.
  - `docs/archive/11-TESTING-AND-ACCEPTANCE-HISTORY-2026-11-08.md` and `docs/archive/12-IMPLEMENTATION-CHANGELOG-HISTORY-2026-11-08.md`: preserved historical snapshots, not current status owners.
  - `docs/14-STAGE-8-NATIVE-DEVICE-ACCESS.md` and `docs/15-ARCH-INSTALLER-INITIAL-EXECUTION.md`: stage-specific design/implementation records, not competing architecture or status sources.
  - `docs/05-PLATFORM-SECURITY-AND-SOFTWARE.md`: canonical security, desktop, hardware/power/network, package, developer-tool, and authorized security-testing policies.
- Other documents may include a brief summary when useful, but must link to or name the owning document instead of duplicating its full requirements, decisions, or procedures. Keep indexes and cross-references concise.
- This map assigns ownership by subject; it is not a blanket rule that one document overrides every other document. Approved decisions in the requirements-and-decisions document constrain the architecture. Architecture and domain documents must remain consistent with them.
- If documents conflict, identify the exact conflicting statements and affected requirements. Do not silently choose one, invent a compromise, or propagate the conflict. Ask for clarification when resolving it would change scope, an approved decision, safety behavior, or an interface. For non-material editorial inconsistencies, make the smallest correction in the non-owning document and preserve the owning document's meaning.
- When a topic changes, update its owning document first, then update only affected summaries, status records, and cross-references. Before finishing, check for stale or duplicated statements in the documents affected by the change.

## Shell and test quality

- Use Bash for installer code unless another language has a documented, material advantage.
- Use safe shell practices, quote expansions appropriately, validate inputs, handle errors, and keep privileged operations minimal.
- Add or update tests alongside behavior changes where feasible. Do not claim tests ran unless they actually ran.
- Do not disable package verification or weaken safety controls to make a test pass.
- Keep documentation consistent with actual code and observed test results.

## Scope and reporting

- Do only the work requested for the current task; do not jump ahead into unrelated implementation.
- Do not merge pull requests, release changes, or perform other consequential repository actions unless explicitly authorized.
- Before reporting completion, check changed files and verification results. State what changed, what was verified, what was not tested, and any important risks.

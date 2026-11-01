# AI Development Instructions

## Purpose

These instructions govern AI-assisted work in this repository. The repository and its reviewed files are the source of truth; conversation history or model memory must not override them.

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
- Use the project status vocabulary consistently: `PLANNED`, `APPROVED`, `IMPLEMENTED`, `TESTED`, `VERIFIED`, and `RELEASED`.
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
- Prefer isolated tests, mocks, and disposable virtual machines for dangerous workflows. Clearly state what remains untested on real hardware.

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
  - `docs/03-ARCHITECTURE-AND-MODULES.md`: system architecture, module boundaries, and interfaces, consistent with approved requirements and decisions.
  - Domain documents: detailed procedures, contracts, implementation guidance, and testing criteria for their named domain.
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

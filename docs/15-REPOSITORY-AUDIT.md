# Repository-Wide Audit

## Audit record

- **Repository:** `K41-Origin/Lenovo-ThinkPad-X280-K41`
- **Branch:** `main`
- **Audit baseline commit:** `719f537341b6d410ce2980144fee86237da01b42`
- **Audit date:** 2026-11-03
- **Scope:** tracked repository tree, documentation structure and relative links, production Bash module boundaries, test layout, CI workflow, hardware profile, and implementation/status consistency.
- **Method:** GitHub tree/blob inspection and static content review. No local hardware inspection, installer execution, storage-device access, or destructive operation was performed.

This is an audit of the repository state at the baseline commit above. The audit-report commit itself is a later documentation-only change.

## Executive summary

The repository has a sound basic layout and a useful safety-first storage foundation. The main problem is **semantic duplication and documentation drift**, not duplicated files or an obviously disorganized directory tree.

The audit found:

- 51 tracked files; the recursive Git tree was complete (not truncated).
- No byte-identical tracked files (no repeated Git blob SHA).
- No duplicate function names among production Bash definitions inspected.
- No broken relative Markdown links in the 17 Markdown files checked.
- Eleven test scripts and one CI workflow.
- CI run #148 passed Bash syntax validation and all eleven tests at the audit baseline commit.
- No destructive storage, package-installation, or system-configuration command invocation was found in the current production Bash entry point/modules during static review. This is not a proof against every possible runtime side effect.

The strongest cleanup opportunity is to make each document and test fixture have one clear owner, then make indexes and CI call those canonical sources instead of repeating lists and explanations.

## Repository inventory

| Area | Files | Responsibility |
| --- | ---: | --- |
| Root guidance and entry point | 4 | `README.md`, `AGENTS.md`, `LICENSE`, `installer` |
| GitHub automation | 1 | Bash validation workflow |
| Hardware profile | 1 | Declarative X280 target profile |
| Documentation | 14 | Charter, requirements, architecture, domain guidance, testing, status, hardware baseline, Stage 8, audit |
| Production library | 19 | Bash modules and planned module placeholders |
| Tests | 12 | Eleven test scripts and their README |
| **Total** | **51** | |

The repository root is reasonably compact: `.github/`, `config/`, `docs/`, `lib/`, and `tests/`, plus the entry point and project metadata. No binary/build artifact directory was found in the tracked tree.

## What is already well structured

1. **Clear safety boundary:** `installer` sources only common/preflight modules. Installation and destructive storage behavior remain disabled.
2. **Useful module separation:** storage discovery, topology, planning, prerequisite collection, confirmation, dry-run manifest, and mock execution boundary have distinct files.
3. **Consistent production function namespace:** production functions use domain namespaces such as `inventory::`, `preflight::`, and `storage::`.
4. **Test isolation:** storage tests use fixture data and mock discovery/probe functions; topology tests use synthetic sysfs/mountinfo fixtures and temporary files.
5. **AI workflow guidance:** `AGENTS.md` establishes repository-first inspection, evidence-based status, documentation ownership, and verification after writes.
6. **Traceable CI:** workflow permissions are limited to `contents: read`, and the test job has a timeout.
7. **Stage 8 is explicitly design-only:** no native helper or real executor is implied by the new design document.

## Findings and recommended actions

### AUD-01 — High: storage and boot decisions are repeated across multiple owning documents

**Evidence**
- `docs/02-REQUIREMENTS-AND-DECISIONS.md` records approved storage and boot decisions.
- `docs/03-ARCHITECTURE-AND-MODULES.md` repeats a long, detailed approved storage/boot design.
- `docs/04-INSTALLATION-AND-DISK.md` also describes the approved layout, encryption, swap, and boot requirements.
- `AGENTS.md` already defines a document ownership map, but the current content does not consistently follow it.

**Risk:** an AI or developer may update one copy while leaving another stale, or incorrectly treat an architecture summary as a separate decision.

**Recommendation**
- Keep requirement IDs and concise approved decision statements in document 02.
- Keep module boundaries, interfaces, and high-level dependency flow in document 03.
- Make document 04 the single detailed owner for disk layout, encryption, boot, swap, hibernation, and recovery procedure.
- Replace repeated long descriptions with short summaries and links. Preserve all approved decisions; do not change architecture during editorial consolidation.

### AUD-02 — High: test acceptance criteria and test-result history overlap

**Evidence**
- `docs/11-TESTING-AND-ACCEPTANCE.md` contains acceptance criteria, stage test details, current status, and historical CI results.
- `docs/12-IMPLEMENTATION-STATUS-AND-CHANGELOG.md` repeats implementation status and many detailed test outcomes.

**Risk:** run numbers and status statements drift, making it difficult to determine which evidence is current.

**Recommendation**
- Document 11 owns test strategy, acceptance criteria, test mappings, and test limitations.
- Document 12 owns the concise current implementation matrix and chronological change history.
- Keep only the latest relevant CI evidence in the current status section; historical changelog entries should reference the test/run without duplicating full test descriptions.

### AUD-03 — High: changelog contained malformed literal newline escapes and a CI reference mismatch

**Evidence at audit baseline**
- Three changelog entries contained literal `\\n` sequences, causing multiple intended Markdown rows/headings/bullets to render as one line.
- The static-check status row associated run #140 with commit `3fcc970f58d76e5f62d6b76f767a4075cbe0a95b`. GitHub run #140 actually belongs to commit `30562c35a043f4fa10bf23d6153ba051b823350e`; the `3fcc...` commit was validated by run #136.
- The status/test README references had not advanced to the later successful run #148.

**Action recorded with this audit:** literal newline escapes were converted to real line breaks, and current CI references were updated to run #148 at baseline commit `719f537341b6d410ce2980144fee86237da01b42`.

### AUD-04 — Medium: test manifest is duplicated between CI and developer instructions

**Evidence**
- `.github/workflows/bash-tests.yml` hardcodes all eleven test paths.
- `tests/README.md` repeats the same list in its shell loop.
- There is no repository-owned test runner.

**Risk:** adding or renaming a test can update one list but not the other.

**Recommendation**
- Add `tests/run.sh` as the canonical ordered test manifest.
- Make CI run `bash tests/run.sh`.
- Make `tests/README.md` document that command rather than maintaining another list.
- Have the runner fail if an expected test is missing and report each test result.

### AUD-05 — Medium: storage test setup repeats similar mocks and target fixtures

**Evidence**
- `test-storage-prerequisites.sh`, `test-storage-confirmation.sh`, `test-storage-execution-dry-run.sh`, and `test-storage-execution-boundary.sh` each define similar preflight mocks, NVMe candidate records, target validation, and plan setup.
- The repeated fixture values include the same device path, major:minor, capacity, transport, stable identity, and model.

**Risk:** fixture definitions can diverge and make tests harder to maintain.

**Recommendation**
- Consider a small `tests/helpers/storage-fixtures.sh` for shared fixture construction and common mocks.
- Keep scenario-specific overrides in each test. Do not create a large generic testing framework or hide the behavior under test.

### AUD-06 — Medium: planned module placeholders can be mistaken for implemented features

**Evidence**
These files contain only a shebang and a short PLANNED comment, with no function definitions:
- `lib/base-system.sh`
- `lib/bootloader.sh`
- `lib/desktop.sh`
- `lib/hardware.sh`
- `lib/packages.sh`
- `lib/report.sh`
- `lib/security.sh`
- `lib/user-setup.sh`
- `lib/validation.sh`

The status matrix calls this a module skeleton, while README describes the library as focused internal modules.

**Risk:** file presence can be mistaken by an AI or developer as a working module or importable contract.

**Recommendation**
- Either keep them as explicitly named placeholders and label them consistently as PLANNED in README/status, or remove the empty files until the corresponding implementation stage begins.
- Do not remove them automatically: first check references and preserve the architecture decision. The current installer does not source them.

### AUD-07 — Medium: hardware profile contains duplicate or currently unused fields

**Evidence**
- `inventory::compare_target_profile` currently consumes only vendor, product name, Linux CPU model, and memory minimum/maximum fields.
- Other profile fields are not currently read by production code.
- The profile has identical values for `K41_TARGET_CPU_MODEL` / `K41_TARGET_CPU_MODEL_LINUX` and `K41_TARGET_PRODUCT_NAME` / `K41_TARGET_MACHINE_TYPE_MODEL`.
- `K41_TARGET_MEMORY_GIB` duplicates a representation derivable from the byte range; `K41_TARGET_PROFILE_ID` is not currently consumed.
- `docs/13-X280-HARDWARE-BASELINE.md` intentionally records owner-reported evidence, while the config is machine-readable operational data; those two roles should remain distinct.

**Risk:** values can become stale or inconsistent, and unused fields can be assumed to be validated when they are not.

**Recommendation**
- Define a small schema/consumer map for each profile key.
- Remove redundant aliases only after confirming no planned consumer needs the distinct semantic field.
- Keep source/evidence details in document 13 and runtime values in config; add a consistency check only if it can be deterministic and maintainable.

### AUD-08 — Medium: CI environment and quality checks are not fully declared

**Evidence**
- Workflow uses `ubuntu-latest` and `actions/checkout@v4` rather than a pinned runner image and immutable action SHA.
- ShellCheck and shfmt are not part of CI.
- `test-storage-discovery.sh` invokes `python3` and directly executes `/usr/bin/jq`; these test dependencies are not declared or installed by the workflow.
- The workflow and tests README have separate test manifests (AUD-04).

**Risk:** CI behavior can change with the hosted image/action tag, and test prerequisites are implicit.

**Recommendation**
- Declare/install required test dependencies explicitly.
- Add ShellCheck and shfmt after establishing project-wide rules and fixing existing findings.
- Consider pinning `ubuntu-24.04` and `actions/checkout` to a reviewed full commit SHA; document the update process.
- Keep workflow permissions minimal.

### AUD-09 — Medium: associative-array nameref validation is inconsistent

**Evidence**
- `storage::plan_gpt_layout` creates `local -n _plan=$1` before checking that the supplied variable name exists and refers to an associative array.
- Several other public functions validate `declare -p` before creating a nameref.
- Related helper functions should be checked for the same ordering.

**Risk:** invalid caller input may produce shell diagnostics or unexpected early failure, and the API contract is less predictable.

**Recommendation**
- Validate identifier syntax, declaration type, and mutability before creating namerefs.
- Add tests for malformed variable names, missing variables, indexed arrays, and readonly associative arrays.
- Apply one small helper/pattern consistently rather than duplicating slightly different validation logic.

### AUD-10 — Low: status vocabulary omits a frequently used state

**Evidence**
- `docs/01-PROJECT-CHARTER.md` and `AGENTS.md` define PLANNED, APPROVED, IMPLEMENTED, TESTED, VERIFIED, and RELEASED.
- The repository also uses `NOT TESTED` extensively, including hardware and hibernation status.

**Recommendation**
- Add an explicit `NOT TESTED` definition and state when it is required.
- Keep the distinction between IMPLEMENTED, TESTED, VERIFIED, and RELEASED.

## Duplication assessment

| Area | Result | Interpretation |
| --- | --- | --- |
| Byte-identical tracked files | None found | No exact file-copy duplication in the Git tree. |
| Production function names | No duplicates found | Current production namespaces and function names are distinct. |
| Relative Markdown links | No broken links found in 17 reviewed Markdown files | Existing internal navigation is intact at the audit baseline. |
| Storage/boot prose | Significant overlap | Highest-value documentation consolidation. |
| CI test manifest | Repeated in two places | Replace with one test runner. |
| Storage fixture setup | Repeated across several tests | Extract only common fixture construction. |
| Hardware profile values | Some duplicate/unused fields | Define ownership and consumers before removal. |
| Planned module placeholders | Nine files without functions | Clarify planned status or remove later with reference checks. |

## Recommended cleanup sequence

Do the cleanup in small reviewable commits, without changing approved installation behavior:

1. **Documentation ownership pass:** consolidate storage/boot detail into document 04; make documents 02 and 03 concise; separate acceptance criteria from historical test evidence.
2. **Status accuracy pass:** define NOT TESTED, retain one current CI reference, and keep changelog entries valid Markdown.
3. **Test-runner pass:** introduce `tests/run.sh`; make CI and test documentation call it; declare `jq` and `python3` dependencies.
4. **Fixture pass:** extract only repeated storage fixture builders and preserve independent scenario tests.
5. **Placeholder/profile pass:** clarify the nine PLANNED modules and define profile-key consumers before removing or renaming anything.
6. **Code-quality pass:** standardize nameref validation; then add ShellCheck/shfmt with explicit configuration and resolve findings.
7. **CI hardening pass:** pin runner/action versions after the workflow has stable, passing checks.

After each pass, fetch the changed files, inspect the diff, run the complete test runner, and verify the resulting GitHub Actions run. Do not combine documentation restructuring with storage behavior changes.

## Explicit non-findings and limits

- No exact duplicate tracked file was identified.
- No duplicate production function name was identified in the inspected production Bash definitions.
- No broken relative Markdown link was identified in the 17 Markdown files checked.
- No destructive disk operation or actual installation was executed or validated.
- No ShellCheck/shfmt run was performed; those tools are not currently in CI.
- No test suite was executed locally during this audit. CI run #148 is the available test evidence for the baseline commit.
- No physical ThinkPad X280 hardware, actual SSD, UEFI boot, LUKS, filesystem, suspend, or hibernation behavior was tested.
- This audit does not authorize deletion of placeholder files, changes to approved storage layout, or activation of destructive execution.


## Cleanup execution follow-up — 2026-11-03

The following changes are being prepared on `maintenance/repository-cleanup` in pull request #3. This section records implementation scope, not a claim that the branch has passed CI or been merged.

| Audit item | Action taken on the cleanup branch | State |
| --- | --- | --- |
| AUD-01 — documentation ownership | Document 04 is the detailed storage/boot owner; document 02 retains concise requirement IDs and approved decisions; document 03 links to the owner instead of repeating the design. | IMPLEMENTED; CI pending |
| AUD-02 — test strategy vs history | Document 11 now owns strategy, coverage, acceptance, and limitations; the historical CI ledger remains in document 12. | IMPLEMENTED; CI pending |
| AUD-03 / AUD-10 — changelog and status vocabulary | Added the canonical `NOT TESTED` definition to document 01 and made AGENTS.md refer to it. Existing historical run mapping is retained. | IMPLEMENTED; CI pending |
| AUD-04 — test manifest | Added `tests/run.sh`; CI and `tests/README.md` invoke it. The runner checks `bash`, `jq`, and `python3`, and fails if a required script is missing. | IMPLEMENTED; CI pending |
| AUD-05 — repeated fixtures | Added a small shared associative-array target fixture builder and reused it in five storage tests. Discovery/probe mocks remain scenario-specific; no generic mock framework was introduced. | PARTIALLY IMPLEMENTED; further extraction only if repetition remains material |
| AUD-06 — placeholder modules | Kept all nine files to preserve repository structure and references; README, architecture, and status now label them PLANNED and state they contain no installation implementation. | IMPLEMENTED; no files deleted |
| AUD-07 — hardware profile | Removed duplicate CPU/product aliases and the redundant GiB memory alias. Documented the five keys currently consumed by `inventory.sh`; remaining owner-reported fields are reference metadata and are not runtime-validated. | IMPLEMENTED; CI pending |
| AUD-08 — CI reproducibility and lint | Pinned the runner to `ubuntu-24.04`, pinned checkout to an immutable v4.2.2 commit, and explicitly installs jq/python3/ShellCheck/shfmt. ShellCheck checks the full Bash tree at error severity; shfmt currently checks the new test infrastructure only, pending a deliberate project-wide formatting baseline. | PARTIALLY IMPLEMENTED; branch CI pending |
| AUD-09 — nameref validation | Added shared associative-array name/type validation before planner nameref creation; mutating output APIs reject readonly arrays. Added malformed, missing, indexed, and readonly-array tests. | IMPLEMENTED; CI pending |

No placeholder module was deleted. No approved storage decision or installer behavior was changed. No real disk, package database, service, firmware setting, or ThinkPad hardware was accessed or modified.

## Audit conclusion

The repository does not need a broad directory reshuffle. Keep the existing top-level structure and improve **single ownership of information, one canonical test entry point, explicit planned-vs-implemented status, and reproducible CI**. This will reduce AI ambiguity and developer onboarding cost without changing the project's technical direction.

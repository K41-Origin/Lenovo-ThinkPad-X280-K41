#!/usr/bin/env bash
# Storage module contract — PLANNED; no executable storage behavior is implemented.
#
# Requirement links:
#   REQ-INSTALL-005 — global gate before installation work proceeds.
#   REQ-DISK-002    — storage/encryption/swap/resume design constraints.
#   REQ-DISK-003    — target identity, full plan, confirmation, and destructive-operation gate.
#   REQ-DISK-006    — unresolved bootloader/resume compatibility blocks destructive work.
#   REQ-RECOVERY-001 — inspect actual state after interruption; never auto-wipe on restart.
# Test mapping: docs/11-TESTING-AND-ACCEPTANCE.md (TC-DISK-003-01..08,
# TC-RECOVERY-001-01).
#
# Ownership and safety:
# - This is the only module allowed to own partitioning/formatting operations.
# - No function may run destructive tools until storage design is approved,
#   prerequisites pass, a complete plan is displayed, target identity is
#   revalidated, and explicit confirmation for that exact target/plan is received.
# - Missing/ambiguous identity, incomplete plan, changed target, failed
#   prerequisite, cancellation, or unknown critical state must fail closed.
# - Keep discovery, planning, display, validation, confirmation, execution,
#   and post-operation verification as separate testable stages.
# - Automated tests must mock/fake destructive tools and assert zero calls on
#   every abort path. Never test this module against a real disk.
#
# Data model — design contract, not implemented:
# - Public functions accept names of caller-declared Bash associative arrays
#   and use validated namerefs; do not use eval or execute serialized data.
# - Candidate identity fields: device_path (current locator only), device_type,
#   size_bytes, model, transport, and available stable identifiers such as
#   WWN or device serial. Missing stable identifiers remain missing; a path
#   alone must never resolve an otherwise ambiguous physical target.
# - Keep raw identifiers available for comparison, but do not log or expose
#   full serials by default. Render only the minimum identifying detail needed
#   for the user to distinguish the target safely.
# - A plan is a validated associative-array record with an explicit schema
#   version and fields for target identity snapshot, boot mode, partition table,
#   ordered partition definitions, encryption, filesystems, mount points,
#   swapfile/resume design, prerequisite evidence, and unresolved decisions.
# - Plan records contain no passphrases, recovery keys, credentials, or shell
#   fragments. Never source a plan file or interpret plan values as commands.
# - Confirmation binds the reviewed target identity and canonical plan digest.
#   Any change to target identity, plan contents, schema, or required evidence
#   invalidates the confirmation. Digest construction and serialization must
#   be deterministic and safely testable before implementation.
#
# Planned public stage interface (names/signatures are design proposals):
#
#   storage::discover_candidates <output_assoc_array_name>
#     Read-only block-device discovery. Return candidate records with stable
#     identity evidence; no writes, mounts, partition-table reads that mutate,
#     or selection based only on enumeration order.
#
#   storage::build_plan <target_assoc_array_name> <profile_assoc_array_name> <output_plan_assoc_array_name>
#     Validate target/profile schemas and required resolved decisions, then
#     build a complete plan. Return failure if any critical input is unknown.
#
#   storage::render_plan <plan_assoc_array_name>
#     Display target identification and every proposed partition, encryption,
#     filesystem, mount, swap, and resume choice. No mutation.
#
#   storage::validate_target <target_assoc_array_name> <plan_assoc_array_name>
#     Re-discover the selected device and compare all available identity
#     evidence and relevant capacity/type attributes against the plan snapshot.
#     A changed path may be accepted only if stable identity proves it is the
#     same device; a path match alone is insufficient.
#
#   storage::confirm_plan <target_assoc_array_name> <plan_assoc_array_name> <output_confirmation>
#     Interactively obtain explicit final confirmation after rendering. The
#     confirmation result binds target identity and canonical plan digest.
#     Cancellation returns status 10; no destructive command is invoked.
#
#   storage::execute_plan <target_assoc_array_name> <plan_assoc_array_name> <confirmation>
#     Sole stage permitted to invoke destructive storage tools. Revalidate
#     target, plan completeness/digest, prerequisites, boot/resume design,
#     and confirmation immediately before the first destructive command.
#     Never infer confirmation from environment variables or stale files.
#
#   storage::verify_result <plan_assoc_array_name>
#     Read-only verification of resulting partition, encryption, filesystem,
#     mount, and swap/resume state. Report observed facts, not assumptions.
#
# Status convention — proposed and aligned with the orchestration contract:
#   0  stage succeeded
#   1  operational/critical failure
#   2  invalid arguments or invalid data schema
#   10 user cancellation or deliberate safe stop (never success)
# Only status 0 permits the caller to advance.
#
# Privilege and recovery boundaries:
# - Discovery/planning/rendering/validation should be read-only and need no
#   elevated privilege unless verified implementation evidence proves otherwise.
# - Elevate only the narrow execution operation that requires it; do not run
#   the entire installer as root merely for convenience.
# - If execution is interrupted or partially fails, stop. A later run must
#   inspect actual on-disk state and require a newly reviewed plan; never
#   automatically repeat partitioning/formatting.
# - Do not place secrets in arguments, environment variables, plan records,
#   logs, traces, reports, or test fixtures.
#
# No real storage command or executable storage function is implemented here.

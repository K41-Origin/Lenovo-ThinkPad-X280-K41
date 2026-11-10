# Root scripts compatibility and shared utilities

Stage-owned scripts are canonical inside their owning stage:

- Stage 3: `stages/stage-3-desktop-install/scripts/`
- Stage 5: `stages/stage-5-desktop-customization/scripts/`

The corresponding root-level `scripts/<name>` entries are relative symlinks retained for backward-compatible command paths. New documentation and automation should use the Stage-owned path.

Hardware/power audit tools and cross-stage utilities remain at the root until their ownership and call graph are established. Do not move a script solely because its filename contains a device or component name; inspect callers, path assumptions, and deployment behavior first.

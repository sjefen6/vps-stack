# Agent Notes

## Line endings

- Keep Linux scripts LF-only and UTF-8 without BOM, including files used in local Docker builds.
- Follow `.editorconfig` and `.gitattributes`. Add explicit LF attributes for new extensionless scripts.

## Design principles

- Fail clearly when required operator configuration is missing or empty; use `${VAR:?error_message}` for required Compose variables. Distinguish required settings from intentional defaults supplied by the image.
- Keep initialization scripts focused on automated startup rather than mixing in manual maintenance tasks.

## Container conventions

- Bake operational scripts into their service image.
- Follow existing service patterns before introducing alternatives.
- Prefer small fixes. Avoid duplicate files, fallback paths, or extra validation when normal initialization directly establishes the state.
- Use temporary, isolated containers for focused verification. Keep test scripts only when their ongoing value justifies maintenance.

## Investigating bugs

- Investigate the cause before proposing or implementing a fix. Inspect relevant logs, configuration, runtime state, and Git history; reproduce the failure where practical.
- Distinguish observed symptoms, confirmed causes, and hypotheses. For containers, compare configured state with actual runtime state rather than relying on configuration alone.
- If the root cause remains unknown, acknowledge that explicitly. Explain what was verified, what remains unexplained, and whether the change is a mitigation or a confirmed root-cause fix. A passing test or disappearance of a symptom does not explain the original failure.

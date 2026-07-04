---
description: Run the Semantic Regeneration Pipeline to regenerate downstream database design artifacts in sequence when an upstream artifact is updated.
---

Command: regenerate-from

Description:
Run the `db-design-pipeline:semantic-regeneration-pipeline` skill to sequentially regenerate all downstream artifacts from a given upstream step. Previous artifacts are read from the `--from-run` directory as knowledge sources, while the updated upstream artifact in the `--to-run` directory serves as the single source of truth.

Usage:
```bash
regenerate-from --from <Step> --from-run <old_run> --to-run <new_run> [--group G05]
```

Arguments:
  --from <Step>          The step containing the updated upstream artifact.
                         Valid values: BusinessReq, ERD, LogicalSchema, Validation, DDL, SeedData.
  --from-run <old_run>   The directory name (under outputs/run/) containing the previous run's artifacts.
  --to-run <new_run>     The directory name (under outputs/run/) where the regenerated artifacts will be written.
  --group <Group>        The group code (default: G05).

Prompt:
  Run the Semantic Regeneration Pipeline starting after step: {{from}}.
  - Source run: outputs/run/{{from-run}}/ (or {{from-run}} if absolute path)
  - Target run: outputs/run/{{to-run}}/ (or {{to-run}} if absolute path)
  - Group: {{group}}

  Read the skill defined in `.opencode/skills/db-design-pipeline/08-semantic-regeneration/SKILL.md`.
  
  Determine the downstream steps to execute in sequence:
  - If --from is BusinessReq (Task 01): execute Task 02, 03, 04, 05, 06, 07
  - If --from is ERD (Task 02): execute Task 03, 04, 05, 06, 07
  - If --from is LogicalSchema (Task 03): execute Task 04, 05, 06, 07
  - If --from is Validation (Task 04): execute Task 05, 06, 07
  - If --from is DDL (Task 05): execute Task 06, 07
  - If --from is SeedData (Task 06): execute Task 07

  For each task, execute the Semantic Regeneration Workflow step-by-step:
  1. Load the task's corresponding skill file (e.g., .opencode/skills/db-design-pipeline/<NN>-<task-name>/SKILL.md).
  2. Read the old artifact from outputs/run/{{from-run}}/ to extract design rationale, naming conventions, and constraints.
  3. Load the updated upstream artifact from outputs/run/{{to-run}}/ as the single source of truth.
  4. Compare old upstream vs new upstream to map alterations.
  5. Regenerate the downstream artifact completely from scratch into outputs/run/{{to-run}}/, ensuring it preserves the design intent and complies with all rules in its task skill.
  6. Overwrite the file in outputs/run/{{to-run}}/.

Notes:
  - Do not patch or edit old files. Completely overwrite them.
  - The updated upstream artifact must already exist in outputs/run/{{to-run}}/.

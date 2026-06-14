Command: generate-erd

Description:
Run the `.opencode/skills/db-design-pipeline/02-erd` skill to generate a Mermaid.js ERD
from `docs/entity-registry.md` and `outputs/01-business-req-analysis-G05.md`.

Usage:
```
generate-erd --group G05
# or
generate-erd docs/entity-registry.md --group G05
```

Prompt:
  Generate the ERD for the Campus Space Management System, group G05.

  Input:  `docs/entity-registry.md`
  Output: `outputs/02-erd-design-G{{group}}.md`

Notes:
  - Use `--group G05` as the default group.
  - This command file defines the invocation interface only; the skill contains the task behavior.
  - Overwrite output file if it already exists.
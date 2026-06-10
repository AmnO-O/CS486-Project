Command: generate-business-req

Description:
Run the `db-design-pipeline:01-business-req-analysis` skill to generate `outputs/01-business-req-analysis-G05.md` from all requirement files under `req/`.

Usage:
```
generate-business-req --group G05
# or
generate-business-req req/ --group G05
```

Implementation example (shell):
```bash
#!/usr/bin/env bash
set -euo pipefail
REQ_PATH=${1:-req}
GROUP=${2:-G05}

if [ ! -e "$REQ_PATH" ]; then
  echo "Requirement path not found: $REQ_PATH" >&2
  exit 1
fi

# Replace this with the actual runtime invocation for your project.
# Example:
# opencode run-skill db-design-pipeline --task 01-business-req-analysis --input "$REQ_PATH" --group "$GROUP"

echo "(stub) Would run db-design-pipeline:01-business-req-analysis on $REQ_PATH -> outputs/01-business-req-analysis-$GROUP.md"
```

Notes:
- Use `--group G05` as the default group for exercise 1 output.
- If a directory is provided, the runtime should read all requirement files under that directory.

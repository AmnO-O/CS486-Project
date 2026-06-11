Command: outputs-evaluation

Description:
Run a critique loop on the current task output by comparing the existing output file with the newly drafted output, then write an evaluation log to `/logs/`.

Usage:
```bash
outputs-evaluation --task 01 --agent reviewer-1
# or
outputs-evaluation --task 01 --agent reviewer-1 --output outputs/01-business-req-analysis-draft.md
```

Implementation example (shell):

```bash
#!/usr/bin/env bash
set -euo pipefail

TASK_ID=${1:-01}
AGENT_NAME=${2:-reviewer-1}
DATE=$(date +%Y-%m-%d)

case "$TASK_ID" in
  01) TASK="01-business-req-analysis" ;;
  02) TASK="02-technical-design" ;;
  *)
    echo "Unknown task id: $TASK_ID" >&2
    exit 1
    ;;
esac

OUTPUT=${3:-outputs/${TASK}-draft.md}

LOG_DIR="logs"
mkdir -p "$LOG_DIR"

if [ ! -e "$OUTPUT" ]; then
  echo "Output file not found: $OUTPUT" >&2
  exit 1
fi

LOG_FILE="$LOG_DIR/${DATE}-${TASK}-${AGENT_NAME}-evaluation.log"

# Replace this with the actual runtime invocation for your project.
# Example:
# opencode run-skill db-design-pipeline \
#   --task "$TASK" \
#   --mode outputs-evaluation \
#   --agent "$AGENT_NAME" \
#   --output "$OUTPUT" \
#   --date "$DATE" \
#   --log "$LOG_FILE"

echo "(stub) Would run outputs-evaluation on task=$TASK agent=$AGENT_NAME date=$DATE using baseline=$OUTPUT -> $LOG_FILE"
```

Examples:

```bash
outputs-evaluation --task 01 --agent reviewer-1
```

* Uses task `01` as shorthand for `01-business-req-analysis`.
* Uses the default draft output file: `outputs/01-business-req-analysis-draft.md`.
* Writes the evaluation log to `/logs/`.

```bash
outputs-evaluation --task 01 --agent reviewer-1 --output outputs/01-business-req-analysis-draft.md
```

* Uses the specified draft file as the baseline.
* Runs the critique loop against the new drafted output.
* Saves the evaluation log with date and agent name in `/logs/`.

```bash
outputs-evaluation --task 02 --agent reviewer-2 --output outputs/02-technical-design-review.md
```

* Evaluates task `02`.
* Uses a review version file as input.
* Writes the log with the agent name in `/logs/`.


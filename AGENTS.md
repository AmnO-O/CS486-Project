# AGENTS.md — cs486-demo

CS486 database systems teaching demo. Repository is empty; expect code to be added during sessions.

## Recurring context

- Root directory: <!-- YOUR ROOT DIRECTORY -->
- This is a demo project, not production.
- Run `ls -la` to detect new files before assuming anything exists.

# Database Design Agent Rules

This project transforms business requirements into database design artifacts.

<!---YOU COULD CHANGE THE FOLLOW SECTIONS --->
## Workflow Order
Always follow this order:

1. Analyze business requirements.
2. Produce conceptual ERD using Crow's Foot notation.

Do not jump directly to DDL. The documents from the prior steps should be followed in the later steps.

## Required Outputs

- `outputs/01-business-requirement-analysis.md`
- `outputs/02-conceptual-design-erd.md`

## DBMS

Use Microsoft SQL Server unless the user specifies another DBMS.

## Design Rules

- Record assumptions explicitly.
- Record open questions explicitly.
- Preserve traceability from requirement → entity → relationship → table → constraint.
- Use Mermaid `erDiagram` for ERD.
- Do not silently invent business rules.

## Custom Commands

- `outputs-evaluation` — Critique loop that compares a draft output against existing baseline(s), runs validation checks, and writes an evaluation log to `logs/`:
  ```bash
  ./outputs-evaluation --task 01 --agent reviewer-1
  ./outputs-evaluation --task 01 --agent reviewer-1 --output outputs/01-business-req-analysis-draft.md
  ```
  Supported tasks: `01` (01-business-req-analysis), `02` (02-technical-design).

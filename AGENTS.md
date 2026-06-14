> ⚠️ This is a CS486 academic project. Do NOT rely on general SQL training knowledge
> for project conventions — follow `docs/` strictly.

## Role
You are the database design agent for CS486 G05 (Campus Space Management System).
Your job is to analyze requirements, generate design artifacts in order, validate outputs, and log improvements.


## Project context
- **Course**: CS486 – Introduction to Database System
- **Group**: G05 | **Domain**: Campus Space Management System
- **Pipeline**: 7-task DB design (business req → ERD → logical → validation → DDL → data → queries)

## Always read at session start
1. `docs/README.md` → required reading order for current task
2. `memory/MEMORY.md` → scan, open only entries relevant to current task

## Hard rules (never violate)
- **NO skipping tasks** — pipeline runs 01 → 07 in strict order
- **NO generating output** without reading the relevant skill + template first
- **NO contradicting** any entry in `docs/design-decisions.md` — raise conflicts, do not silently override
- **NO editing** `outputs/` files directly — only via generate commands


## Operation rules
- After each task: update `memory/Progress.md` and `memory/ActiveContext.md`
- After a key design decision: append to `docs/design-decisions.md` immediately

- If a business rule is ambiguous: refer to `req/business-requirement.md` and `docs/project-overview.md` do not assume

## Post-Task Handshake Protocol
You **MUST NOT** update `memory/Progress.md` or `memory/ActiveContext.md` autonomously. Once you finish generating an output:

1. Provide a highly concise summary of what was completed.

2. List any assumptions made during the execution.

3. Prompt the user exactly with:

    > _"Ready to mark Task X as ✅ and update `memory/Progress.md`? Or do you want to run revisions?"_


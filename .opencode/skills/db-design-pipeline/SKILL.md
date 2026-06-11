---
name: db-design-pipeline
description: Analyze business requirements and produce conceptual ERD, logical database design, and DDL documents step by step.
compatibility: opencode
---

# Database Design Pipeline Skill

Use this skill when the user asks to transform business requirements into a database design.

## Important behavior

Before assuming anything, inspect the project:

1. Run `ls -la`.
2. Read `AGENTS.md` first.
3. Read `README.md` to understand extended project outputs.
4. Locate requirement files under `req/`, `outputs/`, or files passed by the user.
5. Read the relevant requirement files fully before designing.
6. If the requirement is incomplete, continue with explicit assumptions, but also create an unresolved questions section.
7. Do not read unrelated files, `.git/`, temporary files.
8. Do not regenerate all files if the user asks for only one file or section

## Context Engineering

1. Research first, plan second, implement third, verify fourth.
2. If context becomes large, summarize decisions instead of loading more files.
3. Read only upstream artifacts required by the current step.
4. Do not read old outputs by default. Read old outputs only when:
   - the user asks to revise or continue from a previous version;
   - the current step depends on an approved upstream artifact;
   - the output is marked as the latest approved version;
   - the task is evaluation, comparison, or improvement logging.

## Required output files

Create or update the following files:

1. `outputs/01-business-req-analysis-G05.md`

Do not skip any Markdown file.

---

# Step 1: Business Requirement Analysis

Save to:

`outputs/01-business-req-analysis-G05.md`

For step 1, consult the sub-skill at `./01-business-req-analysis/SKILL.md` before generating the document. That sub-skill defines the exact behavior, expected sections, and validation checks for the business requirement analysis stage.

The document must include at least the following sections:

- Purpose
- Actors
- Entities and attributes
- Relationships and cardinalities
- Business rules
- Assumptions
- Open questions
- Suggested table mapping

Do not proceed to later steps until the step 1 output is complete and internally consistent.

## Step 1 behavior

1. Read the input requirement file completely.
2. Apply the step 1 sub-skill guidance from `./01-business-req-analysis/SKILL.md`.
3. Extract actors, candidate entities, attributes, relationships, and business rules.
4. Record any assumptions and open questions explicitly.
5. Generate `outputs/01-business-req-analysis-G05.md` as a standalone, reviewer-friendly analysis.

---

# General guidance

- Treat the pipeline as sequential: Step 1 must be complete before Step 2.
- Keep the output files concise, structured, and easy for a reviewer to validate.
- If additional steps are needed later, add sub-skill references for each new step.

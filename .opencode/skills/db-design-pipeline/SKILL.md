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
2. Locate requirement files under `req/`, `docs/`, or files passed by the user.
3. Read the relevant requirement files fully before designing.
4. If the requirement is incomplete, continue with explicit assumptions, but also create an unresolved questions section.

## Required output files

Create or update the following files:

1. `outputs/01-business-requirement-analysis.md`
2. `outputs/02-conceptual-design-erd.md`

Do not skip any Markdown file.

---

# Step 1: Business Requirement Analysis

Save to:

`outputs/01-business-requirement-analysis.md`

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
5. Generate `docs/01-business-requirement-analysis.md` as a standalone, reviewer-friendly analysis.

---

# Step 2: Conceptual Design / ERD

The ERD should be based on the verified output from Step 1.

Save to:

`docs/02-conceptual-design-erd.md`

The document must include:

- Conceptual entities and relationships
- Cardinalities and participation
- Primary keys and natural keys
- Notes on optionality and business constraints
- A Mermaid ERD diagram or equivalent conceptual model

## Step 2 behavior

1. Use the entities, relationships, and rules identified in Step 1.
2. Avoid inventing unrelated entities or constraints not supported by the requirement.
3. Clarify any gaps with assumptions if required, and do not hide them.
4. Produce a clear conceptual model that can be reviewed before logical design.

---

# General guidance

- Treat the pipeline as sequential: Step 1 must be complete before Step 2.
- Keep the output files concise, structured, and easy for a reviewer to validate.
- If additional steps are needed later, add sub-skill references for each new step.

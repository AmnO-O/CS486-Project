# Database Design Agent Project

This project requires each group to build and improve an AI agent that reads a business requirement and generates database design artifacts from requirement analysis to SQL query design.

## 1. Install OpenCode

OpenCode installation guide: [https://opencode.ai/docs/](https://opencode.ai/docs/)

After installation, open the project folder and start OpenCode:

```bash
cd path/to/your/project
opencode
```

During setup, choose the LLM provider and model that your group will use.

> Do not commit API keys, access tokens, or private credentials to Git.

---

### Connect OpenCode to an LLM Model

After installing OpenCode, each group must connect OpenCode to at least one LLM provider before running the database design agent.

OpenCode provider guide: [https://opencode.ai/docs/providers/](https://opencode.ai/docs/providers/)  
OpenCode model guide: [https://opencode.ai/docs/models/](https://opencode.ai/docs/models/)

#### Step 1: Start OpenCode

Open the project folder in the terminal:

```bash
cd path/to/your/project
opencode
```

#### Step 2: Connect an LLM Provider

Inside OpenCode, run:

```text
/connect
```

Then select the LLM provider that your group wants to use, such as OpenAI, Anthropic, Gemini, OpenRouter, OpenCode Zen, or another supported provider.

When requested, enter the API key or login information for the selected provider.

> Do not commit API keys, access tokens, or private credentials to Git.

#### Step 3: Select an LLM Model

After connecting the provider, run:

```text
/models
```

Choose the model that your group wants to use for the project.

## 2. Project Goal

The agent must read the business requirement and generate the following database design artifacts:

1. Business Requirement Analysis
2. Conceptual Database Design
3. Logical Database Design
4. Database Design Validation
5. Database Implementation
6. Sample Data Preparation
7. Query Design

The group must also evaluate and improve the agent during the development process.

---

## 3. Project Structure

```text
.
├── .opencode/                          # OpenCode agent configuration
│   ├── commands/                        # Custom commands (design-db, evaluate, per-task)
│   ├── skills/
│       ├── db-design-pipeline/          # 7-task pipeline skills + templates
│       │   ├── SKILL.md
│       │   ├── 01-business-req-analysis/SKILL.md
│       │   ├── 02-erd/SKILL.md
│       │   ├── 03-logical-design/SKILL.md
│       │   ├── 04-design-validation/SKILL.md
│       │   ├── 05-generate-ddl/SKILL.md
│       │   ├── 06-sample-data/          # SKILL.md + references/
│       │   └── 07-generate-query/SKILL.md
│       └── evaluations/                 # Rubrics, metrics, trajectory recording
│ 
│   
├── req/
│   └── business-requirement.md          # Input business requirement
├── outputs/                             # All 7 generated artifacts (G05)
├── docs/                                # Design documentation
│   ├── project-overview.md              # Domain, user roles, problem scope
│   ├── entity-registry.md               # Entities, attributes, relationships (single source of truth)
│   ├── schema-registry.md               # Normalized tables, FK wiring, indexes
│   ├── tech-stack.md                    # MSSQL, naming conventions, data types
│   ├── design-decisions.md              # Rationale & trade-offs for every key decision
│   └── templates/                       # Templates for entity-registry and schema-registry
├── memory/                              # Agent memory & progress tracking
│   ├── MEMORY.md
│   ├── ActiveContext.md
│   └── Progress.md
├── AGENTS.md
├── README.md
└── .gitignore
```

---

## 4. Main Files and Folders

| File / Folder | Purpose |
|---|---|
| `.opencode/commands/` | Custom commands: `design-db.md` (full pipeline), per-task commands (`01`-`07`), `evaluate-task.md`. |
| `.opencode/skills/db-design-pipeline/` | 7-task pipeline skills with per-task SKILL.md files and reference docs. |
| `.opencode/skills/evaluations/` | Rubrics, agent-metrics rubric, trajectory recording for agent evaluation. |
| `req/business-requirement.md` | Contains the input business requirement. |
| `outputs/` | Stores all 7 generated project artifacts (G05). |
| `docs/` | Design documentation: project-overview, entity-registry, schema-registry, tech-stack, design-decisions, templates. |
| `memory/` | Agent memory: session log, active context, progress tracker. |
| `AGENTS.md` | Contains project-level instructions and role definition for the agent. |
| `README.md` | Explains how to install, run, and evaluate the project. |
| `.gitignore` | Excludes private or unnecessary files from Git. |

---

## 5. How to Run the Agent

Open the project folder:

```bash
cd path/to/your/project
opencode
```

Run the custom command:

```text
/design-db req/business-requirement.md
```

If your group uses a different command name, update this README with the correct command.

---

## 6. Required Output Artifacts

The `outputs/` folder contains the following files (example for Group 05):

```text
01-business-req-analysis-G05.md
02-erd-design-G05.md
03-logical-design-G05.md
04-design-validation-G05.md
05-db-definition-G05.sql
06-sample-data-G05.sql
07-query-design-G05.sql
```


## 7. Notes on LLM Model Usage and Cost Control

Using LLM models may consume tokens and API credits. To avoid unnecessary cost:

- Use a cheaper or faster model for early drafts.
- Use a stronger model only for difficult reasoning, validation, and final review.
- Do not repeatedly regenerate all files from scratch.
- Ask the agent to update only the specific file or section that needs improvement.
- Keep prompts short, clear, and specific.
- Avoid sending unnecessary files such as `node_modules/`, `.git/`, logs, or large temporary files.
- Stop the agent if it loops or repeatedly produces similar outputs.
- Never commit API keys or tokens to Git.

Good prompt example:

```text
Read req/business-requirement.md and generate only outputs/01-business-req-analysis-G01.md.
```

Better than:

```text
Read the whole project and redo everything.
```

Another good prompt example:

```text
Use outputs/02-erd-design-G01.md to generate only outputs/03-logical-design-G01.md. Do not modify other files.
```

---

## 8. Academic Integrity

Students may use AI tools to support the project, but they are responsible for reviewing, evaluating, and improving the generated outputs.

Do not submit raw AI output without understanding or validation.

Each group must be able to explain:

- How the agent was configured.
- How the agent was improved.
- Why the final database design is valid.
- How the SQL scripts and queries work.
CS486-Project/
├── README.md                             # Setup, run guide, required outputs
├── AGENTS.md                             # Agent rules and workflow constraints
├── .gitignore                            # Ignored local/temp files
├── CS486_Project.pdf                     # Original assignment brief
├── improvement_logs.md                   # Agent improvement notes
├── structure.md                          # Project structure draft
│
├── req/                                  # Source requirements
│   └── business-requirement.md           # Main business requirements
│
├── docs/                                 # Project knowledge base
│   ├── README.md                         # Docs index and reading order
│   ├── project-overview.md               # Domain summary
│   ├── tech-stack.md                     # SQL Server and naming rules
│   ├── entity-registry.md                # Conceptual entities and relationships
│   ├── schema-registry.md                # Relational schema source of truth
│   └── design-decisions.md               # Design rationale and assumptions
│
├── memory/                               # Agent session state
│   ├── MEMORY.md                         # Memory index
│   ├── ActiveContext.md                  # Current task and next steps
│   └── Progress.md                       # Pipeline status and open issues
│
├── outputs/                              # Final deliverables
│   ├── 01-business-req-analysis-G05.md   # Requirement analysis
│   ├── 02-erd-design-G05.md              # Conceptual ERD
│   ├── 03-logical-design-G05.md          # Logical schema
│   ├── 04-design-validation-G05.md       # Schema validation
│   ├── 05-db-definition-G05.sql          # T-SQL DDL
│   ├── 06-sample-data-G05.sql            # Sample data
│   └── 07-query-design-G05.sql           # [Future] Business queries
│
├── logs/                                 # Agent execution and evaluation logs
│   ├── trajectory/                       # Task execution traces
│   │   ├── task01/                       # Task 01 trace
│   │   ├── task02/                       # Task 02 trace
│   │   ├── task03/                       # Task 03 trace
│   │   ├── task04/                       # Task 04 trace
│   │   ├── task05/                       # Task 05 trace
│   │   ├── task06/                       # Task 06 trace
│   │   └── task07/                       # [Future] Task 07 trace
│   │
│   ├── execution/                        # Execution run outputs
│   │   └── task06/                       # Task 06 execution output
│   │
│   ├── eval/                             # Output evaluation logs
│   │   ├── task01/                       # Task 01 evaluation
│   │   ├── task02/                       # Task 02 evaluation
│   │   ├── task03/                       # Task 03 evaluation
│   │   ├── task04/                       # Task 04 evaluation
│   │   ├── task05/                       # Task 05 evaluation
│   │   ├── task06/                       # Task 06 evaluation
│   │   ├── task07/                       # [Future] Task 07 evaluation
│   │   └── pipeline/                     # [Future] Pipeline evaluation
│   │
│   └── registry-snapshots/               # Registry snapshots per task
│
└── .opencode/                            # OpenCode agent configuration
    ├── commands/                         # Slash commands
    │   ├── design-db.md                  # Run full pipeline
    │   ├── 01-generate-business-req.md   # Generate Task 01
    │   ├── 02-generate-erd.md            # Generate Task 02
    │   ├── 03-generate-logical-design.md # Generate Task 03
    │   ├── 04-generate-design-validation.md # Generate Task 04
    │   ├── 05-generate-ddl.md            # Generate Task 05
    │   ├── 06-generate-sample-data.md    # Generate Task 06
    │   ├── 07-generate-query-design.md   # Generate Task 07
    │   ├── evaluate-task.md              # Evaluate one task
    │   └── evaluate-pipeline.md          # [Future] Evaluate pipeline
    |
    └── skills/
        ├── db-design-pipeline/           # Main DB design workflow
        │   ├── SKILL.md                  # Pipeline rules
        │   ├── 01-business-req-analysis/ # Task 01 skill
        │   │   └── SKILL.md
        │   ├── 02-erd/                   # Task 02 skill
        │   │   └── SKILL.md
        │   ├── 03-logical-design/        # Task 03 skill
        │   │   └── SKILL.md
        │   ├── 04-design-validation/     # Task 04 skill
        │   │   └── SKILL.md
        │   ├── 05-generate-ddl/          # Task 05 skill
        │   │   └── SKILL.md
        │   ├── 06-sample-data/           # Task 06 skill
        │   │   ├── SKILL.md
        │   │   └── references/
        │   │       ├── sql-style-and-ordering.md
        │   │       ├── execution-validation.md
        │   │       ├── completion-actions.md
        │   │       ├── business-rule-proofs.md
        │   │       ├── idempotence-and-test-isolation.md
        │   │       └── data-coverage.md
        │   └── 07-query-design/          # [Future] Task 07 skill
        │       └── SKILL.md
        │
        └── evaluations/                  # Evaluation framework
            ├── README.md                 # Evaluation guide
            ├── rubric.md                 # Output rubric
            ├── expected-files.md         # Required file list
            ├── agent-metrics-rubric.md   # Agent quality metrics
            ├── trajectory-recording.md   # Trace log rules
            └── templates/
                └── trajectory-template.md

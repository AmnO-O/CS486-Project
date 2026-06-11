## Self-Evaluation & Logging
Before you overwrite or finalize the output file for your assigned task, you MUST perform a Critique Loop:
1. **Identify & Read Old Output:** Determine the target output file for your CURRENT task. Read its CURRENT existing content (if the file already exists).
2. **Compare:** Compare the old content with your newly drafted content. Identify exactly what was added, modified, or improved based on the latest prompt/requirements.
3. **Generate Log File:** Create or append to an evaluation log file in the `.opencode/evaluations/logs/` folder. Name the file dynamically using the current date and your current task's name (e.g., `YYYY-MM-DD_[current-task-name]-eval.md`).
4. **Log Format:** Write your comparison in the log file using this exact format:
   - **Date:** [Current Date and Time]
   - **Reviewer Agent:** [Name of the Agent performing the evaluation]
   - **Task:** [Insert the exact name of the CURRENT task you are executing]
   - **Previous State:** [Brief summary of what the old file had. Write "None" if it's a new file]
   - **New State:** [Brief summary of the new file]
   - **Key Improvements:** - [Bullet point 1 detailing the exact improvement]
     - [Bullet point 2]
     - [Bullet point 3]
     - [Bullet point 4]
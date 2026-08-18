# Analysing AI-Generated Text Quality
### A SQL-Based Language Evaluation System

## Executive Summary

This project models and builds a relational database to evaluate the quality of AI-generated text across multiple language models. Using PostgreSQL, I designed a six-table normalized schema simulating a real evaluation workflow: three models (GPT-4, Claude, and Llama) respond to the same set of prompts, and evaluators score each response across five quality criteria on a 10-point scale.

Across roughly 50,000 individual evaluation scores, **GPT-4 scored highest overall** (7.00 average), narrowly ahead of **Claude** (6.98) and **Llama** (6.97). The gap is small overall, but breaking scores down by task category tells a more useful story: **GPT-4 leads in coding and grammar explanation**, **Claude leads in creative writing and summarization**, and **translation is a near three-way tie**. Based on these findings, I'd recommend that a team choosing a model for a specific product:

1. Use GPT-4 for technical or rules-based tasks, such as coding assistance or grammar tools
2. Use Claude for open-ended, generative tasks, such as creative writing or summarization
3. Treat translation as a toss-up between models and decide based on cost or latency instead

## Business Problem

As AI language models become more widely used, teams need a structured way to compare model performance across different task types, not just an overall "which model is best" ranking. A single leaderboard score can hide meaningful differences: a model that's strong at coding may be mediocre at creative writing, and vice versa. This project builds a database and analysis workflow to answer:

- Which model performs best overall, and within specific task categories?
- Where does each model perform well, and where does it struggle?
- How consistent are evaluators when scoring the same responses?
- How does model performance change over time?

## Methodology

1. **Design** a normalized six-table relational schema (models, prompts, responses, evaluators, criteria, evaluations) built from scratch rather than an existing dataset.
2. **Generate** a synthetic dataset simulating a realistic evaluation workflow: ~2,000 prompts, ~6,000 AI responses, 10 evaluators, ~50,000 individual scores.
3. **Clean** the data by removing duplicate prompts, standardizing category values, and handling missing word counts.
4. **Validate** the data before analysis, including checking referential integrity across foreign keys.
5. **Join** tables to connect models, prompts, responses, and evaluation scores.
6. **Aggregate** average scores by model and by task category.
7. **Use subqueries** to identify above-average performers.
8. **Classify** responses into quality tiers using CTEs and CASE statements.
9. **Rank and analyse trends** using window functions.
10. **Measure evaluator consistency** using `STDDEV`, and build a reusable view for reporting.

Built in PostgreSQL using pgAdmin.

## Skills Demonstrated

**Database Design:** relational schema design, normalization, PostgreSQL

**SQL:** multi-table JOINs, CTEs, subqueries, aggregate functions, data cleaning and validation

**Advanced Analysis:** window functions, views, `STDDEV` for consistency analysis, time-based analysis

## Results & Business Recommendation

The analysis surfaced clear, actionable patterns in the data:

<img width="2179" height="1282" alt="model_comparison" src="https://github.com/user-attachments/assets/199a750a-d6c9-4451-96c4-05a509e3066c" />

- **GPT-4** has the highest overall average score at **7.00**, narrowly ahead of **Claude** (6.98) and **Llama** (6.97) on a 10-point scale
- Scores across the dataset range from **4 to 10**, with no model ever scoring in the lowest range
- **GPT-4** leads in coding (7.04) and grammar explanation (7.04)
- **Claude** leads in creative writing (7.00) and summarization (6.99)
- **Translation is a near three-way tie** (6.97 across all three models), with no model holding a clear edge
- Evaluator scoring is consistent across all five quality criteria, with standard deviations tightly clustered between **1.72 and 1.74**, suggesting the variation in scores reflects genuine differences in response quality rather than inconsistent evaluators

Based on these findings, I'd recommend:

1. **Match the model to the task rather than picking one model for everything.** GPT-4 for technical and rules-based work, Claude for open-ended generative work.
2. **Treat translation as a cost or speed decision**, since quality is statistically even across all three models.
3. **Continue monitoring evaluator consistency** as new criteria or evaluators are added, since the current low variance is a sign of reliable scoring data worth preserving.

## Next Steps

1. Extend the schema to track cost and latency per model, so the model recommendation can factor in more than just quality.
2. Build a Power BI or dashboard view on top of the reusable SQL view for ongoing reporting.
3. Add a time-based analysis to see whether model performance shifts as prompt difficulty increases.

## Files in This Repository

- `ai_text_evaluation_schema.sql` — Database schema and sample seed data
- `bulk_data_generator.sql` — Generates the synthetic evaluation dataset
- `analysis_queries.sql` — SQL queries used throughout the project

## Data Source

This dataset is synthetically generated rather than sourced externally. It simulates a realistic AI evaluation workflow: three language models (GPT-4, Claude, Llama) responding to ~2,000 prompts across five task categories, scored by 10 evaluators across five quality criteria.

## How to Run This Project

1. Create a PostgreSQL database.
2. Run `ai_text_evaluation_schema.sql`.
3. Run `bulk_data_generator.sql`.
4. Run `analysis_queries.sql` section by section.

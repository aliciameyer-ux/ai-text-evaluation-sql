# Analysing AI-Generated Text Quality

### A SQL-Based Language Evaluation System

## Project Overview

This project models a relational database for evaluating the quality of AI-generated text. It simulates an evaluation workflow where multiple language models (GPT-4, Claude, and Llama) respond to the same set of prompts, and multiple evaluators score each response across several quality criteria including accuracy, fluency, coherence, relevance, and clarity.

The project explores questions such as:

* Which model performs best overall and within different task categories?
* Where does each model perform well, and where does it struggle?
* How consistent are evaluators when scoring the same responses?
* How does model performance change over time?

Built in PostgreSQL using pgAdmin.

## Why This Project

With a background in English language teaching, evaluating language quality felt like a natural problem to explore. Instead of analysing a traditional business dataset, I wanted to design a relational database around an AI text evaluation workflow while applying SQL skills such as database design, joins, data cleaning, validation, aggregation, subqueries, CTEs, window functions, and views.

## Database Schema

The database consists of six normalized tables:

| Table               | Purpose                                                               |
| ------------------- | --------------------------------------------------------------------- |
| llm_models          | The AI models being compared                                          |
| prompts             | Input prompts, tagged by category and difficulty                      |
| ai_responses        | Generated responses linked to a prompt and a model                    |
| evaluators          | People scoring the responses                                          |
| evaluation_criteria | Quality dimensions such as accuracy, fluency, and relevance           |
| evaluations         | Individual scores given by evaluators for each response and criterion |

One of the main design decisions was storing evaluation scores in a separate table. Since each response can be scored by multiple evaluators across multiple criteria, this structure avoids duplication and keeps the database normalized.

## Dataset Size

The dataset is synthetically generated to simulate a realistic AI evaluation workflow.

* Approximately 2,000 prompts across five categories (summarization, grammar explanation, translation, creative writing, and coding)
* Approximately 6,000 AI responses (three models for each prompt)
* 10 evaluators
* Approximately 50,000 individual evaluation scores

## SQL Analysis Workflow

1. Explore the dataset and understand its structure
2. Clean the data by removing duplicate prompts, standardizing category values, and handling missing word counts
3. Validate the data before analysis
4. Join tables to answer business questions
5. Compare models and task categories using aggregation
6. Use subqueries to identify above average performers
7. Classify responses into quality tiers using CTEs and CASE statements
8. Rank models and analyse performance trends with window functions
9. Measure evaluator consistency using `STDDEV`
10. Create a reusable view for reporting and future BI tools

## Skills Demonstrated

* Relational database design
* PostgreSQL
* Data cleaning and validation
* Multi-table JOINs
* Aggregate functions
* Subqueries
* Common Table Expressions (CTEs)
* Window functions
* Views
* Time-based analysis

## Files in This Repository

* `ai_text_evaluation_schema.sql` - Database schema and sample seed data
* `bulk_data_generator.sql` - Generates the synthetic evaluation dataset
* `analysis_queries.sql` - SQL queries used throughout the project

## Key Finding

Within this simulated dataset, GPT-4 achieved the highest average score overall, particularly in coding and grammar explanation tasks. Claude performed best in creative writing and summarization, while Llama achieved the highest scores in translation. The results demonstrate how the database can be used to compare model performance across different task types.

## A Note on the Data

One of the data cleaning challenges involved removing duplicate prompts. Because related responses and evaluations referenced those prompts through foreign keys, the dependent records had to be removed first before deleting the duplicates. This process helped maintain referential integrity and reflects a common challenge when working with relational databases.

## How to Run This Project

1. Create a PostgreSQL database.
2. Run `ai_text_evaluation_schema.sql`.
3. Run `bulk_data_generator.sql`.
4. Run `analysis_queries.sql` section by section.

# Analysing AI-Generated Text Quality
### A SQL-Based Language Evaluation System

## Project Overview
This project models a system for evaluating the quality of AI-generated text. It simulates a pipeline where multiple language models (GPT-4, Claude, Llama) respond to the same set of prompts, and multiple evaluators score each response across several quality criteria (accuracy, fluency, coherence, relevance, clarity).

The goal is to answer questions like:
- Which model performs best overall, and in which task categories?
- Where does each model struggle?
- How much do human evaluators agree with each other?
- How does model performance trend over time?

Built in PostgreSQL, using pgAdmin.

## Why This Project
I have a background in English language teaching, so evaluating language quality, not just running numbers, is a natural fit. This project combines that background with SQL skills relevant to data analytics: relational database design, joins, data cleaning, validation, aggregation, subqueries, CTEs, window functions, and views.

## Database Schema
Six normalized tables:

| Table | Purpose |
|---|---|
| llm_models | The AI models being compared |
| prompts | The input prompts, tagged by category and difficulty |
| ai_responses | Generated text, linked to a prompt and a model |
| evaluators | Who is scoring the responses |
| evaluation_criteria | The dimensions being scored (accuracy, fluency, etc.) |
| evaluations | The scores themselves, one row per evaluator/response/criterion |

The core design decision: a response can be scored by many evaluators across many criteria, so scores live in their own table rather than as columns on ai_responses.

## Dataset Size
- ~2,000 prompts across 5 categories (summarization, grammar explanation, translation, creative writing, coding)
- ~6,000 AI responses (3 models x each prompt)
- 10 evaluators
- ~50,000 individual evaluation scores

## Workflow
1. Data Exploration — understand the shape of the dataset
2. Data Cleaning — check for and remove duplicate prompts, standardize inconsistent category values, handle missing word counts
3. Data Validation — confirm the data is clean and complete before analysis
4. Joins — combine tables to answer real questions
5. Aggregation — compare models and categories
6. Subqueries — isolate above-average performers
7. CTEs + CASE logic — classify responses into quality tiers
8. Window Functions — rank models within categories, track performance over time
9. Evaluator Consistency — measure agreement between evaluators using STDDEV
10. View — package the core analysis into a reusable view for BI tools

## Files in This Repo
- ai_text_evaluation_schema.sql — table definitions + realistic seed data
- bulk_data_generator.sql — generates the large synthetic dataset
- analysis_queries.sql — the full analysis workflow

## Key Finding
GPT-4 had the highest overall average score, and led specifically in coding and grammar_explanation tasks. Claude performed best in creative_writing and summarization. Llama led in translation. This suggests model strength varies by task type rather than one model dominating across the board, which matters for choosing a model based on the actual use case rather than general reputation.

## A Note on the Data
Removing duplicate prompts required deleting related evaluation and response records first, since Postgres blocks deletes that would leave other tables referencing a row that no longer exists (a foreign key constraint). Handling that cascading delete correctly is part of the data cleaning process documented in the analysis file.

## How to Run This
1. Create a PostgreSQL database
2. Run ai_text_evaluation_schema.sql
3. Run bulk_data_generator.sql
4. Run analysis_queries.sql section by section

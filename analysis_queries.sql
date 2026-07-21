-- ============================================
-- AI-Generated Text Quality Analysis
-- Author: Alicia Meyer
-- Database: PostgreSQL
-- ============================================

-- ============================================
-- SECTION 1: DATA EXPLORATION
-- ============================================
-- First thing I want to do is just have a look at each table
-- and get a feel for what the data looks like before I do anything.

SELECT * FROM llm_models LIMIT 10;
SELECT * FROM prompts LIMIT 10;
SELECT * FROM ai_responses LIMIT 10;
SELECT * FROM evaluators LIMIT 10;
SELECT * FROM evaluation_criteria LIMIT 10;
SELECT * FROM evaluations LIMIT 10;

-- Checking how many rows are in each table.
SELECT COUNT(*) AS total_prompts FROM prompts;
SELECT COUNT(*) AS total_responses FROM ai_responses;
SELECT COUNT(*) AS total_evaluators FROM evaluators;
SELECT COUNT(*) AS total_evaluations FROM evaluations;

-- Checking what category values actually exist in prompts.
-- I want to see this before I clean anything, in case there
-- are inconsistent entries like mixed casing or extra spaces.
SELECT DISTINCT category FROM prompts ORDER BY category;

-- Checking how many prompts fall into each category and
-- difficulty level, just to understand the spread of the data.
SELECT category, difficulty_level, COUNT(*) AS num_prompts
FROM prompts
GROUP BY category, difficulty_level
ORDER BY category, difficulty_level;

-- Checking how many responses each model has, to confirm
-- every model was actually tested against the prompts.
SELECT m.model_name, COUNT(r.response_id) AS num_responses
FROM llm_models m
LEFT JOIN ai_responses r ON m.model_id = r.model_id
GROUP BY m.model_name;


-- ============================================
-- SECTION 2: DATA CLEANING
-- ============================================
-- Checking for duplicate prompts. I want to make sure the same
-- prompt wasn't accidentally loaded twice.

SELECT prompt_text, COUNT(*) AS num_copies
FROM prompts
GROUP BY prompt_text
HAVING COUNT(*) > 1
ORDER BY num_copies DESC;

-- Removing duplicate prompts while keeping the earliest copy
-- (lowest prompt_id). Because related responses and evaluations
-- reference these prompts through foreign keys, PostgreSQL won't
-- allow the prompt to be deleted first. The child records must be
-- removed before the duplicate prompt can be deleted.

-- Step 1: delete evaluations tied to responses for duplicate prompts
DELETE FROM evaluations
WHERE response_id IN (
    SELECT response_id
    FROM ai_responses
    WHERE prompt_id IN (
        SELECT prompt_id
        FROM (
            SELECT
                prompt_id,
                ROW_NUMBER() OVER (PARTITION BY prompt_text ORDER BY prompt_id) AS rn
            FROM prompts
        ) ranked
        WHERE rn > 1
    )
);

-- Step 2: delete the responses themselves for duplicate prompts
DELETE FROM ai_responses
WHERE prompt_id IN (
    SELECT prompt_id
    FROM (
        SELECT
            prompt_id,
            ROW_NUMBER() OVER (PARTITION BY prompt_text ORDER BY prompt_id) AS rn
        FROM prompts
    ) ranked
    WHERE rn > 1
);

-- Step 3: now the duplicate prompts can be safely removed
DELETE FROM prompts
WHERE prompt_id IN (
    SELECT prompt_id
    FROM (
        SELECT
            prompt_id,
            ROW_NUMBER() OVER (PARTITION BY prompt_text ORDER BY prompt_id) AS rn
        FROM prompts
    ) ranked
    WHERE rn > 1
);

-- Standardizing the category column. I want everything lowercase
-- and with no extra whitespace, so 'Summarization', 'SUMMARIZATION '
-- and 'summarization' all become the same value.
UPDATE prompts
SET category = LOWER(TRIM(category));

-- Confirming the cleanup worked.
SELECT DISTINCT category FROM prompts ORDER BY category;

-- Trimming whitespace from all text columns in ai_responses,
-- I don't want extra spaces causing issues later when I join tables.
UPDATE ai_responses
SET response_text = TRIM(response_text);

-- Filling in any missing word counts by recalculating them
-- from the actual response text instead of leaving them blank.
UPDATE ai_responses
SET word_count = array_length(regexp_split_to_array(TRIM(response_text), '\s+'), 1)
WHERE word_count IS NULL;


-- ============================================
-- SECTION 3: DATA VALIDATION
-- ============================================
-- Now that cleaning is done, I want to double check nothing
-- is still broken or missing before I move on to analysis.

-- Any responses still missing core fields?
SELECT response_id, prompt_id, model_id
FROM ai_responses
WHERE response_text IS NULL OR word_count IS NULL OR latency_ms IS NULL;

-- Any evaluation scores outside the 1-10 range they're supposed to be in?
SELECT * FROM evaluations
WHERE score < 1 OR score > 10;

-- Any responses that never got evaluated at all?
SELECT r.response_id, r.model_id, r.prompt_id
FROM ai_responses r
LEFT JOIN evaluations e ON r.response_id = e.response_id
WHERE e.evaluation_id IS NULL;

-- Checking that every response still points to a valid prompt
-- after removing duplicate prompts in Section 2.

SELECT r.response_id
FROM ai_responses r
LEFT JOIN prompts p ON r.prompt_id = p.prompt_id
WHERE p.prompt_id IS NULL;


-- ============================================
-- SECTION 4: JOINS
-- ============================================
-- Now I want to start combining tables to actually see the data
-- in a useful way, instead of one table at a time.

SELECT m.model_name, p.category, r.response_text
FROM ai_responses r
JOIN llm_models m ON r.model_id = m.model_id
JOIN prompts p ON r.prompt_id = p.prompt_id
LIMIT 10;


-- ============================================
-- SECTION 5: AGGREGATION
-- ============================================
-- Comparing the overall average score per model.
SELECT m.model_name, ROUND(AVG(e.score), 2) AS avg_score
FROM evaluations e
JOIN ai_responses r ON e.response_id = r.response_id
JOIN llm_models m ON r.model_id = m.model_id
GROUP BY m.model_name
ORDER BY avg_score DESC;

-- Narrowing down to where each model is weakest, model/category
-- combinations averaging below a 6.
SELECT m.model_name, p.category, ROUND(AVG(e.score), 2) AS avg_score, COUNT(*) AS num_scores
FROM evaluations e
JOIN ai_responses r ON e.response_id = r.response_id
JOIN llm_models m ON r.model_id = m.model_id
JOIN prompts p ON r.prompt_id = p.prompt_id
GROUP BY m.model_name, p.category
HAVING AVG(e.score) < 6
ORDER BY avg_score;


-- ============================================
-- SECTION 6: SUBQUERIES
-- ============================================
-- Finding responses that scored above the overall average,
-- using a subquery to calculate that average first.
SELECT r.response_id, m.model_name, ROUND(AVG(e.score), 2) AS avg_score
FROM ai_responses r
JOIN llm_models m ON r.model_id = m.model_id
JOIN evaluations e ON r.response_id = e.response_id
GROUP BY r.response_id, m.model_name
HAVING AVG(e.score) > (SELECT AVG(score) FROM evaluations)
ORDER BY avg_score DESC
LIMIT 20;


-- ============================================
-- SECTION 7: CTEs + CASE LOGIC
-- ============================================
-- Breaking this into two steps: first calculate the average score
-- per response, then label each one with a quality tier so it's
-- easier to read at a glance.
WITH response_scores AS (
    SELECT
        r.response_id,
        m.model_name,
        p.category,
        ROUND(AVG(e.score), 2) AS avg_score
    FROM ai_responses r
    JOIN llm_models m ON r.model_id = m.model_id
    JOIN prompts p ON r.prompt_id = p.prompt_id
    JOIN evaluations e ON r.response_id = e.response_id
    GROUP BY r.response_id, m.model_name, p.category
)
SELECT
    model_name,
    category,
    avg_score,
    CASE
        WHEN avg_score >= 9 THEN 'Excellent'
        WHEN avg_score >= 7 THEN 'Good'
        WHEN avg_score >= 5 THEN 'Average'
        ELSE 'Needs Improvement'
    END AS quality_tier
FROM response_scores
ORDER BY avg_score DESC
LIMIT 30;


-- ============================================
-- SECTION 8: WINDOW FUNCTIONS
-- ============================================
-- Ranking each model within its category, without collapsing
-- the rows the way GROUP BY on its own would.
SELECT
    p.category,
    m.model_name,
    ROUND(AVG(e.score), 2) AS avg_score,
    RANK() OVER (PARTITION BY p.category ORDER BY AVG(e.score) DESC) AS rank_in_category
FROM evaluations e
JOIN ai_responses r ON e.response_id = r.response_id
JOIN llm_models m ON r.model_id = m.model_id
JOIN prompts p ON r.prompt_id = p.prompt_id
GROUP BY p.category, m.model_name
ORDER BY p.category, rank_in_category;

-- Tracking a running average score over time for each model.
SELECT
    m.model_name,
    DATE(r.generated_at) AS response_date,
    ROUND(AVG(e.score), 2) AS daily_avg_score,
    ROUND(AVG(AVG(e.score)) OVER (
        PARTITION BY m.model_name ORDER BY DATE(r.generated_at)
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ), 2) AS running_avg_score
FROM ai_responses r
JOIN llm_models m ON r.model_id = m.model_id
JOIN evaluations e ON r.response_id = e.response_id
GROUP BY m.model_name, DATE(r.generated_at)
ORDER BY m.model_name, response_date;


-- ============================================
-- SECTION 9: EVALUATOR CONSISTENCY
-- ============================================
-- Checking how much evaluators agree with each other on the
-- same response, using standard deviation to measure it.
SELECT
    r.response_id,
    m.model_name,
    ROUND(STDDEV(e.score), 2) AS score_disagreement,
    COUNT(DISTINCT e.evaluator_id) AS num_evaluators
FROM evaluations e
JOIN ai_responses r ON e.response_id = r.response_id
JOIN llm_models m ON r.model_id = m.model_id
GROUP BY r.response_id, m.model_name
HAVING COUNT(DISTINCT e.evaluator_id) > 1
ORDER BY score_disagreement DESC NULLS LAST
LIMIT 20;


-- ============================================
-- SECTION 10: A REUSABLE VIEW
-- ============================================
-- Packaging the core analysis into a view so I can query it
-- directly, or connect it to Power BI later without rewriting
-- all these joins every time.
CREATE OR REPLACE VIEW model_performance_summary AS
SELECT
    m.model_name,
    p.category,
    c.criteria_name,
    ROUND(AVG(e.score), 2) AS avg_score,
    COUNT(*) AS num_evaluations
FROM evaluations e
JOIN ai_responses r ON e.response_id = r.response_id
JOIN llm_models m ON r.model_id = m.model_id
JOIN prompts p ON r.prompt_id = p.prompt_id
JOIN evaluation_criteria c ON e.criteria_id = c.criteria_id
GROUP BY m.model_name, p.category, c.criteria_name;

SELECT * FROM model_performance_summary
ORDER BY model_name, category, criteria_name
LIMIT 20;

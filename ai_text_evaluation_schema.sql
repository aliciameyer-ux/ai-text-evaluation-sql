-- =====================================================================
-- Project: Analysing AI-Generated Text Quality
-- A SQL-Based Language Evaluation System
-- Database: PostgreSQL
-- =====================================================================
-- DESIGN NOTE:
-- The core relationship in this database is many-to-many:
--   one AI response gets scored by MULTIPLE evaluators
--   across MULTIPLE criteria (accuracy, fluency, coherence, etc.)
-- That's why "evaluations" is its own table rather than adding
-- score columns onto ai_responses. This is what lets you write
-- interesting SQL later (joins, GROUP BY, window functions) instead
-- of a single flat spreadsheet-style table.
-- =====================================================================


-- =====================================================================
-- 1. llm_models
-- Which AI model produced the response. Kept separate so you can
-- compare models against each other (e.g. GPT vs Claude vs Llama).
-- =====================================================================
CREATE TABLE llm_models (
    model_id      SERIAL PRIMARY KEY,
    model_name    VARCHAR(100) NOT NULL,
    provider      VARCHAR(100),
    version       VARCHAR(50),
    release_date  DATE
);


-- =====================================================================
-- 2. prompts
-- The input given to the model. Category and difficulty let you
-- later ask "which task type do models struggle with most?"
-- =====================================================================
CREATE TABLE prompts (
    prompt_id        SERIAL PRIMARY KEY,
    prompt_text      TEXT NOT NULL,
    category         VARCHAR(50) NOT NULL,   -- e.g. 'summarization', 'creative_writing', 'coding', 'reasoning', 'translation'
    difficulty_level VARCHAR(20) CHECK (difficulty_level IN ('easy', 'medium', 'hard')),
    created_at       TIMESTAMP DEFAULT NOW()
);


-- =====================================================================
-- 3. ai_responses
-- One row per (prompt, model) pair — the actual generated text.
-- word_count and latency_ms are stored as plain columns (not derived
-- on the fly) because in a real system you'd capture them at
-- generation time, not recompute them every query.
-- =====================================================================
CREATE TABLE ai_responses (
    response_id    SERIAL PRIMARY KEY,
    prompt_id      INT NOT NULL REFERENCES prompts(prompt_id),
    model_id       INT NOT NULL REFERENCES llm_models(model_id),
    response_text  TEXT NOT NULL,
    word_count     INT,
    latency_ms     INT,
    generated_at   TIMESTAMP DEFAULT NOW()
);


-- =====================================================================
-- 4. evaluators
-- Who is doing the scoring. evaluator_type distinguishes human raters
-- from, say, an LLM-as-judge, so you could later compare human vs
-- automated evaluation.
-- =====================================================================
CREATE TABLE evaluators (
    evaluator_id    SERIAL PRIMARY KEY,
    evaluator_name  VARCHAR(100) NOT NULL,
    evaluator_type  VARCHAR(20) CHECK (evaluator_type IN ('human', 'expert', 'llm_judge')),
    expertise_area  VARCHAR(100)   -- e.g. 'ESL teaching', 'linguistics', 'general'
);


-- =====================================================================
-- 5. evaluation_criteria
-- The dimensions being scored. Kept as a lookup table (not hardcoded
-- columns) so you can add new criteria later without altering the
-- table structure — this is the normalization payoff.
-- =====================================================================
CREATE TABLE evaluation_criteria (
    criteria_id    SERIAL PRIMARY KEY,
    criteria_name  VARCHAR(50) UNIQUE NOT NULL,  -- accuracy, fluency, coherence, relevance, creativity, safety
    description    TEXT
);


-- =====================================================================
-- 6. evaluations
-- The fact table. One row = one evaluator scoring one response on
-- one criterion. This is where all the interesting joins happen.
-- The UNIQUE constraint stops the same evaluator scoring the same
-- response/criterion twice by accident.
-- =====================================================================
CREATE TABLE evaluations (
    evaluation_id  SERIAL PRIMARY KEY,
    response_id    INT NOT NULL REFERENCES ai_responses(response_id),
    evaluator_id   INT NOT NULL REFERENCES evaluators(evaluator_id),
    criteria_id    INT NOT NULL REFERENCES evaluation_criteria(criteria_id),
    score          NUMERIC(3,1) CHECK (score BETWEEN 1 AND 10),
    comments       TEXT,
    evaluated_at   TIMESTAMP DEFAULT NOW(),
    UNIQUE (response_id, evaluator_id, criteria_id)
);

-- Indexes on foreign keys used in JOINs/GROUP BY, for query performance
CREATE INDEX idx_responses_prompt   ON ai_responses(prompt_id);
CREATE INDEX idx_responses_model    ON ai_responses(model_id);
CREATE INDEX idx_evaluations_response ON evaluations(response_id);
CREATE INDEX idx_evaluations_evaluator ON evaluations(evaluator_id);
CREATE INDEX idx_evaluations_criteria  ON evaluations(criteria_id);


-- =====================================================================
-- SEED DATA
-- =====================================================================

INSERT INTO llm_models (model_name, provider, version, release_date) VALUES
('GPT-4', 'OpenAI', '4.0', '2023-03-14'),
('Claude', 'Anthropic', '3.5', '2024-06-20'),
('Llama', 'Meta', '3.1', '2024-07-23');

INSERT INTO prompts (prompt_text, category, difficulty_level) VALUES
('Summarize the causes of the French Revolution in 3 sentences.', 'summarization', 'medium'),
('Write a short story about a lighthouse keeper who finds a message in a bottle.', 'creative_writing', 'medium'),
('Explain the difference between "affect" and "effect" with examples.', 'grammar_explanation', 'easy'),
('Write a Python function that checks if a string is a palindrome.', 'coding', 'easy'),
('Translate this sentence into formal French: "Could you please send me the report by Friday?"', 'translation', 'hard');

INSERT INTO ai_responses (prompt_id, model_id, response_text, word_count, latency_ms) VALUES
(1, 1, 'The French Revolution was driven by financial crisis, social inequality between estates, and Enlightenment ideas challenging absolute monarchy. Rising bread prices and a weak king deepened public anger. These pressures culminated in the storming of the Bastille in 1789.', 40, 1200),
(1, 2, 'Heavy taxation and debt, sharp inequality between the nobility, clergy, and commoners, and the spread of Enlightenment ideas about liberty and rights combined to destabilize the monarchy. Poor harvests worsened public discontent. This unrest erupted into revolution in 1789.', 42, 980),
(3, 1, '"Affect" is usually a verb meaning to influence something, e.g. "The weather affects my mood." "Effect" is usually a noun meaning a result, e.g. "The effect of the storm was flooding."', 33, 700),
(3, 2, '"Affect" (verb) means to influence: "Stress can affect sleep." "Effect" (noun) means a result: "One effect of stress is poor sleep." A memory trick: Affect = Action, Effect = End result.', 34, 650),
(4, 3, 'def is_palindrome(s):\n    s = s.lower().replace(" ", "")\n    return s == s[::-1]', 12, 500);

INSERT INTO evaluators (evaluator_name, evaluator_type, expertise_area) VALUES
('Alicia', 'expert', 'ESL teaching'),
('Reviewer_2', 'human', 'general');

INSERT INTO evaluation_criteria (criteria_name, description) VALUES
('accuracy', 'Is the information factually correct?'),
('fluency', 'Is the language natural and grammatically correct?'),
('coherence', 'Does the response flow logically?'),
('relevance', 'Does the response actually address the prompt?'),
('clarity', 'Is the explanation easy to understand?');

INSERT INTO evaluations (response_id, evaluator_id, criteria_id, score, comments) VALUES
(1, 1, 1, 8.5, 'Accurate but slightly oversimplified.'),
(1, 1, 2, 9.0, 'Clean, natural sentences.'),
(1, 2, 1, 8.0, NULL),
(2, 1, 1, 9.0, 'More precise causal detail than response 1.'),
(2, 1, 2, 9.0, NULL),
(2, 2, 1, 9.5, 'Best factual coverage.'),
(3, 1, 4, 9.5, 'Directly answers the grammar question.'),
(3, 1, 5, 9.0, 'Clear examples.'),
(4, 1, 4, 10.0, 'Excellent memory trick added.'),
(4, 1, 5, 10.0, NULL),
(5, 2, 1, 9.0, 'Correct and runs as expected.'),
(5, 2, 3, 8.5, 'Short but logically complete.');


-- =====================================================================
-- EXAMPLE ANALYSIS QUERIES (for your portfolio write-up)
-- =====================================================================

-- Average score per model, across all criteria
SELECT m.model_name,
       ROUND(AVG(e.score), 2) AS avg_score,
       COUNT(*) AS num_evaluations
FROM evaluations e
JOIN ai_responses r ON e.response_id = r.response_id
JOIN llm_models m ON r.model_id = m.model_id
GROUP BY m.model_name
ORDER BY avg_score DESC;

-- Average score per criterion, per model (which model is strongest where)
SELECT m.model_name, c.criteria_name, ROUND(AVG(e.score), 2) AS avg_score
FROM evaluations e
JOIN ai_responses r ON e.response_id = r.response_id
JOIN llm_models m ON r.model_id = m.model_id
JOIN evaluation_criteria c ON e.criteria_id = c.criteria_id
GROUP BY m.model_name, c.criteria_name
ORDER BY m.model_name, avg_score DESC;

-- Rank responses within each prompt category by average score (window function)
SELECT p.category, m.model_name, r.response_id,
       ROUND(AVG(e.score), 2) AS avg_score,
       RANK() OVER (PARTITION BY p.category ORDER BY AVG(e.score) DESC) AS rank_in_category
FROM evaluations e
JOIN ai_responses r ON e.response_id = r.response_id
JOIN prompts p ON r.prompt_id = p.prompt_id
JOIN llm_models m ON r.model_id = m.model_id
GROUP BY p.category, m.model_name, r.response_id;

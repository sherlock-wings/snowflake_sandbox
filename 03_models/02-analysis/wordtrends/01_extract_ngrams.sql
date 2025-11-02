/*
  Extract N-grams (1-grams, 2-grams, 3-grams) from POST_TEXT
  
  This view extracts tokens and n-grams from social media posts, normalizes text,
  and prepares it for trend analysis. Each post is broken down into individual
  words and multi-word phrases.
  
  Features:
  - Normalizes text (lowercase, removes special chars except spaces)
  - Extracts 1-grams (single words)
  - Extracts 2-grams (word pairs)
  - Extracts 3-grams (three-word phrases)
  - Filters out very short tokens
  - Preserves CONTENT_ID and POST_MONTH for joining with sentiment data
*/

CREATE OR REPLACE VIEW BLUESKY_DB.PFC.VW_POST_NGRAMS AS
WITH cleaned_text AS (
  SELECT 
    p.CONTENT_ID,
    DATE_TRUNC('MONTH', p.POST_CREATED_AT_TIMESTAMP) AS POST_MONTH,
    -- Normalize text: lowercase, remove URLs, handle hashtags/mentions
    REGEXP_REPLACE(
      REGEXP_REPLACE(
        REGEXP_REPLACE(
          LOWER(TRIM(p.POST_TEXT)),
          'https?://\\S+', '', 1, 0, 'i'  -- Remove URLs
        ),
        '@\\w+', '', 1, 0  -- Remove mentions (optional - might want to keep)
      ),
      '[^a-z0-9\\s]', ' ', 1, 0  -- Replace punctuation with spaces
    ) AS CLEANED_TEXT
  FROM BLUESKY_DB.MAIN.FIREHOSE_PROCESSED p
  WHERE p.POST_TEXT IS NOT NULL
    AND p.POST_TEXT != ''
    AND LENGTH(TRIM(p.POST_TEXT)) > 0
),
tokenized AS (
  SELECT 
    CONTENT_ID,
    POST_MONTH,
    CLEANED_TEXT,
    -- Split text into array of words
    SPLIT(REGEXP_REPLACE(TRIM(CLEANED_TEXT), '\\s+', ' ', 1, 0), ' ') AS WORDS_ARRAY
  FROM cleaned_text
  WHERE CLEANED_TEXT IS NOT NULL
    AND LENGTH(TRIM(CLEANED_TEXT)) > 0
),
words_flat AS (
  SELECT 
    t.CONTENT_ID,
    t.POST_MONTH,
    TRIM(CAST(w.VALUE AS VARCHAR)) AS WORD,
    w.INDEX AS WORD_POSITION
  FROM tokenized t,
  LATERAL FLATTEN(INPUT => t.WORDS_ARRAY) w
  WHERE LENGTH(TRIM(CAST(w.VALUE AS VARCHAR))) >= 2  -- Minimum 2 characters per word
),
-- 1-grams (single words)
unigrams AS (
  SELECT 
    CONTENT_ID,
    POST_MONTH,
    WORD AS NGRAM,
    1 AS NGRAM_SIZE,
    WORD_POSITION AS START_POSITION
  FROM words_flat
),
-- 2-grams (word pairs)
bigrams AS (
  SELECT 
    w1.CONTENT_ID,
    w1.POST_MONTH,
    w1.WORD || ' ' || w2.WORD AS NGRAM,
    2 AS NGRAM_SIZE,
    w1.WORD_POSITION AS START_POSITION
  FROM words_flat w1
  INNER JOIN words_flat w2
    ON w1.CONTENT_ID = w2.CONTENT_ID
    AND w1.POST_MONTH = w2.POST_MONTH
    AND w2.WORD_POSITION = w1.WORD_POSITION + 1
),
-- 3-grams (three-word phrases)
trigrams AS (
  SELECT 
    w1.CONTENT_ID,
    w1.POST_MONTH,
    w1.WORD || ' ' || w2.WORD || ' ' || w3.WORD AS NGRAM,
    3 AS NGRAM_SIZE,
    w1.WORD_POSITION AS START_POSITION
  FROM words_flat w1
  INNER JOIN words_flat w2
    ON w1.CONTENT_ID = w2.CONTENT_ID
    AND w1.POST_MONTH = w2.POST_MONTH
    AND w2.WORD_POSITION = w1.WORD_POSITION + 1
  INNER JOIN words_flat w3
    ON w1.CONTENT_ID = w3.CONTENT_ID
    AND w1.POST_MONTH = w3.POST_MONTH
    AND w3.WORD_POSITION = w2.WORD_POSITION + 1
),
-- Combine all n-grams
all_ngrams AS (
  SELECT CONTENT_ID, POST_MONTH, NGRAM, NGRAM_SIZE, START_POSITION FROM unigrams
  UNION ALL
  SELECT CONTENT_ID, POST_MONTH, NGRAM, NGRAM_SIZE, START_POSITION FROM bigrams
  UNION ALL
  SELECT CONTENT_ID, POST_MONTH, NGRAM, NGRAM_SIZE, START_POSITION FROM trigrams
)
SELECT DISTINCT
  CONTENT_ID,
  POST_MONTH,
  NGRAM,
  NGRAM_SIZE,
  START_POSITION
FROM all_ngrams
WHERE LENGTH(TRIM(NGRAM)) >= 2;  -- Final validation


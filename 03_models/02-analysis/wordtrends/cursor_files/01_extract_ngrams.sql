insert into bluesky_db.pfc.post_ngrams 
WITH cleaned_text AS (
  SELECT 
    p.CONTENT_ID,
    DATE_TRUNC('MONTH', p.POST_CREATED_AT_TIMESTAMP) AS POST_MONTH,
    p.POST_TEXT,
    REGEXP_REPLACE(
      REGEXP_REPLACE(
        REGEXP_REPLACE(
          LOWER(TRIM(p.POST_TEXT)),
          'https?://\\S+', '', 1, 0, 'i'
        ),
        '@\\w+', '', 1, 0
      ),
      '[^a-z0-9\\s]', ' ', 1, 0
    ) AS CLEANED_TEXT
   ,post_created_at_timestamp
  FROM BLUESKY_DB.MAIN.FIREHOSE_PROCESSED p
  WHERE p.POST_TEXT IS NOT NULL
    AND p.POST_TEXT != ''
    AND LENGTH(TRIM(p.POST_TEXT)) > 0
    AND (p.FIRST_DETECTED_LANGUAGE = 'English' OR p.FIRST_DETECTED_LANGUAGE IS NULL)
    AND p.post_created_at_timestamp > (select nvl(max(post_created_at_timestamp), '1900-01-01 00:00:00 +1000') from bluesky_db.pfc.post_ngrams)
),
tokenized AS (
  SELECT 
    CONTENT_ID,
    POST_MONTH,
    SPLIT(REGEXP_REPLACE(TRIM(CLEANED_TEXT), '\\s+', ' ', 1, 0), ' ') AS WORDS_ARRAY,
    post_created_at_timestamp
  FROM cleaned_text
  WHERE CLEANED_TEXT IS NOT NULL
    AND LENGTH(TRIM(CLEANED_TEXT)) > 0
),
words_flat AS (
  SELECT 
    t.CONTENT_ID,
    t.POST_MONTH,
    TRIM(CAST(w.VALUE AS VARCHAR)) AS WORD,
    w.INDEX AS WORD_POSITION,
    t.post_created_at_timestamp
  FROM tokenized t,
  LATERAL FLATTEN(INPUT => t.WORDS_ARRAY) w
  WHERE LENGTH(TRIM(CAST(w.VALUE AS VARCHAR))) >= 2
),
stop_words AS (
  SELECT WORD FROM BLUESKY_DB.PFC.STOPWORDS_ENGLISH
),
-- Extract all n-grams but count per post first
post_ngrams AS (
  -- 1-grams (filtered)
  SELECT 
    w.CONTENT_ID,
    w.POST_MONTH,
    w.WORD AS NGRAM,
    1 AS NGRAM_SIZE,
    1 AS OCCURRENCES_IN_POST,
    w.post_created_at_timestamp
  FROM words_flat w
  LEFT JOIN stop_words s ON w.WORD = s.WORD
  WHERE s.WORD IS NULL
  
  UNION ALL
  
  -- 2-grams
  SELECT 
    w1.CONTENT_ID,
    w1.POST_MONTH,
    w1.WORD || ' ' || w2.WORD AS NGRAM,
    2 AS NGRAM_SIZE,
    1 AS OCCURRENCES_IN_POST,
    w1.post_created_at_timestamp
  FROM words_flat w1
  INNER JOIN words_flat w2
    ON w1.CONTENT_ID = w2.CONTENT_ID
    AND w1.POST_MONTH = w2.POST_MONTH
    AND w2.WORD_POSITION = w1.WORD_POSITION + 1
  WHERE NOT (
    w1.WORD IN (SELECT WORD FROM stop_words) 
    AND w2.WORD IN (SELECT WORD FROM stop_words)
    AND w1.WORD = w2.WORD
  )
  
  UNION ALL
  
  -- 3-grams
  SELECT 
    w1.CONTENT_ID,
    w1.POST_MONTH,
    w1.WORD || ' ' || w2.WORD || ' ' || w3.WORD AS NGRAM,
    3 AS NGRAM_SIZE,
    1 AS OCCURRENCES_IN_POST,
    w1.post_created_at_timestamp
  FROM words_flat w1
  INNER JOIN words_flat w2
    ON w1.CONTENT_ID = w2.CONTENT_ID
    AND w1.POST_MONTH = w2.POST_MONTH
    AND w2.WORD_POSITION = w1.WORD_POSITION + 1
  INNER JOIN words_flat w3
    ON w1.CONTENT_ID = w3.CONTENT_ID
    AND w1.POST_MONTH = w3.POST_MONTH
    AND w3.WORD_POSITION = w2.WORD_POSITION + 1
  WHERE NOT (
    w1.WORD IN (SELECT WORD FROM stop_words)
    AND w2.WORD IN (SELECT WORD FROM stop_words)
    AND w3.WORD IN (SELECT WORD FROM stop_words)
    AND w1.WORD = w2.WORD 
    AND w2.WORD = w3.WORD
  )
),
-- Join back to get POST_TEXT for each post
posts_with_text AS (
  SELECT DISTINCT
    CONTENT_ID,
    POST_MONTH,
    POST_TEXT
  FROM cleaned_text
),
-- Aggregate by post: count occurrences of each n-gram per post
post_ngram_counts AS (
  SELECT 
    n.CONTENT_ID,
    n.POST_MONTH,
    n.NGRAM,
    n.NGRAM_SIZE,
    SUM(n.OCCURRENCES_IN_POST) AS OCCURRENCES_IN_POST,
    MAX(p.POST_TEXT) AS POST_TEXT,  -- POST_TEXT is same for all n-grams in a post
    n.post_created_at_timestamp
  FROM post_ngrams n
  INNER JOIN posts_with_text p
    ON n.CONTENT_ID = p.CONTENT_ID
    AND n.POST_MONTH = p.POST_MONTH
  GROUP BY all
)
-- Final output: post-level aggregated n-grams with POST_TEXT and RECORD_KEY
SELECT 
  CONTENT_ID,
  POST_MONTH,
  NGRAM,
  NGRAM_SIZE,
  OCCURRENCES_IN_POST,
  POST_TEXT,
  -- RECORD_KEY: MD5 hash of columns required for uniqueness (null-safe)
  -- Uniqueness: CONTENT_ID + POST_MONTH + NGRAM + NGRAM_SIZE
  MD5(
    CONCAT(
      COALESCE(CAST(CONTENT_ID AS VARCHAR), ''),
      '|',
      COALESCE(CAST(POST_MONTH AS VARCHAR), ''),
      '|',
      COALESCE(CAST(NGRAM AS VARCHAR), ''),
      '|',
      COALESCE(CAST(NGRAM_SIZE AS VARCHAR), '')
    )
  ) AS RECORD_KEY
 ,post_created_at_timestamp
FROM post_ngram_counts
WHERE LENGTH(TRIM(NGRAM)) >= 2
;
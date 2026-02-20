/*
================================================================================
N-GRAM ANALYSIS FOR BLUESKY POSTS
================================================================================
This script creates the infrastructure needed to analyze unigrams, bigrams, and
trigrams from Bluesky posts with stopwords removed.

The goal is to let interesting keywords emerge from the data organically rather
than selecting them manually (which introduces bias).

Dependencies:
- BLUESKY_DB.MAIN.REMOVE_STOPWORDS (UDF) - already exists
- BLUESKY_DB.PFC.STOPWORDS_ENGLISH (table) - already exists
- BLUESKY_DB.MAIN.FIREHOSE_PROCESSED (table) - source data

Objects Created:
- BLUESKY_DB.MAIN.GENERATE_NGRAMS (UDF) - generates n-grams from token array
- BLUESKY_DB.MAIN.NGRAMS_BLOWN_OUT (table) - persisted n-gram data (~337M rows)
- BLUESKY_DB.MAIN.SPROC_POPULATE_NGRAMS (procedure) - populates the table
- Several views for analysis

Created: 2026-02-20
================================================================================
*/

USE DATABASE BLUESKY_DB;
USE SCHEMA MAIN;
USE WAREHOUSE COMPUTE_WH;
USE ROLE ADMIN_FR;

--------------------------------------------------------------------------------
-- STEP 1: Create UDF to generate n-grams from a token array
--------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION GENERATE_NGRAMS(tokens VARIANT, n INT)
RETURNS VARIANT
LANGUAGE PYTHON
RUNTIME_VERSION = '3.9'
HANDLER = 'generate_ngrams'
AS $$
def generate_ngrams(tokens: list, n: int) -> list:
    """
    Generate n-grams from a list of tokens.
    
    Args:
        tokens: List of word tokens
        n: Size of n-gram (1=unigram, 2=bigram, 3=trigram)
    
    Returns:
        List of n-gram strings joined by spaces
    """
    if not tokens or len(tokens) < n:
        return []
    
    # Filter out empty strings and None values
    tokens = [t for t in tokens if t and str(t).strip()]
    
    if len(tokens) < n:
        return []
    
    ngrams = []
    for i in range(len(tokens) - n + 1):
        ngram = ' '.join(str(tokens[j]) for j in range(i, i + n))
        ngrams.append(ngram)
    
    return ngrams
$$;

--------------------------------------------------------------------------------
-- STEP 2: Create persisted table for n-grams (for performance)
--------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS NGRAMS_BLOWN_OUT (
    CONTENT_ID VARCHAR(16777216),
    POST_DATE DATE,
    POST_CREATED_AT_TIMESTAMP TIMESTAMP_TZ(9),
    NGRAM_TYPE VARCHAR(10),
    NGRAM_SIZE INT,
    NGRAM VARCHAR(16777216),
    INSERTED_AT_TIMESTAMP TIMESTAMP_TZ(9) DEFAULT CURRENT_TIMESTAMP(),
    INSERTED_BY_USER VARCHAR(255) DEFAULT CURRENT_USER(),
    INSERTED_WITH_ROLE VARCHAR(255) DEFAULT CURRENT_ROLE()
);

--------------------------------------------------------------------------------
-- STEP 3: Create stored procedure to populate the n-grams table
--------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE SPROC_POPULATE_NGRAMS(
    p_mode VARCHAR DEFAULT 'INCREMENTAL'  -- 'FULL' = truncate and reload, 'INCREMENTAL' = only new records
)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    v_start_time TIMESTAMP_TZ;
    v_end_time TIMESTAMP_TZ;
    v_rows_inserted INT;
    v_max_date DATE;
    v_result VARCHAR;
    v_sql VARCHAR;
BEGIN
    v_start_time := CURRENT_TIMESTAMP();
    
    IF (UPPER(p_mode) = 'FULL') THEN
        TRUNCATE TABLE BLUESKY_DB.MAIN.NGRAMS_BLOWN_OUT;
        v_max_date := '1900-01-01'::DATE;
    ELSE
        SELECT COALESCE(MAX(POST_DATE), '1900-01-01'::DATE) INTO v_max_date
        FROM BLUESKY_DB.MAIN.NGRAMS_BLOWN_OUT;
    END IF;
    
    v_sql := 'INSERT INTO BLUESKY_DB.MAIN.NGRAMS_BLOWN_OUT (
        CONTENT_ID, POST_DATE, POST_CREATED_AT_TIMESTAMP, NGRAM_TYPE, NGRAM_SIZE, NGRAM
    )
    WITH stopwords_array AS (
        SELECT ARRAY_AGG(WORD) AS stopword_list 
        FROM BLUESKY_DB.PFC.STOPWORDS_ENGLISH
    )
    ,cleaned_data AS (
        SELECT 
            p.CONTENT_ID,
            DATE(p.USA_TIMESTAMP) AS POST_DATE,
            p.POST_CREATED_AT_TIMESTAMP,
            BLUESKY_DB.MAIN.REMOVE_STOPWORDS(s.stopword_list, p.POST_TEXT) AS CLEANED_TOKENS,
            ARRAY_SIZE(BLUESKY_DB.MAIN.REMOVE_STOPWORDS(s.stopword_list, p.POST_TEXT)) AS TOKEN_COUNT
        FROM BLUESKY_DB.MAIN.FIREHOSE_PROCESSED p
        CROSS JOIN stopwords_array s
        WHERE p.POST_TEXT IS NOT NULL 
          AND p.POST_TEXT != ''''
          AND p.FIRST_DETECTED_LANGUAGE = ''English''
          AND DATE(p.USA_TIMESTAMP) > ''' || v_max_date::VARCHAR || '''::DATE
    )
    ,base_data AS (SELECT * FROM cleaned_data WHERE TOKEN_COUNT >= 1)
    ,unigrams AS (
        SELECT CONTENT_ID, POST_DATE, POST_CREATED_AT_TIMESTAMP, 
               ''unigram'' AS NGRAM_TYPE, 1 AS NGRAM_SIZE, 
               TRIM(f.VALUE::STRING, ''"'') AS NGRAM
        FROM base_data, LATERAL FLATTEN(input => CLEANED_TOKENS) f
    )
    ,bigrams AS (
        SELECT CONTENT_ID, POST_DATE, POST_CREATED_AT_TIMESTAMP, 
               ''bigram'' AS NGRAM_TYPE, 2 AS NGRAM_SIZE, 
               TRIM(f.VALUE::STRING, ''"'') AS NGRAM
        FROM base_data, LATERAL FLATTEN(input => BLUESKY_DB.MAIN.GENERATE_NGRAMS(CLEANED_TOKENS, 2)) f
        WHERE TOKEN_COUNT >= 2
    )
    ,trigrams AS (
        SELECT CONTENT_ID, POST_DATE, POST_CREATED_AT_TIMESTAMP, 
               ''trigram'' AS NGRAM_TYPE, 3 AS NGRAM_SIZE, 
               TRIM(f.VALUE::STRING, ''"'') AS NGRAM
        FROM base_data, LATERAL FLATTEN(input => BLUESKY_DB.MAIN.GENERATE_NGRAMS(CLEANED_TOKENS, 3)) f
        WHERE TOKEN_COUNT >= 3
    )
    SELECT * FROM unigrams 
    UNION ALL SELECT * FROM bigrams 
    UNION ALL SELECT * FROM trigrams';
    
    EXECUTE IMMEDIATE v_sql;
    
    SELECT COUNT(*) INTO v_rows_inserted FROM BLUESKY_DB.MAIN.NGRAMS_BLOWN_OUT;
    v_end_time := CURRENT_TIMESTAMP();
    
    v_result := 'Mode: ' || p_mode || ' | Rows in table: ' || v_rows_inserted::VARCHAR || 
                ' | Duration: ' || DATEDIFF('second', v_start_time, v_end_time)::VARCHAR || ' seconds';
    
    RETURN v_result;
END;
$$;

-- To run:
-- CALL SPROC_POPULATE_NGRAMS('FULL');        -- Full reload (~9 minutes for 12M posts)
-- CALL SPROC_POPULATE_NGRAMS('INCREMENTAL'); -- Only new data since last load

--------------------------------------------------------------------------------
-- STEP 4: Create view for cleaned tokens (optional, for ad-hoc analysis)
--------------------------------------------------------------------------------
CREATE OR REPLACE VIEW VW_POSTS_CLEANED_TOKENS AS
WITH stopwords_array AS (
    SELECT ARRAY_AGG(WORD) AS stopword_list 
    FROM BLUESKY_DB.PFC.STOPWORDS_ENGLISH
)
SELECT 
    p.CONTENT_ID,
    p.POST_CREATED_AT_TIMESTAMP,
    p.USA_TIMESTAMP,
    DATE(p.USA_TIMESTAMP) AS POST_DATE,
    p.POST_TEXT,
    BLUESKY_DB.MAIN.REMOVE_STOPWORDS(s.stopword_list, p.POST_TEXT) AS CLEANED_TOKENS,
    ARRAY_SIZE(BLUESKY_DB.MAIN.REMOVE_STOPWORDS(s.stopword_list, p.POST_TEXT)) AS TOKEN_COUNT
FROM BLUESKY_DB.MAIN.FIREHOSE_PROCESSED p
CROSS JOIN stopwords_array s
WHERE p.POST_TEXT IS NOT NULL 
  AND p.POST_TEXT != ''
  AND p.FIRST_DETECTED_LANGUAGE = 'English'
;

--------------------------------------------------------------------------------
-- STEP 5: Create views for n-gram analysis (query the persisted table)
--------------------------------------------------------------------------------

-- Daily n-gram frequency (for time series analysis)
CREATE OR REPLACE VIEW VW_NGRAM_DAILY_FREQUENCY AS
SELECT 
    POST_DATE,
    NGRAM_TYPE,
    NGRAM,
    COUNT(*) AS FREQUENCY,
    COUNT(DISTINCT CONTENT_ID) AS UNIQUE_POSTS
FROM NGRAMS_BLOWN_OUT
GROUP BY POST_DATE, NGRAM_TYPE, NGRAM
;

-- Overall n-gram frequency (for ranking top n-grams)
CREATE OR REPLACE VIEW VW_NGRAM_OVERALL_FREQUENCY AS
SELECT 
    NGRAM_TYPE,
    NGRAM,
    COUNT(*) AS TOTAL_FREQUENCY,
    COUNT(DISTINCT CONTENT_ID) AS UNIQUE_POSTS,
    MIN(POST_DATE) AS FIRST_SEEN,
    MAX(POST_DATE) AS LAST_SEEN,
    COUNT(DISTINCT POST_DATE) AS DAYS_PRESENT
FROM NGRAMS_BLOWN_OUT
GROUP BY NGRAM_TYPE, NGRAM
;

--------------------------------------------------------------------------------
-- STEP 6: Create views for n-gram sentiment analysis
--------------------------------------------------------------------------------

-- N-gram sentiment join view
CREATE OR REPLACE VIEW VW_NGRAM_SENTIMENT AS
SELECT 
    n.POST_DATE,
    n.NGRAM_TYPE,
    n.NGRAM,
    n.CONTENT_ID,
    s.SENTIMENT_DETECTED_LABEL,
    s.SENTIMENT_CONFIDENCE_SCORE
FROM NGRAMS_BLOWN_OUT n
JOIN FIREHOSE_NLP_LABELED s
    ON n.CONTENT_ID = s.CONTENT_ID
;

-- Aggregated sentiment by n-gram
CREATE OR REPLACE VIEW VW_NGRAM_SENTIMENT_SUMMARY AS
SELECT 
    NGRAM_TYPE,
    NGRAM,
    COUNT(*) AS TOTAL_OCCURRENCES,
    COUNT(DISTINCT CONTENT_ID) AS UNIQUE_POSTS,
    
    -- Sentiment distribution
    SUM(CASE WHEN SENTIMENT_DETECTED_LABEL = 'Positive' THEN 1 ELSE 0 END) AS POSITIVE_COUNT,
    SUM(CASE WHEN SENTIMENT_DETECTED_LABEL = 'Neutral' THEN 1 ELSE 0 END) AS NEUTRAL_COUNT,
    SUM(CASE WHEN SENTIMENT_DETECTED_LABEL = 'Negative' THEN 1 ELSE 0 END) AS NEGATIVE_COUNT,
    
    -- Sentiment percentages
    ROUND(100.0 * SUM(CASE WHEN SENTIMENT_DETECTED_LABEL = 'Positive' THEN 1 ELSE 0 END) / COUNT(*), 2) AS POSITIVE_PCT,
    ROUND(100.0 * SUM(CASE WHEN SENTIMENT_DETECTED_LABEL = 'Neutral' THEN 1 ELSE 0 END) / COUNT(*), 2) AS NEUTRAL_PCT,
    ROUND(100.0 * SUM(CASE WHEN SENTIMENT_DETECTED_LABEL = 'Negative' THEN 1 ELSE 0 END) / COUNT(*), 2) AS NEGATIVE_PCT,
    
    -- Average confidence score
    ROUND(AVG(SENTIMENT_CONFIDENCE_SCORE), 4) AS AVG_CONFIDENCE,
    
    -- Sentiment score: +1 for positive, 0 for neutral, -1 for negative (weighted by confidence)
    ROUND(AVG(
        CASE 
            WHEN SENTIMENT_DETECTED_LABEL = 'Positive' THEN SENTIMENT_CONFIDENCE_SCORE
            WHEN SENTIMENT_DETECTED_LABEL = 'Negative' THEN -SENTIMENT_CONFIDENCE_SCORE
            ELSE 0 
        END
    ), 4) AS WEIGHTED_SENTIMENT_SCORE
    
FROM VW_NGRAM_SENTIMENT
GROUP BY NGRAM_TYPE, NGRAM
;

--------------------------------------------------------------------------------
-- SAMPLE QUERIES FOR ANALYSIS (fast - uses persisted table)
--------------------------------------------------------------------------------

/*
-- Quick table stats
SELECT 
    NGRAM_TYPE,
    COUNT(*) as row_count,
    COUNT(DISTINCT NGRAM) as unique_ngrams,
    COUNT(DISTINCT CONTENT_ID) as unique_posts
FROM NGRAMS_BLOWN_OUT
GROUP BY NGRAM_TYPE;

-- Top 50 unigrams overall (excluding contraction artifacts)
SELECT NGRAM_TYPE, NGRAM, COUNT(*) AS TOTAL_FREQUENCY, COUNT(DISTINCT CONTENT_ID) AS UNIQUE_POSTS
FROM NGRAMS_BLOWN_OUT
WHERE NGRAM_TYPE = 'unigram'
  AND NGRAM NOT IN ('', '''', '''s', '''t', '''m', '''re', '''ve', '''ll', '''d')
  AND LEN(NGRAM) > 1
GROUP BY NGRAM_TYPE, NGRAM
ORDER BY TOTAL_FREQUENCY DESC
LIMIT 50;

-- Top 50 bigrams overall
SELECT NGRAM_TYPE, NGRAM, COUNT(*) AS TOTAL_FREQUENCY, COUNT(DISTINCT CONTENT_ID) AS UNIQUE_POSTS
FROM NGRAMS_BLOWN_OUT
WHERE NGRAM_TYPE = 'bigram'
  AND NGRAM NOT LIKE '%''%'
GROUP BY NGRAM_TYPE, NGRAM
ORDER BY TOTAL_FREQUENCY DESC
LIMIT 50;

-- Top 50 trigrams overall
SELECT NGRAM_TYPE, NGRAM, COUNT(*) AS TOTAL_FREQUENCY, COUNT(DISTINCT CONTENT_ID) AS UNIQUE_POSTS
FROM NGRAMS_BLOWN_OUT
WHERE NGRAM_TYPE = 'trigram'
  AND NGRAM NOT LIKE '%''%'
GROUP BY NGRAM_TYPE, NGRAM
ORDER BY TOTAL_FREQUENCY DESC
LIMIT 50;

-- Daily trending unigrams (top 20 per day)
SELECT * FROM (
    SELECT 
        POST_DATE,
        NGRAM,
        FREQUENCY,
        ROW_NUMBER() OVER (PARTITION BY POST_DATE ORDER BY FREQUENCY DESC) as rank
    FROM VW_NGRAM_DAILY_FREQUENCY
    WHERE NGRAM_TYPE = 'unigram'
      AND NGRAM NOT IN ('', '''', '''s', '''t', '''m', '''re', '''ve', '''ll', '''d')
      AND LEN(NGRAM) > 1
)
WHERE rank <= 20
ORDER BY POST_DATE DESC, rank;

-- Most positive bigrams (minimum 100 occurrences)
SELECT * FROM VW_NGRAM_SENTIMENT_SUMMARY
WHERE NGRAM_TYPE = 'bigram'
  AND TOTAL_OCCURRENCES >= 100
  AND NGRAM NOT LIKE '%''%'
ORDER BY WEIGHTED_SENTIMENT_SCORE DESC
LIMIT 50;

-- Most negative bigrams (minimum 100 occurrences)
SELECT * FROM VW_NGRAM_SENTIMENT_SUMMARY
WHERE NGRAM_TYPE = 'bigram'
  AND TOTAL_OCCURRENCES >= 100
  AND NGRAM NOT LIKE '%''%'
ORDER BY WEIGHTED_SENTIMENT_SCORE ASC
LIMIT 50;
*/

# English Stop Words Table

## Overview

The `BLUESKY_DB.PFC.STOPWORDS_ENGLISH` table contains a comprehensive list of 175 common English stop words based on NLTK and spaCy standard stop word lists.

## Table Structure

```sql
CREATE TABLE BLUESKY_DB.PFC.STOPWORDS_ENGLISH (
    WORD VARCHAR(50) PRIMARY KEY,
    INSERTED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    INSERTED_BY VARCHAR(255) DEFAULT CURRENT_USER()
)
```

## Files

1. **`stopwords_english.csv`** - CSV file containing all stop words (one per line)
   - Header row: `word`
   - 175 stop words total
   - Includes contractions (don't, can't, etc.)
   - Based on NLTK and spaCy standard lists

2. **`load_stopwords.sql`** - SQL script to load stop words into the table
   - Contains INSERT statements for all 175 words
   - Can be run to reload or update the table

## Stop Word List Categories

The list includes:

- **Articles**: a, an, the
- **Pronouns**: I, you, he, she, it, we, they, me, him, her, us, them, etc.
- **Prepositions**: of, in, on, at, to, for, with, from, etc.
- **Conjunctions**: and, but, or, nor, so, yet
- **Common verbs**: be, is, am, are, was, were, been, being, have, has, had, do, does, did, etc.
- **Adverbs**: very, too, so, then, now, here, there, where, when, why, how
- **Determiners**: this, that, these, those, some, any, all, both, each, every
- **Contractions**: don't, can't, won't, isn't, aren't, etc.

## Usage

### Query the table:
```sql
SELECT * FROM BLUESKY_DB.PFC.STOPWORDS_ENGLISH ORDER BY WORD;
```

### Use in views/queries:
```sql
-- Example: Filter stop words from a word list
SELECT w.word
FROM words w
LEFT JOIN BLUESKY_DB.PFC.STOPWORDS_ENGLISH s ON w.word = s.WORD
WHERE s.WORD IS NULL;  -- Exclude stop words
```

### Reload the table:
```sql
-- Clear existing data
TRUNCATE TABLE BLUESKY_DB.PFC.STOPWORDS_ENGLISH;

-- Run load_stopwords.sql to reload
```

## Integration with Word Trends Analysis

The stop words table is designed to be used in the `VW_POST_NGRAMS` view. Update the view to reference this table instead of the inline VALUES list for easier maintenance:

```sql
-- Instead of:
stop_words AS (
  SELECT word FROM VALUES ('the'), ('and'), ... AS stopword_list(word)
)

-- Use:
stop_words AS (
  SELECT WORD FROM BLUESKY_DB.PFC.STOPWORDS_ENGLISH
)
```

## Adding Custom Stop Words

To add additional stop words:

```sql
INSERT INTO BLUESKY_DB.PFC.STOPWORDS_ENGLISH (WORD) 
VALUES ('customword1'), ('customword2');
```

Or load from CSV:

```sql
COPY INTO BLUESKY_DB.PFC.STOPWORDS_ENGLISH (WORD)
FROM @your_stage/stopwords_english.csv
FILE_FORMAT = (TYPE = 'CSV' SKIP_HEADER = 1);
```


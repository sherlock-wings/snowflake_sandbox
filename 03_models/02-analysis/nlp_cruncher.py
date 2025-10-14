from datasets import Dataset
from datetime import datetime, timedelta
import os
import re
import argparse
import snowflake.connector
from snowflake.connector.pandas_tools import write_pandas
from time import sleep
import torch
from transformers import pipeline

### GLOBAL VARS | GLOBAL VARS | GLOBAL VARS | GLOBAL VARS | GLOBAL VARS | GLOBAL VARS | GLOBAL VARS | GLOBAL VARS | GLOBAL VARS | GLOBAL VARS | GLOBAL VARS 
### GLOBAL VARS | GLOBAL VARS | GLOBAL VARS | GLOBAL VARS | GLOBAL VARS | GLOBAL VARS | GLOBAL VARS | GLOBAL VARS | GLOBAL VARS | GLOBAL VARS | GLOBAL VARS 
### GLOBAL VARS | GLOBAL VARS | GLOBAL VARS | GLOBAL VARS | GLOBAL VARS | GLOBAL VARS | GLOBAL VARS | GLOBAL VARS | GLOBAL VARS | GLOBAL VARS | GLOBAL VARS 

# this basically means "smoke em if you got em" where the "em" is NVIDIA GPU
DEVICE = 0 if torch.cuda.is_available() else -1

SF_USR = os.getenv('SF_USR')
SF_ID  = os.getenv('SF_ID')
SF_WH  = os.getenv('SF_WH')
SF_DB  = os.getenv('SF_DB')
SF_SC  = os.getenv('SF_SC')
SF_RL  = os.getenv('SF_RL')

# connect to database and init a cursor for querying
xct_params = {
    "user":                 SF_USR
   ,"account":              SF_ID
   ,"warehouse":            SF_WH
   ,"database":             SF_DB
   ,"schema":               SF_SC
   ,"role":                 SF_RL
   ,"private_key_file":     os.getenv('PRIVATE_KEY_PATH')
   ,"private_key_file_pwd": os.getenv('PRIVATE_KEY_PASSPHRASE')
   ,"authenticator":        os.getenv('SF_AUTH')
}

SF_XCT = snowflake.connector.connect(**xct_params)
CSR = SF_XCT.cursor()

# sentiment analyzer doo-dad instantiation
PIPL_SNT = pipeline(
    "sentiment-analysis",
    model="cardiffnlp/twitter-roberta-base-sentiment",
    tokenizer="cardiffnlp/twitter-roberta-base-sentiment",
    device=DEVICE,
    truncation=True,
    max_length = 512 
)
## This sentiment pipeline returns labels like ['LABEL_0', 'LABEL_1', 'LABEL_2']
## instead of ['Negative', 'Neutral', 'Positive']
## The below-linked mapping indicates which model-labels match to which
## human-understandable terms. 
## for verification, see this link:
##      https://huggingface.co/cardiffnlp/twitter-roberta-base-sentiment


### FUNCTIONS | FUNCTIONS | FUNCTIONS | FUNCTIONS | FUNCTIONS | FUNCTIONS | FUNCTIONS | FUNCTIONS | FUNCTIONS | FUNCTIONS | FUNCTIONS | FUNCTIONS 
### FUNCTIONS | FUNCTIONS | FUNCTIONS | FUNCTIONS | FUNCTIONS | FUNCTIONS | FUNCTIONS | FUNCTIONS | FUNCTIONS | FUNCTIONS | FUNCTIONS | FUNCTIONS 
### FUNCTIONS | FUNCTIONS | FUNCTIONS | FUNCTIONS | FUNCTIONS | FUNCTIONS | FUNCTIONS | FUNCTIONS | FUNCTIONS | FUNCTIONS | FUNCTIONS | FUNCTIONS 

def execute_query(query: str
                 ,conn: snowflake.connector.connection.SnowflakeConnection = SF_XCT
                 ,cursor: snowflake.connector.cursor.SnowflakeCursor = CSR
                 ,connection_parameters: dict = xct_params
                 ,retry_attempts: int = 5
                 ) -> snowflake.connector.cursor.SnowflakeCursor:
    """
    Execute a query in such a way that it never fails unless Snowflake really really
    won't let you connect after multiple retries

    Args:
        query: The query you want to execute in Snowflake
        conn:  The Python Connection to Snowflake
        cursor: The cursor you use to execute queries in Snowflake via the connection
        connection_parameters: A dict containing the username, authentication, etc that lets you into Snowflake
        retry_attempts: Total number of times this function will reattempt to connect and query before giving 
                        up.
    """
    try:
        cursor.execute(query)
        return cursor
    except snowflake.connector.errors.ProgrammingError as e:
        # Programming errors should surface to the caller for correction
        print(f"Bad query. Encountered error: {e}\n... from this query:\n{query}")
        raise
    except (snowflake.connector.errors.ForbiddenError,
            snowflake.connector.errors.DatabaseError,
            snowflake.connector.errors.OperationalError,
            snowflake.connector.errors.InterfaceError) as e:
        print(f"Connection to Snowflake went bad due to error: {e}\nAttempting to re-establish connection with retries...")
        last_error_msg = e

        for attempt in range(1, retry_attempts + 1):
            try:
                if conn:
                    try:
                        conn.close()
                    except Exception:
                        pass
                conn = snowflake.connector.connect(**connection_parameters)
                cursor = conn.cursor()
                cursor.execute(query)
                print(f"Successfully re-established connection on attempt {attempt}")
                return cursor
            except Exception as e:
                print(f"Reconnection attempt {attempt} failed: {e}")
                last_error_msg = e
                if attempt < retry_attempts:
                    # backoff up to 16s
                    sleep(2 ** (attempt - 1))
        print(f"Failed to re-establish connection and execute query after {retry_attempts} attempts. Aborting.")
        raise last_error_msg
  
def writeback_batch(source_table_query: str
                   ,source_table_name: str
                   ,target_table_name: str
                   ,target_columns: list
                   ,nlp_params: dict
                   ,source_table_filter: str = None
                   ,source_database: str = SF_DB
                   ,source_schema: str = SF_SC
                   ,target_database: str = SF_DB
                   ,target_schema: str = SF_SC
                   ,conn: snowflake.connector.connection.SnowflakeConnection = SF_XCT
                   ,cursor: snowflake.connector.cursor.SnowflakeCursor = CSR
                   ,connection_parameters: dict = xct_params
                   ):
    """
    This query is used for all the NLP workflows on this project. It works like this:

        1. Query some source table. Retrieve the results in batches
        2. For each batch, do some local NLP analysis
        3. Write the batch back to a target table
        4. Repeat until all batches are exhausted, printing detailed progress 
           reports along the way
    
    Args:
        source_table_query: The SQL query string used to retrieve the source data 
        source_table_name: The name of the source table in Snowflake
        source_table_filter: A SQL fragment that filters the source table. This
                             is input separate so it can be used with the part
                             where we count rows in the source table; don't want
                             an inaccurate count.
        target_table_name: The name of the table to which we are writing NLP data
        target_columns: The column-set of the target table (string list)
        nlp_params: A dict that indicates what NLP metric is being calculated,
                    what transformer pipeline is being used, and what the name
                    is of the column containing the text that is being analyzed.
                    ------------------------------------------------------------
                    Example dict:
                    ------------------------------------------------------------
                    {
                        'nlp_metric':           'SENTIMENT_ANALYSIS'
                       ,'transformer_pipeline': PIPL_SENT
                       ,'target_text_colname':  'POST_TEXT'
                    }
                    ------------------------------------------------------------
        source_database: the database of the source table
        source_database: the schema of the source table
        target_database: the database of the target table
        target_database: the schema of the target table
        conn: Snowflake connection
        cursor: Snowflake connection's cursor
        connection_parameters: All details used to instantiate a Snowflake 
                               connection              
    """
    
    # need to be able to report progress during execution because this runs for so long
    # track some measures to help do that
    count_all_query = f"select count(*) from {source_database}.{source_schema}.{source_table_name}"
    if source_table_filter:
        source_table_filter = re.sub(r'\s+', ' ', source_table_filter)
        count_all_query += f' {source_table_filter}'
    cursor = execute_query(count_all_query
                          ,conn=conn
                          ,cursor=cursor
                          ,connection_parameters=connection_parameters
                          )
    total_rows_in_source = cursor.fetchone()[0]
    c = 0
    rows_processed = 0
    pcnt_progress = 0
    
    # retrieve and process source data in resumable, paginated batches
    source_table_query = re.sub(r'\s+', ' ', source_table_query)
    process_started_at = datetime.now()
    batch_size = nlp_params.get('batch_size', 1000)
    num_batches = (total_rows_in_source + batch_size - 1) // batch_size
    mode_msg = (
        "Full refresh: starting from scratch (INT_FIREHOSE_NLP will be cleared)."
        if nlp_params.get('full_refresh') else
        "Resume: processing remaining rows not in INT_FIREHOSE_NLP or FIREHOSE_NLP_LABELED."
    )
    print(f"\nInitiated NLP Workflow '{nlp_params['nlp_metric']}' at\n{process_started_at.strftime('%Y-%m-%d %H:%M:%S')}")
    print(mode_msg)
    print(f"Remaining rows to process from {source_table_name.upper()}: {(total_rows_in_source):,}")
    print(f"Batch size: {batch_size:,} | Estimated batches: {num_batches:,}\n")

    # The selection query must already exclude rows present in INT and LABELED
    # We'll page by LIMIT to avoid long-lived cursors; each page is independent and resumable
    batch_size = nlp_params.get('batch_size', 1000)

    while True:
        paged_query = f"{source_table_query} limit {int(batch_size)}"
        cursor = execute_query(paged_query
                              ,conn=conn
                              ,cursor=cursor
                              ,connection_parameters=connection_parameters
                              )
        batch = cursor.fetch_pandas_all()
        if batch is None or len(batch) == 0:
            break

        batch_started_at = datetime.now()
        c              += 1
        rows_processed += len(batch)
        pcnt_progress   = min(100, (rows_processed/total_rows_in_source) * 100)
        print(f"\n{len(batch):,} rows downloaded from page {(c):,} at {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")

        # Prepare clean text inputs for the transformer: list[str]
        text_col = nlp_params['target_text_colname']
        texts = (
            batch[text_col]
            .astype("string")
            .fillna("")
            .tolist()
        )
        # Replace any accidental None values post-conversion
        texts = [t if isinstance(t, str) and t != "<NA>" else "" for t in texts]

        nlp_output = nlp_params['transformer_pipeline'](texts)
        batch[nlp_params['nlp_metric'].upper()] = nlp_output
        
        try:
            batch = batch[target_columns]
        except KeyError as e:
            print(f"Attempted to select these columns in batch:\n{target_columns}\nActual columns in this batch are:\n{batch.columns}")

        write_pandas(SF_XCT
                    ,batch
                    ,table_name        = target_table_name.replace('"', '').upper()
                    ,database          = target_database.replace('"', '').upper()
                    ,schema            = target_schema.replace('"', '').upper()
                    ,use_logical_type  = True
                    ,auto_create_table = False
                    ,overwrite         = False
            )
        
        # After writing the page, update the source query to continue excluding what's in INT
        # This keeps the next page small even after interruptions
        # Nothing to do here as the source query already excludes INT on each loop

        batch_finished_at = datetime.now()
        print(f"Batch {(c):,} completed at {batch_finished_at.strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"{len(batch):,} rows from batch written to {target_table_name} ({(pcnt_progress):,.1f}% of source rows processed)")
        total_seconds_for_batch = (batch_finished_at - batch_started_at).total_seconds()
        minute_time_for_batch = int(total_seconds_for_batch // 60)
        second_time_for_batch = total_seconds_for_batch % 60
        print(f"Batch Process Time = {(minute_time_for_batch):,}m {(second_time_for_batch):,.1f}s")
           
    process_finished_at = datetime.now()
    total_seconds_for_process = (process_finished_at - process_started_at).total_seconds()
    minute_time_for_process = total_seconds_for_process // 60
    second_time_for_process = total_seconds_for_process % 60
    print(f"\n{(c):,} batches totaling {(total_rows_in_source):,} rows were processed in {round(minute_time_for_process, 0)}m {(second_time_for_process):,.1f}s")
    print(f"Average process velocity is {round((total_rows_in_source/(total_seconds_for_process/60)), 1):,.1f} rows/minute")

### DRIVER | DRIVER | DRIVER | DRIVER | DRIVER | DRIVER | DRIVER | DRIVER | DRIVER | DRIVER | DRIVER | DRIVER | DRIVER | DRIVER | DRIVER | DRIVER | DRIVER |
### DRIVER | DRIVER | DRIVER | DRIVER | DRIVER | DRIVER | DRIVER | DRIVER | DRIVER | DRIVER | DRIVER | DRIVER | DRIVER | DRIVER | DRIVER | DRIVER | DRIVER |
### DRIVER | DRIVER | DRIVER | DRIVER | DRIVER | DRIVER | DRIVER | DRIVER | DRIVER | DRIVER | DRIVER | DRIVER | DRIVER | DRIVER | DRIVER | DRIVER | DRIVER |

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Run NLP cruncher with resumable batching")
    parser.add_argument("--full-refresh", action="store_true", dest="full_refresh", help="Truncate INT table and reprocess from scratch")
    parser.add_argument("--batch-size", type=int, default=1000, dest="batch_size", help="Rows per page to fetch from source")
    args = parser.parse_args()

    ## Setup filters based on refresh mode
    if args.full_refresh:
        CSR = execute_query(f'truncate table {SF_DB}.{SF_SC}.INT_FIREHOSE_NLP')

    language_filter = "(first_detected_language = 'English' or first_detected_language is null)"
    exclude_labeled = f"content_id not in (select content_id from {SF_DB}.{SF_SC}.firehose_nlp_labeled)"
    exclude_int = f"content_id not in (select content_id from {SF_DB}.{SF_SC}.int_firehose_nlp)" if not args.full_refresh else "1=1"

    base_select = f"""
    select content_id
          ,usa_timestamp as POST_CREATED_USA_TIMESTAMP
          ,post_text
    from {SF_DB}.{SF_SC}.firehose_processed
    where {language_filter}
      and {exclude_labeled}
      and {exclude_int}
    """

    # Full query string used by the paginated loop (LIMIT applied inside the loop)
    query = base_select

    # Filter string used for counting rows remaining
    src_filter = f"where {language_filter} and {exclude_labeled} and {exclude_int}"

    nlp_params = {'nlp_metric': 'SENTIMENT_ANALYSIS'
                 ,'transformer_pipeline': PIPL_SNT
                 ,'target_text_colname': 'POST_TEXT'
                 ,'batch_size': args.batch_size
                 ,'full_refresh': args.full_refresh
                 }
    target_cols = ['CONTENT_ID', 'POST_CREATED_USA_TIMESTAMP', 'POST_TEXT', 'SENTIMENT_ANALYSIS']

    # writeback NLP in resumable pages
    writeback_batch(query, 'FIREHOSE_PROCESSED', 'INT_FIREHOSE_NLP', target_cols, nlp_params, source_table_filter=src_filter)

    # At this point, we have the NER data in INT_FIREHOSE_NLP. We have the SENT data in TMP_MERGE_SRC. So we have to
    # 1. MERGE the SENT data from TMP_MERGE_SRC to INT_FIREHOSE_NLP
    # 2. INSERT everything in INT_FIREHOSE_NLP to FIREHOSE_NLP_LABELED
    query=f"""
    merge into  {SF_DB}.{SF_SC}.firehose_nlp_labeled tgt
    using (
    select a.content_id
          ,a.post_created_usa_timestamp
          ,b.readable_label_name as sentiment_detected_label
          ,cast(sentiment_analysis:score as number(5,4)) as sentiment_confidence_score
          ,current_timestamp() as record_inserted_at_timestamp
          ,current_user() as record_inserted_by_user
          ,current_role() as record_inserted_with_role
    from {SF_DB}.{SF_SC}.int_firehose_nlp a
    left join {SF_DB}.{SF_SC}.label_map_roberta_base_sentiment b
           on trim(a.sentiment_analysis:label, '"') = b.model_label_name
    ) src
       on src.content_id = tgt.content_id
    when not matched then insert (
     content_id
    ,post_created_usa_timestamp
    ,sentiment_detected_label
    ,sentiment_confidence_score
    ,record_inserted_at_timestamp
    ,record_inserted_by_user
    ,record_inserted_with_role
    ) values (
     src.content_id
    ,src.post_created_usa_timestamp
    ,src.sentiment_detected_label
    ,src.sentiment_confidence_score
    ,src.record_inserted_at_timestamp
    ,src.record_inserted_by_user
    ,src.record_inserted_with_role
    )"""

    CSR = execute_query(query)
    # make sure you actually inserted something before clearing the table
    inserted_rows = CSR.fetchone()[0]
    if inserted_rows > 0:
        # After successful merge, it's safe to clear INT so the next run resumes with fresh deltas
        CSR = execute_query(f'truncate table {SF_DB}.{SF_SC}.INT_FIREHOSE_NLP')
        print(f"Operation completed at {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\nSuccessfully cleared INT_FIREHOSE_NLP and inserted all data to FIREHOSE_NLP_LABELED")
        CSR.close()
        SF_XCT.close()
    else:
        print("Latest query completed, but zero rows were inserted. INT_FIREHOSE_NLP has *not* been cleared, so no worries.")
        print("Maybe something is wrong with the last query you ran? Go fix it!")
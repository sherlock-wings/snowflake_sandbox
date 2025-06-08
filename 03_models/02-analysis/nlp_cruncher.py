from datasets import Dataset
from datetime import datetime, timedelta
import os
import re
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

# named-entity recognition doo-dad instantiation
PIPL_NER = pipeline(
    "ner",
    model="dslim/bert-base-NER",
    tokenizer="dslim/bert-base-NER",
    aggregation_strategy="simple",
    device=DEVICE,
    batch_size=256 
)

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
        print(f"Bad query. Encountered error: {e}\n... from this query:\n{query}")
    except snowflake.connector.errors.ForbiddenError as e:
        print(f"Connection to Snowflake went bad due to error: {e}\nAttempting to re-establish connection...")
        last_error_msg = e

        for i in range(retry_attempts):
            try:
                if conn:
                    conn.close()
                conn = snowflake.connector.connect(**connection_parameters)
                cursor = conn.cursor()
                cursor.execute(query)
                print(f"Successfully re-established connection on attempt {i}")
                return cursor
            except Exception as e:
                print(f"Reconnection Attempt {i} Failed: {e}")
                last_error_msg = e
                if i < retry_attempts: # only sleep & try again if you still have retries left
                    sleep(2 ** i) #increase time between each reconnection attempt exponentially-- this maxes out at just over 1 min of total 'waiting to retry' time for 5 attempts
        else: # i didn't know you could do `for... else` in python! cool!!
            print(f"Failed to re-establish connection and execute query after {retry_attempts} attempts. Aborting.")
            # Print the final error and then re-raise it
            raise last_error_msg 
  
def writeback_batch(source_table_query: str
                   ,source_table_name
                   ,target_table_name
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
    
    # retrieve source data
    source_table_query = re.sub(r'\s+', ' ', source_table_query)
    cursor = execute_query(source_table_query
                          ,conn=conn
                          ,cursor=cursor
                          ,connection_parameters=connection_parameters
                          )
    process_started_at = datetime.now()
    print(f"\nInitiated NLP Workflow '{nlp_params['nlp_metric']}' at\n{process_started_at.strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"Downloading {(total_rows_in_source):,} total rows from {source_table_name.upper()}...\n\n")

    for batch in cursor.fetch_pandas_batches():
        batch_started_at = datetime.now()
        c              += 1
        rows_processed += 1
        pcnt_progress  += (len(batch)/total_rows_in_source) * 100
        print(f"\n{len(batch):,} rows downloaded from batch {(c):,}")

        # using this thing as input is more efficient than using `batch` directly for whatever reason
        batch_dataset = Dataset.from_pandas(batch[[nlp_params['target_text_colname']]], preserve_index=False)
        # execute NER analysis 
        nlp_output = nlp_params['transformer_pipeline'](batch_dataset[nlp_params['target_text_colname']])
        batch[nlp_params['nlp_metric'].upper()] = nlp_output
        
        # NER is called first-- if that's what we're doing, then fill in an empty sentana column for now-- we'll get it later
        if nlp_params['nlp_metric'].upper() == 'NER_ANALYSIS' and 'SENTIMENT_ANALYSIS' not in batch.columns:
            batch['SENTIMENT_ANALYSIS'] = None
        
        # match col order before writing
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
        
        #### more prints to show velocity 
        # ... of this specific batch
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
    print(f"Average process velocity is {round((total_rows_in_source/(total_seconds_for_process/60)), 1):,.1f}")

### DRIVER | DRIVER | DRIVER | DRIVER | DRIVER | DRIVER | DRIVER | DRIVER | DRIVER | DRIVER | DRIVER | DRIVER | DRIVER | DRIVER | DRIVER | DRIVER | DRIVER |
### DRIVER | DRIVER | DRIVER | DRIVER | DRIVER | DRIVER | DRIVER | DRIVER | DRIVER | DRIVER | DRIVER | DRIVER | DRIVER | DRIVER | DRIVER | DRIVER | DRIVER |
### DRIVER | DRIVER | DRIVER | DRIVER | DRIVER | DRIVER | DRIVER | DRIVER | DRIVER | DRIVER | DRIVER | DRIVER | DRIVER | DRIVER | DRIVER | DRIVER | DRIVER |

if __name__ == "__main__":
    ## NER ANALYSIS
    query = f"""
    select content_id
          ,usa_timestamp as POST_CREATED_USA_TIMESTAMP
          ,post_text
    from {SF_DB}.{SF_SC}.firehose_processed
    where usa_timestamp between to_timestamp_tz('2025-05-25 00:00:00+0000')
                            and to_timestamp_tz('2025-05-31 23:59:59+0000')
      and (first_detected_language = 'English'
           or first_detected_language is null
          )
      and content_id not in (select content_id from {SF_DB}.{SF_SC}.firehose_nlp_labeled); 
    """
    src_filter = f"""
    where usa_timestamp between to_timestamp_tz('2025-05-25 00:00:00+0000')
                            and to_timestamp_tz('2025-05-31 23:59:59+0000')
      and (first_detected_language = 'English'
           or first_detected_language is null
          )
      and content_id not in (select content_id from {SF_DB}.{SF_SC}.firehose_nlp_labeled)"""
    nlp_params = {'nlp_metric': 'NER_ANALYSIS'
                 ,'transformer_pipeline': PIPL_NER
                 ,'target_text_colname': 'POST_TEXT'
                 }
    target_cols = ['CONTENT_ID', 'POST_CREATED_USA_TIMESTAMP', 'POST_TEXT', 'NER_ANALYSIS', 'SENTIMENT_ANALYSIS']

    # writeback NER
    writeback_batch(query, 'FIREHOSE_PROCESSED', 'INT_FIREHOSE_NLP', target_cols, nlp_params, source_table_filter=src_filter)
    
    ## SENTIMENT ANALYSIS
    query = f"""create or replace table {SF_DB}.{SF_SC}.TMP_MERGE_SRC(
     content_id varchar
    ,post_created_usa_timestamp timestamp_tz(9)
    ,post_text varchar
    ,sentiment_analysis variant
    )"""
    CSR = execute_query(query)
    
    query = "select * from bluesky_db.main.int_firehose_nlp;"
    nlp_params = {'nlp_metric': 'SENTIMENT_ANALYSIS'
                 ,'transformer_pipeline': PIPL_SNT
                 ,'target_text_colname': 'POST_TEXT'
                 }
    target_cols = ['POST_TEXT', 'CONTENT_ID', 'SENTIMENT_ANALYSIS']
    
    # writeback SENTIMENT
    writeback_batch(query, 'INT_FIREHOSE_NLP', 'TMP_MERGE_SRC', target_cols, nlp_params)

    # At this point, we have the NER data in INT_FIREHOSE_NLP. We have the SENT data in TMP_MERGE_SRC. So we have to
    # 1. MERGE the SENT data from TMP_MERGE_SRC to INT_FIREHOSE_NLP
    # 2. INSERT everything in INT_FIREHOSE_NLP to FIREHOSE_NLP_LABELED
    query=f"""
    merge into {SF_DB}.{SF_SC}.INT_FIREHOSE_NLP tgt
    using {SF_DB}.{SF_SC}.TMP_MERGE_SRC src
       on src.content_id = tgt.content_id
    when matched then update 
    set tgt.SENTIMENT_ANALYSIS = src.SENTIMENT_ANALYSIS
    """

    CSR = execute_query(query)
    print(f"Sentiment Analysis MERGE into INT_FIREHOSE_NLP.SENTIMENT_ANALYSIS using TMP_MERGE_SRC complete!")

    query = f"""
    insert into {SF_DB}.{SF_SC}.firehose_nlp_labeled
    with src as (
    select a.content_id
          ,a.post_created_usa_timestamp
          ,b.readable_label_name as sentiment_detected_label
          ,cast(sentiment_analysis:score as number(5,4)) as sentiment_confidence_score
          ,row_number() over (
           partition by a.content_id
           order     by a.post_created_usa_timestamp, trim(a2.value:word, '"')
           ) as post_entity_number
          ,trim(a2.value:entity_group, '"') as ner_detected_group
          ,trim(a2.value:word, '"') as ner_detected_entity
          ,cast(a2.value:score as number(5,4)) as ner_confidence_score
          ,current_timestamp() as record_inserted_at_timestamp
          ,current_user() as record_inserted_by_user
          ,current_role() as record_inserted_with_role
    from {SF_DB}.{SF_SC}.int_firehose_nlp a
    left join table(flatten(input => parse_json(a.ner_analysis))) a2
    left join {SF_DB}.{SF_SC}.label_map_roberta_base_sentiment b
           on trim(a.sentiment_analysis:label, '"') = b.model_label_name
    left join {SF_DB}.{SF_SC}.firehose_nlp_labeled tgt
           on tgt.content_id = a.content_id
    where tgt.content_id is null
    )

    select sha2(nvl(to_char(content_id), 'NULL') 
             || '||' 
             || nvl(to_char(post_entity_number), 'NULL')
           ) as analysis_id
          ,*
    from src 
    order by content_id
            ,post_created_usa_timestamp
            ,ner_detected_entity
    """
    try:
        CSR = execute_query(query)
        inserted_rows = CSR.fetchone()[0]
        print(f"{(inserted_rows):,} rows inserted to final target FIREHOSE_NLP_LABELED")
        if inserted_rows > 0:
            CSR = execute_query(f'truncate table {SF_DB}.{SF_SC}.INT_FIREHOSE_NLP')
            CSR = execute_query(f"drop table {SF_DB}.{SF_SC}.TMP_MERGE_SRC")
            print(f"Operation completed at {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\nSuccessfully cleared INT_FIREHOSE_NLP and inserted all data to FIREHOSE_NLP_LABELED")
            CSR.close()
            SF_XCT.close()
    except Exception as e:
        print(f"Encountered an error during the final target insertion: {e}")

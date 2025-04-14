from atproto import Client
from atproto.exceptions import NetworkError 
import azure.functions as func
from azure.identity import DefaultAzureCredential
from azure.storage.blob import BlobServiceClient, ContainerClient
import csv
from datetime import datetime
from dateutil import parser as timestamp_parser
from io import StringIO, BytesIO
import logging
import os
import pandas as pd
import pytz
import time
from typing import Tuple

# TEST
###
### AZURE CONFIG
###

# instantiate blob Service Client (dependency of container client)
AZR_DFT_CRD = DefaultAzureCredential()
AZR_ACT_URL = f"https://{os.getenv('AZR_STR_ACT')}.blob.core.windows.net"
BLB_SVC_CLI = BlobServiceClient(AZR_ACT_URL, AZR_DFT_CRD)

# instantiate container client (needed for reads/writes of blob data to/from bluesky_posts azr directory)
AZR_TGT_CTR = os.getenv('AZR_TGT_CTR')
AZR_CTR_CLI = BLB_SVC_CLI.get_container_client(AZR_TGT_CTR)
C_AZR_SRC_DIR = os.getenv('C_AZR_SRC_DIR')
AZR_TGT_DIR = f"{os.getenv('AZR_TGT_DIR')}/"  # apparently a trailing slash is required? 


###
### BLUESKY CLIENT CONFIG
###

USR = os.getenv('BSY_USR').lower()
KEY = os.getenv('BSY_KEY')

###
### OTHER IMPORTANT LOCAL VARS
###

# defines the columnset for all data collected from bluesky posts
SCHEMA = {'content_id':                               []
         ,'post_uri':                                 []
         ,'like_count':                               []
         ,'quote_count':                              []
         ,'reply_count':                              []
         ,'repost_count':                             []
         ,'post_created_timestamp':                   []
         ,'text':                                     []
         ,'tags':                                     []
         ,'embedded_link_title':                      []
         ,'embedded_link_description':                []
         ,'embedded_link_uri':                        []
         ,'post_author_did':                          []
         ,'post_author_username':                     []
         ,'post_author_displayname':                  []
         ,'post_author_account_created_timestamp':    []
         ,'bluesky_client_account_did':               []
         ,'bluesky_client_account_username':          []
         ,'bluesky_client_account_displayname':       []
         ,'bluesky_client_account_created_timestamp': []
         ,'record_captured_timestamp':                []
        }

# Control-table directory 
# This table will be used for the "high-watermark" stratgegy for incremental ingestion 
L_XTR_DIR = os.getenv('L_XTR_DIR')

# Instantiate a BlueSky session
def bluesky_login() -> Tuple[Client, str]:
    bsky_client = Client()
    bsky_client.login(USR, KEY)
    return bsky_client, USR

# get BlueSky DID
# The DID never changes for a BlueSky user account, whereas handle can change
# Therefore, DID is more reliable to identify a specific user, and should be leveraged instead of user handle where possible 
def get_did(bsky_client: Client, bksy_handle: str) -> str:
    return bsky_client.com.atproto.identity.resolve_handle({'handle': bksy_handle}).did

# get all followers for the user related to a given BlueSky session
def get_following_users(bsky_client: Client, bsky_handle: str, follows_limit: int = 100) -> list:
    bsky_did = get_did(bsky_client, bsky_handle)
    csr = None
    pages_remain = True
    following_users = []
    # like posts, followed users are paginated
    while pages_remain:
        resp = bsky_client.get_follows(actor=bsky_did, limit=follows_limit, cursor=csr)
        following_users += resp.follows
        if not resp.cursor:
            pages_remain = False
        csr = resp.cursor
    return following_users 


# write a chunk of post data to CSV
def write_chunk(df: pd.DataFrame, output_path: str=None) -> None:
    if not output_path:
        output_path = C_AZR_SRC_DIR
    # filename format is posts_<extraction_date>_<file_ordinal>.csv, where <final ordinal> is an incremental int
    # ex) If 3 files are generated on New Years Day 2025, the names are ['posts_2025-01-01_1.csv', 'posts_2025-01-01_2.csv', 'posts_2025-01-01_3.csv']
    rn = datetime.now().strftime('%Y-%m-%d')
    filename = f"{output_path}/posts_{rn}_"
    last_file_num = -1
    
    # generating the incremental int correctly means checking, both in the cloud and locally, for any CSVs which already exist whose name includes the current date 
    # check Azure Cloud Storage location first to determine the name for the next generated CSV
    azr_files = [blob.name for blob in AZR_CTR_CLI.list_blobs()]
    if len(azr_files) > 0:
        cloud_file_numbers = [int(file.split('_')[-1].split('.')[0]) for file in azr_files if file.split('.')[-1] == 'csv' and rn in file]
        cloud_file_numbers.sort()
        try:
            last_file_num = cloud_file_numbers[-1]+1
        except IndexError:
            last_file_num = 0    
    else:
        last_file_num = 0
    
    if last_file_num > 0:
        filename += f"{last_file_num}.csv"
    else:
        filename += "1.csv"
    df['azure_container_name'] = AZR_TGT_CTR
    df['azure_blobpath'] = AZR_TGT_DIR
    print(f"\nWriting {filename}...")
    df['azure_blobname'] = filename.split('/')[-1]

    csv_buffer = df.to_csv(filename,
                           index=False,
                           encoding='utf-8',
                           quoting=csv.QUOTE_ALL, # Wrap all fields in quotes -- hopefully this handles weird chars like line separators or paragraph separators
                           quotechar='"',         
                           escapechar='\\',       
                           doublequote=True,      
                           lineterminator='\n'    
                          )
    upload_file_to_azr(csv_buffer, filename) 
             
# check if the current file is already "full" (larger than 100 MB, by default)
# if it is, stash the current data object as CSV and reset a new empty one    
def chunk_check(schema_input: dict, filesize_limit_mb: int = 300, dict_input: dict=None, dataframe_input: pd.DataFrame=pd.DataFrame(), callout_size: bool=False) -> Tuple[pd.DataFrame, dict]:
    if not dict_input and dataframe_input.empty:
        raise ValueError("chunk_check() requires either an argument for `dict_input` or for `dataframe_input`. Both cannot be ommitted.")
    elif dataframe_input.empty:
        dataframe_input = pd.DataFrame(dict_input)
    '''
    TODO-- Figure out why there isn't a one-to-one between MB measured via pd.DataFrame.memory_usage() and 
           actual MB consumed when the CSV is written to disk.

           Like if you try to cut it off at 100 MB the file that gets written is something like 45 - 65 MB.

           So right now I'm just gonna crank this number up to 300 until I can figure out a better way 
           to control this without guesstimating.
    '''
    size = dataframe_input.memory_usage(deep=True).sum() / (1000000)
    if callout_size:
        print(f"Current calculated space of df is {size:,.2f} MB")
    if size >= filesize_limit_mb:
        print("SIZE LIMIT TRIGGERED")
        write_chunk(dataframe_input)
        return pd.DataFrame(), schema_input
    return dataframe_input, dict_input
    
# write User Feed data as a series of one or more CSVs
def stash_user_posts(client_details: str
                    ,schema_input: dict
                    ,bsky_client:Client
                    ,bsky_did:str
                    ,bsky_username:str
                    ,wtm_tbl: dict | None = None
                    ,max_retries: int = 5
                    ,wait_period_increment_seconds: int=300) -> pd.DataFrame:
    
    data         = {col: [] for col in schema_input} 
    csr          = None
    pages_remain = True
    page_num     = 0
    watermark_crossed = False
    default_timezone = pytz.timezone('UTC')
    known_content_ids = set() # idk why but the same user will have the same posts repeated many times-- block em with a set

    # Iterate through every post in their account's post history
    while pages_remain and not watermark_crossed:
        # Retrieve a paginated post-feed for a specific bluesky user
        page_num += 1  
        retry_count = 0
        wait_period_seconds = 0
        # Calls made to BlueSky can get rate-limited
        # Retry when calls get blocked some number of times before giving up, linearly-increasing wait-period between retries 
        while retry_count <= max_retries:
            try:
                resp = bsky_client.get_author_feed(actor=bsky_did, cursor=csr)
                break
            except NetworkError:
                retry_count += 1
                if retry_count > max_retries:
                    raise NetworkError(f"Call to atproto.Client.get_author_feed() still blocked after {max_retries} attempts. Aborting.")
                wait_period_seconds += wait_period_increment_seconds
                print(f"Call for page {page_num:,} of user @{bsky_username}'s post data was blocked by Rate-Limiting.")
                print(f"Trying again in {wait_period_seconds:,} seconds (attempt {retry_count} of {max_retries})...")
                time.sleep(wait_period_seconds)
        # reverse-chron sort feed. This helps optimize our watermark logic
        feed = resp.feed
        for item in feed: 
            ts = timestamp_parser.parse(item.post.record.created_at)
            if not ts.tzinfo:
                ts = default_timezone.localize(ts)
            item.post.record.created_at = ts

        feed.sort(key=lambda item: item.post.record.created_at, reverse=True)
        print(f"Ingesting {page_num:,} pages of post-data from user @{bsky_username}...", end='\r')
        #
        # i drink your data! i DRINK IT UP ლಠ益ಠ)ლ
        # 
        for item in feed:
            if wtm_tbl:
                # WATERMARK STRATEGY-- don't ingest the same record more than once 
                watermark_ts = datetime(1900, 1, 1, 0, 0, 0, 0, pytz.utc) # default value
                try:
                    # look up the timestamp in the watermark table for the user who authored the post
                    watermark_ts = timestamp_parser.parse(wtm_tbl['post_created_timestamp'][wtm_tbl['post_author_did'].index(bsky_did)])
                except ValueError:
                    pass # watermark keeps default value if a later watermark for that user is not found

                if item.post.record.created_at <= watermark_ts:
                    watermark_crossed = True
                    print(f"\n\nHit high watermark for user {bsky_username}")
                    print(f"Encountered post creation timestamp is {datetime.strftime(item.post.record.created_at, '%Y-%m-%d %H:%M:%S.%f %z')}, latest known timestamp for this user is {datetime.strftime(watermark_ts, '%Y-%m-%d %H:%M:%S.%f %z')}")
                    break
            # idk why but the same user will have the same posts repeated many times-- block em with a set
            if item.post.cid not in known_content_ids:
            # if stash_user_posts() gets to this line, the given post has not been ingested before, so the program continues...        
                known_content_ids.add(item.post.cid)
                data['content_id'].append(item.post.cid)
                data['post_created_timestamp'].append(ts)
                data['post_uri'].append(item.post.uri)
                data['like_count'].append(item.post.like_count)
                data['quote_count'].append(item.post.quote_count)
                data['reply_count'].append(item.post.reply_count)
                data['repost_count'].append(item.post.repost_count)
                data['text'].append(item.post.record.text)
                data['tags'].append(item.post.record.tags)
                
                # post may or may not have external links
                try:
                    data['embedded_link_title'].append(item.post.record.embed.external.title)
                except AttributeError:
                    data['embedded_link_title'].append('null')
                try:
                    data['embedded_link_description'].append(item.post.record.embed.external.description)
                except AttributeError:
                    data['embedded_link_description'].append('null')
                try:
                    data['embedded_link_uri'].append(item.post.record.embed.external.uri)
                except AttributeError:
                    data['embedded_link_uri'].append('null')

                data['post_author_did'].append(bsky_did)
                data['post_author_username'].append(item.post.author.handle)
                data['post_author_displayname'].append(item.post.author.display_name)
                data['post_author_account_created_timestamp'].append(item.post.author.created_at) 
                
                # client details passed as input arg
                data['bluesky_client_account_did'].append(client_details.split('|')[0])
                data['bluesky_client_account_username'].append(client_details.split('|')[1])
                data['bluesky_client_account_displayname'].append(client_details.split('|')[2])
                
                data['bluesky_client_account_created_timestamp'].append(client_details.split('|')[3])
                ts = datetime.now(pytz.timezone('America/New_York')).astimezone(pytz.timezone('UTC'))
                data['record_captured_timestamp'].append(ts) 
        
        '''
        TODO -- Figure out why the below call never gets a "hit". It's like the only time
                that this .py file will write a CSV to disk is between one user and the next.

                This doesn't really make sense-- 99% of the time this program should be inside
                the `while` loop in this method. So you would think that the CSV write happens
                here, between one page and the next for the same user, and not after one 
                user finishes/before the next user is begun.
        '''
        if watermark_crossed:
            print("Ingestion for this user will now stop.\n")
            break
        _, data = chunk_check(schema_input=SCHEMA, dict_input=data)
        if not resp.cursor:
            pages_remain = False
        csr = resp.cursor        # reset cursor when another page of posts is available
    return pd.DataFrame(data)

# upload-csv-as-blob function
def upload_file_to_azr(file_to_upload: str, blob_name) -> None:
    
    # block potential cloud overwrites (check if a blob with a similar name exists)
    azr_files = [blob.name.split('/')[-1] for blob in AZR_CTR_CLI.list_blobs(name_starts_with=AZR_TGT_DIR.rstrip('/') + "/")]
    blob_name = f"{AZR_TGT_DIR.rstrip('/')}/{blob_name}"
    if blob_name.split('/')[-1] in azr_files:
        print(f"\nA blob with the name {blob_name.split('/')[-1]} already exists in the Azure Storage Location.\nSkipping the upload to avoid overwriting existing cloud data.\n")
        return None

    blob_cli = BLB_SVC_CLI.get_blob_client(container=AZR_TGT_CTR, blob=blob_name)

    try:
        # Create a BytesIO object from the string buffer
        buffer_bytes = BytesIO(file_to_upload.encode('utf-8'))

        # Upload the buffer to the blob
        blob_cli.upload_blob(buffer_bytes, overwrite=True)
        print(f"Uploaded buffer as blob: {blob_name}")

    except Exception as e:
        print(f"An error occurred during buffer upload: {e}")

# # THIS FUNCTION IS ONLY NEEDED IF YOU'RE RUNNING THE EXTRACTION ENTIRELY OUTSIDE OF AZURE
# def clear_local_dir() -> None:
#     # collect all filenames in blob dir, then limit the list of files to those labeled with the most recent date
#     azr_files = [blob.name.split('/')[-1] for blob in AZR_CTR_CLI.list_blobs()]
#     local_files = [file for file in os.listdir(C_AZR_SRC_DIR)]

#     for file in local_files:
#         if file in azr_files:
#             os.remove(f"{C_AZR_SRC_DIR}/{file}")
#         else:
#             print(f"File {file} detected locally but not detected in Azure Storage account!!\nYou may have some local data missing from the cloud. Consider reuploading.")
#     if len(os.listdir(C_AZR_SRC_DIR)) == 0:
#         os.rmdir(C_AZR_SRC_DIR)

# generate a control table for the "High-Watermark" strategy
# This is an incremental ingestion strategy-- it should ensure that the same record is never sent to the Azure Storage acct more than once
def write_watermark_table() -> bool: 
    azr_files = [blob.name for blob in AZR_CTR_CLI.list_blobs()]
    if len(azr_files) == 0:
        print(f"\n\nWARNING! WARNING! WARNING!\n\nZero CSV files found in Azure Blob directory {AZR_TGT_DIR}, container {AZR_TGT_CTR}")
        print("This means incremental ingestion will not be applied. If that is unexpected, then this run may be ingesting duplicate records.")
        print("If you don't want that, cancel this ingestion now with CTRL+C!\n")
        return False # Indicate watermark-write failure to function caller
    
    max_date = max([datetime.strptime(filename.split('/')[-1].split('_')[1], '%Y-%m-%d').date() for filename in azr_files])
    file_datestring = datetime.strftime(max_date, '%Y-%m-%d')
    azr_files = [file for file in azr_files if file_datestring in file]
    print(f"{len(azr_files):,} files with max date {max_date} detected in Azure Cloud Storage.\nDownloading files to generate watermark table...")
    df = pd.DataFrame(SCHEMA)
    for i in range(len(azr_files)):
        blob_client = BLB_SVC_CLI.get_blob_client(container=AZR_TGT_CTR, blob=azr_files[i])
        blob_data = blob_client.download_blob().readall()
        df_next = pd.read_csv(StringIO(blob_data.decode('utf-8')))
        if not df_next.empty:
            df = pd.concat([df, df_next])
        print(f"{i+1} of {len(azr_files)} max-date files downloaded from Azure")

    return df.groupby('post_author_did')['post_created_timestamp'].max().reset_index()
    
# Driver function
app = func.FunctionApp()

@app.timer_trigger(schedule="0 0 9 */2 * *", arg_name="myTimer", run_on_startup=False,
              use_monitor=False) 
def extract_feed(myTimer: func.TimerRequest) -> None:
    cli, session_usr = bluesky_login()
    
    # to collect information from bluesky, you need a bluesky client. 
    # to do that, you need to create a user (with a name, etc) to log into bluesky. the bluesky client session is then tied to this specific user
    # for completeness, information on the specific user we are logging in as should also be collected
    cli_did = get_did(cli, session_usr)
    resp = cli.get_profile(actor=cli_did)
    cli_username = session_usr
    cli_displayname = resp.display_name
    cli_account_created_at = resp.created_at
    cli_deets = f"{cli_did}|{cli_username}|{cli_displayname}|{cli_account_created_at}"
    
    # before parsing begins, write a control table locally
    # this should prevent records already saved in Azure from being ingested again
    print(f"Logging in as BlueSky User {USR}... \nLET'S GET THIS DATA! ( ͡⌐■ ͜ʖ ͡-■)\n\n")
    watermark_tbl = write_watermark_table()
    
    following_users = {item.handle: [item.did, item.display_name] for item in get_following_users(cli, session_usr)}
    print(f"Detected {len(following_users):,} BlueSky Users being followed by user @{session_usr}")
    print(f"Parsing posts...")
    df = None
    c = 0
    for usr in following_users:
        c += 1
        print(f"\n\n{str(c).zfill(3)} of {str(len(following_users)).zfill(3)} | Parsing posts from user @{usr}...")
        # accumulate data across the feeds of many users
        # stash_user_posts() will save CSV data should it hit the 100 mb threshold mid-ingestion for a single user
        if c == 1:
            df = stash_user_posts(cli_deets, schema_input=SCHEMA, bsky_client=cli, bsky_did=following_users[usr][0], bsky_username=usr, wtm_tbl=watermark_tbl)
        else:
            df_next = stash_user_posts(cli_deets, schema_input=SCHEMA, bsky_client=cli, bsky_did=following_users[usr][0], bsky_username=usr, wtm_tbl=watermark_tbl)
            if not df_next.empty:
                df = pd.concat([df, df_next])
                # if the 100 MB threshold is hit between users, stash the data at this point
                df, _ = chunk_check(schema_input=SCHEMA, dataframe_input=df)
    if len(df) > 0:
        # ensure any remaining data less than 100 MB is still written
        write_chunk(df)
    print(f"\nFeed Ingestion Complete! Uploading to Azure now...\n")
    
    files = [file for file in os.listdir(C_AZR_SRC_DIR) if file.endswith('.csv')]
    print(f"{len(files)} total CSV files detected.")
    for i in range(len(files)):
        print(f"\nUploading {files[i]}, {i+1} of {len(files)}")
        upload_file_to_azr(f"{C_AZR_SRC_DIR}/{files[i]}")
    print(f"File upload complete!")
    
    
    if myTimer.past_due:
        logging.info('The timer is past due!')

    logging.info('Python timer trigger function executed.')
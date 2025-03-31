from atproto import Client
from atproto.exceptions import NetworkError 
from azure.storage.blob import BlobServiceClient
import csv
from datetime import datetime
from dateutil import parser as timestamp_parser
import os
import pandas as pd
import pytz
import time
from typing import Tuple

# schema for all tabular data collected in this file
schema = {'content_id':                               []
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

# Instantiate a BlueSky session
def bluesky_login() -> Tuple[Client, str]:
    USR = os.getenv('BSY_USR').lower()
    KEY = os.getenv('BSY_KEY')
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
        output_path = os.getenv('AZR_SRC_DIR')
    # filename format is posts_<extraction_date>_<file_ordinal>.csv, where <final ordinal> is an incremental int
    # ex) If 3 files are generated on New Years Day 2025, the names are ['posts_2025-01-01_1.csv', 'posts_2025-01-01_2.csv', 'posts_2025-01-01_3.csv']
    rn = datetime.now().strftime('%Y-%m-%d')
    last_file_num = -1
    filename = f"{output_path}/posts_{rn}_"

    if os.path.exists(f"{output_path}/posts_{rn}_1.csv"):
        # get a list of ints where each item is the number just before the '.csv' part in the file name-- get CSV filenames only
        files = [int(file.split('_')[-1].split('.')[0]) for file in os.listdir(output_path) if file.split('.')[-1] == 'csv']
        files.sort()
        last_file_num = files[-1]+1 #increment by one
    elif not os.path.exists(output_path): 
        os.makedirs(output_path)

    if last_file_num > 0:
        filename += f"{last_file_num}.csv"
    else:
        filename += "1.csv"
    print(f"\nWriting {filename}...")
    df.to_csv(filename,
              index=False,
              encoding='utf-8',
              quoting=csv.QUOTE_ALL, # Wrap all fields in quotes -- hopefully this handles weird chars like line separators or paragraph separators
              quotechar='"',         
              escapechar='\\',       
              doublequote=True,      
              lineterminator='\n'    
             )           
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
def stash_user_posts(client_details: str, schema_input: dict, bsky_client:Client, bsky_did:str, bsky_username:str, max_retries: int = 5, wait_period_increment_seconds: int=300) -> pd.DataFrame:
    data         = {col: [] for col in schema_input} 
    csr          = None
    pages_remain = True
    page_num     = 0
    df           = pd.DataFrame()

    # Iterate through every post in their account's post history
    while pages_remain:
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
        
        feed = resp.feed
        print(f"Ingesting {page_num:,} pages of post-data from user @{bsky_username}...", end='\r')
        for item in feed:
            #
            # i drink your data! i DRINK IT UP ლಠ益ಠ)ლ
            # 
            data['content_id'].append(item.post.cid)
            data['post_uri'].append(item.post.uri)
            data['like_count'].append(item.post.like_count)
            data['quote_count'].append(item.post.quote_count)
            data['reply_count'].append(item.post.reply_count)
            data['repost_count'].append(item.post.repost_count)

            # extract timestamp strings as actual timestamps, including timezone
            ts = timestamp_parser.parse(item.post.record.created_at)
            data['post_created_timestamp'].append(ts)   

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

            # extract timestamp strings as actual timestamps, including timezone
            ts = timestamp_parser.parse(item.post.author.created_at)
            data['post_author_account_created_timestamp'].append(ts) 
            
            # client details passed as input arg
            data['bluesky_client_account_did'].append(client_details.split('|')[0])
            data['bluesky_client_account_username'].append(client_details.split('|')[1])
            data['bluesky_client_account_displayname'].append(client_details.split('|')[2])
            
            # extract timestamp strings as actual timestamps, including timezone
            ts = timestamp_parser.parse(client_details.split('|')[3])
            data['bluesky_client_account_created_timestamp'].append(ts)

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
        _, data = chunk_check(schema_input=schema, dict_input=data)
        if not resp.cursor:
            pages_remain = False
        csr = resp.cursor        # reset cursor when another page of posts is available
    return pd.DataFrame(data)

# upload-csv-as-blob function
def upload_file_to_azr(file_to_upload: str):
    azr_xct_str = os.getenv('AZR_XCT_STR')
    azr_container = os.getenv('AZR_TGT_CTR')
    azr_dir = os.getenv('AZR_TGT_DIR')
    blob_cli = BlobServiceClient.from_connection_string(azr_xct_str)
    container_cli = blob_cli.get_container_client(azr_container)
    blob_name = f"{azr_dir}/{os.path.basename(file_to_upload)}"
    blob_cli = container_cli.get_blob_client(blob_name)

    # Upload the file (supports large files via chunking)
    with open(file_to_upload, "rb") as data:
        blob_cli.upload_blob(data, overwrite=True)
        print(f"Uploaded file: {blob_name}")

# Driver function
def extract_feed() -> None:
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
            df = stash_user_posts(cli_deets, schema_input=schema, bsky_client=cli, bsky_did=following_users[usr][0], bsky_username=usr)
        else:
            df_next = stash_user_posts(cli_deets, schema_input=schema, bsky_client=cli, bsky_did=following_users[usr][0], bsky_username=usr)
            df = pd.concat([df, df_next])
            # if the 100 MB threshold is hit between users, stash the data at this point
            df, _ = chunk_check(schema_input=schema, dataframe_input=df)
    if len(df) > 0:
        # ensure any remaining data less than 100 MB is still written
        write_chunk(df)
    print(f"\nFeed Ingestion Complete! Uploading to Azure now...\n")
    source_dir = os.getenv('AZR_SRC_DIR')
    files = [file for file in os.listdir(source_dir) if file.endswith('.csv')]
    print(f"{len(files)} total CSV files detected.")
    
    for i in range(len(files)):
        print(f"\nUploading {files[i]}, {i+1} of {len(files)}")
        upload_file_to_azr(f"{source_dir}/{files[i]}")
    
    print(f"File upload complete!")

if __name__ == "__main__":
    extract_feed()
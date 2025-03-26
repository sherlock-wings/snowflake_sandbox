from atproto import Client
import csv
from datetime import datetime
import os
import pandas as pd
import pytz
import time

# string-typed timestamps come in many formats-- one function to parse them all
def parse_timestamp(timestamp_str, return_timezone: str='UTC'):
    # if the timezone is given in the timestamp, parse that into the final return
    if '-' in timestamp_str or '+' in timestamp_str:
        for tz_fmt in ('%Y-%m-%dT%H:%M:%S.%f%z','%Y-%m-%dT%H:%M:%S%z'):
            try:
                return datetime.strptime(timestamp_str, tz_fmt)
            except ValueError:
                continue
    # if the timezone has no timestamp, apply the requested timezone if available, else default to UTC time
    for no_tz_fmt in ('%Y-%m-%dT%H:%M:%S.%fZ', '%Y-%m-%dT%H:%M:%SZ', '%Y-%m-%dT%H:%M:%S'):
        try:
            ts = datetime.strptime(timestamp_str, no_tz_fmt)
            return pytz.timezone(return_timezone).localize(ts) 
        except ValueError:
            continue
    raise ValueError(f"Timestamp format not recognized: {timestamp_str}")

# Instantiate a BlueSky session
def bluesky_login():
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
def get_followers(bsky_client: Client, bsky_handle: str) -> list:
    bsky_did = get_did(bsky_client, bsky_handle)
    return bsky_client.get_follows(actor=bsky_did).follows


# write a chunk of post-data to CSV
def write_chunk(df: str, bsky_username: str, output_path: str='posts_output') -> None:
    # filename format is posts_<extraction_date>_<file_ordinal>.csv, where <final ordinal> is an incremental int
    # ex) If 3 files are generated on New Years Day 2025, the names are ['posts_2025-01-01_1.csv', 'posts_2025-01-01_2.csv', 'posts_2025-01-01_3.csv']
    rn = datetime.now().strftime('%Y-%m-%d')
    last_filenum = -1
    filename = ''

    if os.path.exists(f"{output_path}/{rn}_1.csv"):
        files = [int(file.split('_')[-1][0]) for file in os.listdir(output_path)]
        files.sort()
        last_filenum = files[-1]+1
    # if the first file for a given day 
    elif not os.path.exists(output_path): 
        os.makedirs(output_path)
    if last_filenum > 0:
        df.to_csv(df.to_csv(filename,
                            index=False,
                            encoding='utf-8',
                            quoting=csv.QUOTE_ALL,        # Wrap all fields in quotes
                            quotechar='"',                # Standard quote character
                            escapechar='\\',              # Escape special chars
                            doublequote=True,             # Handle existing quotes
                            lineterminator='\n'          # Standard line terminator
                            )
                 )



    dir   = f"output_data/usr_{bsky_username}"
    if not os.path.exists(dir):
        os.makedirs(dir)
    filename = f"{dir}/{bsky_username}.bsky.social_{start}_to_{end}.csv"
    

# write User Feed data as a series of one or more CSVs
def stash_feed(bsky_client: Client, bsky_did: str, bsky_username: str) -> None:
    schema = {'content_id':                       []
             ,'post_uri':                         []
             ,'like_count':                       []
             ,'quote_count':                      []
             ,'reply_count':                      []
             ,'repost_count':                     []
             ,'post_created_timestamp':           []
             ,'text':                             []
             ,'tags':                             []
             ,'embedded_link_title':              []
             ,'embedded_link_description':        []
             ,'embedded_link_uri':                []
             ,'author_username':                  []
             ,'author_displayname':               []
             ,'author_account_created_timestamp': []
             ,'record_captured_timestamp':        []
             }
    data = schema 
    
    csr          = None
    pages_remain = True
    filenum      = 0
    page_num     = 0
    
    # Iterate through every post in their account's post history
    while pages_remain:
        
        # # check if the current file is already "full" (larger than 100 MB)
        # # if it is, stash the current data object as CSV and reset a new empty one
        df = pd.DataFrame(data)
        if df.memory_usage(deep=True).sum() / (1024*1024) >= 100:
            filenum+=1
            write_chunk(df, bsky_username)
            data = schema
            del df # No need to lock up memory while the next instance of `data` is filling up...
        
        # Retrieve a paginated post-feed for a specific bluesky user
        page_num += 1  
        resp      = bsky_client.get_author_feed(actor=bsky_did, cursor=csr)
        feed      = resp.feed
        print(f"Retrieving post data from page {page_num} for user @{bsky_username}.bsky.social...", end='\r')
        for item in feed:
            # i drink your data! i DRINK IT UP ლಠ益ಠ)ლ
            data['content_id'].append(item.post.cid)
            data['post_uri'].append(item.post.uri)
            data['like_count'].append(item.post.like_count)
            data['quote_count'].append(item.post.quote_count)
            data['reply_count'].append(item.post.reply_count)
            data['repost_count'].append(item.post.repost_count)

            # extract timestamp strings as actual timestamps, including timezone
            # ts = datetime.strptime(item.post.record.created_at, '%Y-%m-%dT%H:%M:%S.%fZ')
            ts = parse_timestamp(item.post.record.created_at)
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
            data['author_username'].append(item.post.author.handle)
            data['author_displayname'].append(item.post.author.display_name)

            # extract timestamp strings as actual timestamps, including timezone
            # ts = datetime.strptime(item.post.author.created_at, '%Y-%m-%dT%H:%M:%S.%fZ')
            ts = parse_timestamp(item.post.author.created_at)
            data['author_account_created_timestamp'].append(ts) 

            ts = datetime.now(pytz.timezone('America/New_York')).astimezone(pytz.timezone('UTC'))
            data['record_captured_timestamp'].append(ts) 
            
        if not resp.cursor:
            pages_remain = False
        
        csr = resp.cursor        # reset cursor when another page of posts is available
    
    df = pd.DataFrame(data)
    
    if len(df) > 0:
        write_chunk(df, bsky_username)

# Driver function
def extract_feed() -> None:
    cli, session_usr = bluesky_login()
    followed_users = {item.handle: [item.did, item.display_name] for item in get_followers(cli, session_usr)}
    print(f"Detected {len(followed_users):,} BlueSky Users being followed by user @{session_usr}")
    print(f"Parsing posts...\n")
    c = 0
    for usr in followed_users:
        c += 1
        print(f"\n{str(c).zfill(3)} of {str(len(followed_users)).zfill(3)} | Parsing posts from user @{usr}...\n")
        stash_feed(bsky_client=cli, bsky_did=followed_users[usr][0], bsky_username=usr)
    print(f"Feed Ingestion Complete!")

if __name__ == "__main__":
    extract_feed()
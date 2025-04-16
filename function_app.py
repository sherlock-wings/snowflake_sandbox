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

###
### AZURE CONFIG
###

# instantiate blob Service Client (dependency of container client)
AZR_DFT_CRD = DefaultAzureCredential()
AZR_ACT_URL = f"https://{os.environ['AZR_STR_ACT']}.blob.core.windows.net"
BLB_SVC_CLI = BlobServiceClient(AZR_ACT_URL, AZR_DFT_CRD)

# instantiate container client (needed for reads/writes of blob data to/from bluesky_posts azr directory)
AZR_TGT_CTR = os.environ['AZR_TGT_CTR']
AZR_CTR_CLI = BLB_SVC_CLI.get_container_client(AZR_TGT_CTR)
C_AZR_SRC_DIR = os.environ['C_AZR_SRC_DIR']
AZR_TGT_DIR = f"{os.environ['AZR_TGT_DIR']}/"  # apparently a trailing slash is required? 


###
### BLUESKY CLIENT CONFIG
###

USR = os.environ['BSY_USR'].lower()
KEY = os.environ['BSY_KEY']

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
L_XTR_DIR = os.environ['L_XTR_DIR']

app = func.FunctionApp()

@app.timer_trigger(schedule="1 1 1 1 1 1", arg_name="myTimer", run_on_startup=False,
              use_monitor=False) 
def timer_trigger(myTimer: func.TimerRequest) -> None:
    if myTimer.past_due:
        logging.info('The timer is past due!')

    logging.info('Python timer trigger function executed.')
git@github.com:sherlock-wings/snowflake_sandbox.git
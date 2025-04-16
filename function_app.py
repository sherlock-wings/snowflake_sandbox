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

app = func.FunctionApp()

@app.timer_trigger(schedule="1 1 1 1 1 1", arg_name="myTimer", run_on_startup=False,
              use_monitor=False) 
def timer_trigger(myTimer: func.TimerRequest) -> None:
    if myTimer.past_due:
        logging.info('The timer is past due!')

    logging.info('Python timer trigger function executed.')
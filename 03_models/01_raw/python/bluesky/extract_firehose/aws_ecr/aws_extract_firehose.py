import asyncio
import websockets
import json
from datetime import datetime
import boto3
from io import BytesIO
import os

uri = os.getenv('JETSTREAM_URI')
S3_BUCKET_NAME = os.getenv('AWS_TGT_BKT')
S3_TARGET_FOLDER = os.getenv('AWS_TGT_DIR')
AWS_REGION = "us-east-2"
SCOOP_RUNTIME_IN_SECONDS = os.getenv('SCOOP_RUNTIME_IN_SECONDS')  

# Initialize the S3 client
s3_client = boto3.client('s3', region_name=AWS_REGION)

async def firehose_scoop(capture_mode: str, SCOOP_RUNTIME_IN_SECONDS: int = 300) -> None:
    """
    Asynchronous function to "scoop" a portion of post data from Bluesky Firehose, which is
    a kind of streaming service offering realtime post data. Output data is captured as 
    .jsonl files and uploaded to S3. The "scoop size" is 

    Args:
        capture_mode: A string-labeled that indicates, for each row of collected data,
                      whether the data was collected as part of a regularly scheduled
                      run, or if it was part of a test run. 
                      This is a field directly added to the collected data.
    
    Function is controlled by global constants that specify 
        - The target bucket in S3
        - The AWS Region
        - The max file size for each .jsonl file 
    """
    # write in-memory data to a Bytes Buffer
    in_memory_data = BytesIO()
    current_memory_size = 0
    file_completed = False

    try:
        async with websockets.connect(uri) as websocket:
            print(f"Opened websocked at {datetime.now(datetime.timezone.utc).strftime('%Y-%m-%d %H:%M:%S %z')}.\nListening for posts...")
            opened_at = datetime.now(datetime.timezone.utc)
            while not file_completed:
                message = await websocket.recv()
                message_bytes = len(message.encode('utf-8'))
                # Write the message to the in-memory buffer
                in_memory_data.write(message.encode('utf-8'))
                in_memory_data.write(b'\n')              # Add newline for JSON Lines format
                current_memory_size += message_bytes + 1 # +1 bc of the newline that must be added for each JSON paylod
                
                if (datetime.now(datetime.timezone.utc)-opened_at).seconds % 10 == 0:
                    print(f"{(current_memory_size/1000000):,.2f} MB collected over {(datetime.now(datetime.timezone.utc)-opened_at).seconds} seconds...")
                    
                # continually check to see if the timer is expired
                if (datetime.now(datetime.timezone.utc) - opened_at).seconds >= SCOOP_RUNTIME_IN_SECONDS:
                    closed_at = datetime.now(datetime.timezone.utc)
                    s3_key = f"{S3_TARGET_FOLDER}/{capture_mode}_{opened_at.strftime('%Y%m%d_%H%M%S%Z')}_to_{closed_at.strftime('%Y%m%d_%H%M%S%Z')}.jsonl"
                    in_memory_data.seek(0)  # Go to the beginning of the buffer
                    try:
                        # write raw JSON to .jsonl in S3
                        s3_client.upload_fileobj(in_memory_data, S3_BUCKET_NAME, s3_key)
                        print(f"Uploaded {s3_key} to S3")
                        file_completed = True
                    except Exception as e:
                        print(f"Error uploading to S3: {e}")

    except websockets.ConnectionClosed as e:
        print(f"Connection closed: {e}")
    except Exception as e:
        print(f"Error: {e}")

def lambda_handler(event, context, capture_mode: str='SCHEDULED RUN') -> None:
    """
    Handler method. This is what will be directly called by AWS Lambda
    Args:
        event: idk AWS made me put it here
        context: idk AWS made me put it here
    """
    asyncio.run(firehose_scoop(capture_mode))
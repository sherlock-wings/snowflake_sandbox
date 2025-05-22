import asyncio
import websockets
import json
from datetime import datetime
import boto3
from io import BytesIO
import os

uri = os.get_env('JETSTREAM_URI')
S3_BUCKET_NAME = os.getenv('AWS_TGT_BKT')
S3_TARGET_FOLDER = os.getenv('AWS_TGT_DIR')
AWS_REGION = "us-east-2"
SCOOP_RUNTIME_IN_SECONDS = os.getenv('SCOOP_RUNTIME_IN_SECONDS')  

# Initialize the S3 client
s3_client = boto3.client('s3', region_name=AWS_REGION)

async def firehose_scoop(SCOOP_RUNTIME_IN_SECONDS: int = 300) -> None:
    """
    Asynchronous function to "scoop" a portion of post data from Bluesky Firehose, which is
    a kind of streaming service offering realtime post data. Output data is captured as 
    .jsonl files and uploaded to S3. The "scoop size" is 

    Args:
        None
    
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
            print(f"Opened websocked at {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}.\nListening for posts...")
            opened_at = datetime.now()
            while not file_completed:
                message = await websocket.recv()
                message_bytes = len(message.encode('utf-8'))
                # Write the message to the in-memory buffer
                in_memory_data.write(message.encode('utf-8'))
                in_memory_data.write(b'\n')              # Add newline for JSON Lines format
                current_memory_size += message_bytes + 1 # +1 bc of the newline that must be added for each JSON paylod
                print(f"{(current_memory_size/1000000):,.2f} MB collected over {(datetime.now()-opened_at).seconds} seconds...", end='\r')
                
                # continually check to see if the timer is expired
                if (datetime.now() - opened_at).seconds >= SCOOP_RUNTIME_IN_SECONDS:
                    s3_key = f"{S3_TARGET_FOLDER}/firehose_posts_{opened_at.strftime('%Y%m%d_%H%M%S')}.jsonl"
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

def lambda_handler() -> None:
    """
    Handler method. This is what will be directly called by AWS Lambda
    Args:
        None
    """
    asyncio.run(firehose_scoop())
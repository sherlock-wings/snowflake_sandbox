import asyncio
import websockets
import json
from datetime import datetime
import boto3
from io import BytesIO
import os

# Replace with your S3 bucket name and AWS credentials/configuration
uri = "wss://jetstream2.us-east.bsky.network/subscribe?wantedCollections=app.bsky.feed.post"
S3_BUCKET_NAME = os.getenv('AWS_TGT_BKT')
S3_TARGET_FOLDER = os.getenv('AWS_TGT_DIR')
AWS_REGION = "us-east-2"  # e.g., "us-east-1"
MAX_IN_MEMORY_SIZE_MB = 1
MAX_IN_MEMORY_BYTES = MAX_IN_MEMORY_SIZE_MB * 1024 * 1024

# Initialize the S3 client (ensure your AWS environment is configured)
s3_client = boto3.client('s3', region_name=AWS_REGION)

async def firehose_scoop() -> None:
    """
    Asynchronous function to "scoop" a portion of post data from Bluesky Firehose, which is
    a kind of streaming service offering realtime post data. Output data is captured as 
    .jsonl files and uploaded to S3.

    Args:
        None
    
    Function is controlled by global constants that specify 
        - The target bucket in S3
        - The AWS Region
        - The max file size for each .jsonl file 
    """

    in_memory_data = BytesIO()
    current_memory_size = 0
    file_counter = 1
    file_completed = False

    try:
        async with websockets.connect(uri) as websocket:
            while not file_completed:
                print(f"The current val for file_completed is {file_completed}")
                message = await websocket.recv()
                message_bytes = len(message.encode('utf-8'))
                print('Listening for posts...')
                print(f"Current memory size is {current_memory_size + message_bytes} bytes")
                if current_memory_size + message_bytes > MAX_IN_MEMORY_BYTES:
                    # Upload to S3
                    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
                    s3_key = f"{S3_TARGET_FOLDER}/firehose_posts_{timestamp}.jsonl"
                    in_memory_data.seek(0)  # Go to the beginning of the buffer
                    try:
                        s3_client.upload_fileobj(in_memory_data, S3_BUCKET_NAME, s3_key)
                        print(f"Uploaded {s3_key} to S3")
                        file_completed = True
                    except Exception as e:
                        print(f"Error uploading to S3: {e}")

                    # Reset in-memory buffer and size
                    in_memory_data = BytesIO()
                    current_memory_size = 0
                    file_counter += 1

                # Write the message to the in-memory buffer
                in_memory_data.write(message.encode('utf-8'))
                in_memory_data.write(b'\n')  # Add newline for JSON Lines format
                current_memory_size += message_bytes + 1  # +1 for the newline byte

    except websockets.ConnectionClosed as e:
        print(f"Connection closed: {e}")
    except Exception as e:
        print(f"Error: {e}")
    # finally:
    #     # Upload any remaining data in memory
    #     if current_memory_size > 0:
    #         timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    #         s3_key = f"bluesky_posts_{timestamp}_{file_counter}.jsonl"
    #         in_memory_data.seek(0)
    #         try:
    #             s3_client.upload_fileobj(in_memory_data, S3_BUCKET_NAME, s3_key)
    #             print(f"Uploaded final data as {s3_key} to S3")
                
    #             print(f"The current val for file_completed is {file_completed}")
    #         except Exception as e:
    #             print(f"Error uploading final data to S3: {e}")

if __name__ == "__main__":
    asyncio.run(firehose_scoop())
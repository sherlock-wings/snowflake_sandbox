import asyncio
import datetime as dt
import websockets
import json

uri = "wss://jetstream2.us-east.bsky.network/subscribe?wantedCollections=app.bsky.feed.post"
OUTPUT_FILENAME = "bluesky_posts.jsonl"  # Using .jsonl for newline-delimited JSON

async def listen_to_websocket(max_file_size_mb=1):
    max_bytes = max_file_size_mb * 1024 * 1024
    current_file_size = 0
    file = None

    try:
        async with websockets.connect(uri) as websocket:
            while True:
                message = await websocket.recv()
                message_bytes = len(message.encode('utf-8'))

                if file is None or (current_file_size + message_bytes > max_bytes):
                    if file:
                        file.close()
                    timestamp = dt.datetime.now().strftime("%Y%m%d_%H%M%S")
                    new_filename = f"bluesky_posts_{timestamp}.jsonl"
                    file = open(new_filename, 'w', encoding='utf-8')
                    current_file_size = 0
                    print(f"Opened new file: {new_filename}")

                file.write(message + '\n')  # Write each JSON object on a new line
                current_file_size += message_bytes

    except websockets.ConnectionClosed as e:
        print(f"Connection closed: {e}")
    except Exception as e:
        print(f"Error: {e}")
    finally:
        if file:
            file.close()
            print("Finished writing to file.")

if __name__ == "__main__":
    import datetime
    asyncio.run(listen_to_websocket())
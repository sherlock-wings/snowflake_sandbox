from atproto import Client
import os
 
USR = os.getenv('BSY_USR').lower()
KEY = os.getenv('BSY_KEY')

print(f"Retrieved env vars $USR = {USR} and $KEY = {KEY}")

cli = Client()
cli.login(USR, KEY)
from atproto import Client
import os
 
USR = os.getenv('BSY_USR').lower()
KEY = os.getenv('BSY_KEY')

cli = Client()
cli.login(USR, KEY)

data = cli.get_timeline(limit=1)
feed = data.feed
print(feed[0]['post']['record'])
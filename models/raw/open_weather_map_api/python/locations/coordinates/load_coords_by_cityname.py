import os
import requests
import pandas as pd

# In order to get weather for a specific loaction from the OpenWeatherMap API, you need to pass in lat & long coordinates.
# They provide another API, the Geocoding API, to get that information. 

api_key = os.getenv("owm_brx")
if not api_key:
    raise ValueError("The API Key for the OpenWeatherMap API is not set in your Environment Variables.")

src_name = pd.read_csv('target_cities.csv')
tgt_ls = src_name['city_name'].values
responses = []

for city in tgt_ls:
    geo_url = 'http://api.openweathermap.org/geo/1.0/direct?q='+city+'&limit=5&appid='+api_key
    response = requests.get(url=geo_url)
    responses.append(response.json())

output = pd.DataFrame({'city_name_input':tgt_ls, 'api_json_respnose':responses})
output.to_csv('geo_api_lat_long_output.csv', index= False )
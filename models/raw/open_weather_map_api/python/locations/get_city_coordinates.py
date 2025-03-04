import ast
import pandas as pd

data = pd.read_csv('C:/Users/patri/OneDrive/Desktop/work/snowflake_sandbox/models/raw/open_weather_map_api/python/locations/coordinates/geo_api_lat_long_output.csv')
json_ls = [ast.literal_eval(item)[0] if item!= '[]' else None for item in data['api_json_respnose'].values]

lats = [json_item['lat'] if isinstance(json_item, dict) else None for json_item in json_ls]
data['latitude'] = lats

longs = [json_item['lon'] if isinstance(json_item, dict) else None for json_item in json_ls]
data['longitude'] = longs

nations = [json_item['country'] if isinstance(json_item, dict) else None for json_item in json_ls]
data['iso_2_letter_country_code'] = nations

data = pd.merge(data
               ,pd.read_csv('C:/Users/patri/OneDrive/Desktop/work/snowflake_sandbox/models/raw/open_weather_map_api/python/locations/names/iso_country_codes.csv')
               ,left_on='iso_2_letter_country_code'
               ,right_on='iso_2_letter_code'
               )
data = data[['city_name_input', 'latitude', 'longitude', 'country_name', 'iso_2_letter_country_code']]
data = data.rename(columns={ 'city_name_input':'city_name', 'iso_2_letter_country_code':'country_code' })
data.to_csv('C:/Users/patri/OneDrive/Desktop/work/snowflake_sandbox/models/raw/open_weather_map_api/python/locations/coordinates_by_city.csv'
            ,index=False
           )
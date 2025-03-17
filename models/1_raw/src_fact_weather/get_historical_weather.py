import os
import pandas as pd
import requests

PROJECT_DIR = os.getenv('PROJECT_DIR')
API_KEY = os.getenv("OWM_KEY")
if not API_KEY:
    raise ValueError("The API Key for the OpenWeatherMap API is not set in your Environment Variables.")

dat_city = pd.read_csv(PROJECT_DIR+'/models/1_raw/src_dim_city/6_output_src_dim_city.csv')
print(cities.head(10))



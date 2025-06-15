import spacy
from spacy.lang.en import stop_words
import pandas as pd

# this is a language pack-- it is not on your machine by default
# after doing `pip install spacy`, run this
# python -m spacy download en_core_web_sm
# that allows the next line to work
nlp = spacy.load('en_core_web_sm')

stop_words_ls = stop_words.STOP_WORDS
stop_words_ls = [word.replace('‘', "'").replace("’", "'").replace('"', "'") for word in stop_words_ls]
tmp = set(stop_words_ls)
stop_words_ls = list(tmp)
stop_words_ls.append("'t")
stop_words_ls.sort()

index = 0 
data = {'id': [], 'stopword': []}

for i in range(len(stop_words_ls)):
    data['id'].append(i)
    data['stopword'].append(stop_words_ls[i])

data = pd.DataFrame(data)
data.to_csv('stopwords.csv', index=False) 

# upload CSV to snowflake at your desired namespace
# I used table name TMP_STOPWORDS_LIST
# # Then once the table exists you can do this SQL to inser it into a final STOPWORDS table
# create or replace TABLE BLUESKY_DB.PFC.STOPWORDS_LIST (
# 	LIST_VALS VARIANT
# );
# insert into stopwords_list (
# select split(listagg(stopword, ','), ',') as list_vals
# from BLUESKY_DB.PFC.TMP_STOPWORDS_LIST
# );

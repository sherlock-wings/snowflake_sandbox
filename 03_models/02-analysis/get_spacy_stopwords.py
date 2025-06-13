import spacy
from string import punctuation
from spacy.lang.en import stop_words
from re import sub as regex_sub


nlp = spacy.load('en_core_web_sm')

stop_words_str = ('|').join(stop_words.STOP_WORDS).replace("’", "'").replace('‘', "'").replace("'", "\\\'")


if __name__ == '__main__':
    print(stop_words_str)
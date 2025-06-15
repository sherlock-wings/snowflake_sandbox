create or replace function remove_stopwords(stopword_list variant, input_text varchar)
returns variant
language python
runtime_version = '3.9'
handler = 'remove_stopwords'
as $$
import re

def remove_stopwords(stopword_list: list, POST_TEXT: str):
    special_char_pat = r'[\\\`\~\!\@\#\$\%\^\&\*\(\)\-\_\+\=\/\<\>\,\.\|\[\]\{\}]+'
    POST_TEXT = re.sub(special_char_pat, '', POST_TEXT).lower().split()
    txt_ls = []
    for i in range(len(POST_TEXT)):
        if "'" in POST_TEXT[i]:
            pair = POST_TEXT[i].split("'")
            newval = "'" + pair[1]
            txt_ls.append(pair[0])
            txt_ls.append(newval)
        else:
            txt_ls.append(POST_TEXT[i])
    return [word for word in txt_ls if word not in stopword_list]
$$;
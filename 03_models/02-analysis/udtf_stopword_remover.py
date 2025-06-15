import re


def remove_stopwords(stopword_list: list, POST_TEXT: str):
    POST_TEXT = re.sub(r"[\.,\!\?]", '', POST_TEXT).lower().split()
    txt_ls = []
    for i in range(len(POST_TEXT)):
        if "'" in POST_TEXT[i]:
            pair = POST_TEXT[i].split("'")
            newval_1 = pair[0]
            newval_2 = "'" + pair[1]
            txt_ls.append(newval_1)
            txt_ls.append(newval_2)
        else:
            txt_ls.append(POST_TEXT[i])
    return [word for word in txt_ls if word not in stopword_list]
    
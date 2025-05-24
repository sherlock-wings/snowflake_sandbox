FROM python:3.9-slim-buster
WORKDIR /aws_app
COPY requirements.txt /aws_app/
RUN useradd -ms /bin/bash bluesky_extractor_usr
USER bluesky_extractor_usr
RUN pip install --no-cache-dir -r /aws_app/requirements.txt
COPY . /aws_app/
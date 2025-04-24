FROM python:3.9-slim-buster
WORKDIR /aws_app
COPY requirements.txt /aws_app/
RUN pip install --no-cache-dir -r /aws_app/requirements.txt
COPY . /aws_app/
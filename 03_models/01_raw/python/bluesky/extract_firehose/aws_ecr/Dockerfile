FROM public.ecr.aws/lambda/python:3.9

COPY requirements.txt .
RUN pip install -r requirements.txt

COPY aws_extract_firehose.py .

CMD [ "aws_extract_firehose.lambda_handler" ]

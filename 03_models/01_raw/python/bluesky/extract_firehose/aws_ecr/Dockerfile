FROM public.ecr.aws/lambda/python:3.12

# Set the working directory inside the container
WORKDIR /app

# Copy your Python script into the container
COPY aws_extract_firehose.py .

# Copy your requirements file if you have one
COPY requirements.txt .

# Install any dependencies
RUN pip install -r requirements.txt

# Set the command to run your script when the container starts
CMD ["your_script.lambda_handler"]
FROM public.ecr.aws/lambda/python:3.12

# Copy your requirements file into the container
# This is usually done first to leverage Docker's build cache if requirements.txt doesn't change
COPY requirements.txt ${LAMBDA_TASK_ROOT}/

# Install any dependencies into the Lambda task root
RUN pip install -r ${LAMBDA_TASK_ROOT}/requirements.txt --target "${LAMBDA_TASK_ROOT}"

# Copy your Python script into the Lambda task root
COPY aws_extract_firehose.py ${LAMBDA_TASK_ROOT}/

# Set the command to run your script when the container starts
# The format is "your_script_filename_without_py_extension.your_handler_function_name"
CMD ["aws_extract_firehose.lambda_handler"]


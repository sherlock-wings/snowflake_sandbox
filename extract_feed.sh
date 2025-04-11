#!/bin/bash

PYTHON_SCRIPT=$L_XTR_DIR
LOG_DIR="$PYTHON_SCRIPT/extract_logs/"                  
TIMESTAMP=$(date +'%Y-%m-%d_%H-%M-%S')   
LOG_FILE="${LOG_DIR}/extract_feed_${TIMESTAMP}.log" 

# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR"

# Check if Python is installed
if ! command -v python3 &> /dev/null
then
    echo "Python3 could not be found. Please install Python3."
    exit 1
fi

# Check if the script exists
if [ ! -f "$PYTHON_SCRIPT" ]; then
    echo "Python script not found at $PYTHON_SCRIPT"
    exit 1
fi

echo "Python script: $PYTHON_SCRIPT" | tee -a "$LOG_FILE"
echo "Log file: $LOG_FILE" | tee -a "$LOG_FILE"

# Run the Python script and log everything
python3 "$PYTHON_SCRIPT" 2>&1 | tee -a "$LOG_FILE"

# Check if the script ran successfully
if [ $? -eq 0 ]; then
    echo "Python script executed successfully"
else
    echo "Python script failed to execute"
    exit 1
fi
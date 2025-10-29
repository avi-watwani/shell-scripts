#!/bin/bash

# --- Configuration ---
# IMPORTANT: Change this to your S3 bucket name
BUCKET_NAME="journal-entries-v2"
# URL expiration time in seconds (e.g., 900 = 15 minutes, 3600 = 1 hour)
URL_EXPIRATION=900
# --- End Configuration ---

# 1. Fetch a random object key from the bucket
echo "Fetching a random object from bucket: $BUCKET_NAME..."

# Cross-platform random selection
if command -v shuf &> /dev/null; then
  # Linux: use shuf
  RANDOM_KEY=$(aws s3api list-objects-v2 --bucket "$BUCKET_NAME" --query "Contents[].Key" --output json | jq -r '.[]' | shuf -n 1)
elif command -v gshuf &> /dev/null; then
  # macOS with GNU coreutils: use gshuf
  RANDOM_KEY=$(aws s3api list-objects-v2 --bucket "$BUCKET_NAME" --query "Contents[].Key" --output json | jq -r '.[]' | gshuf -n 1)
else
  # macOS/BSD: use sort -R (random sort)
  RANDOM_KEY=$(aws s3api list-objects-v2 --bucket "$BUCKET_NAME" --query "Contents[].Key" --output json | jq -r '.[]' | sort -R | head -n 1)
fi

# 2. Check if an object key was actually found
if [[ -z "$RANDOM_KEY" ]]; then
  echo "Error: Could not find a random object. Is the bucket empty or do you lack s3:ListBucket permissions?"
  exit 1
fi

echo "Selected object: $RANDOM_KEY"
echo ""

# 3. Generate the presigned URL using the configuration variable
echo "Generating presigned URL (expires in $URL_EXPIRATION seconds)..."
PRESIGNED_URL=$(aws s3 presign "s3://${BUCKET_NAME}/${RANDOM_KEY}" --expires-in "$URL_EXPIRATION")

# 4. Check if the URL was generated successfully
if [[ -z "$PRESIGNED_URL" ]]; then
  echo "Error: Failed to generate a presigned URL. Check your AWS credentials and s3:GetObject permissions."
  exit 1
fi

# 5. Print the URL for reference
echo ""
echo "=================================================="
echo "Your random object link:"
echo "$PRESIGNED_URL"
echo "=================================================="
echo ""

# 6. Attempt to open the URL in the default browser (Cross-platform)
echo "Attempting to open the link in your default browser..."

# Use the correct command based on the operating system
if [[ "$(uname)" == "Darwin" ]]; then
  # macOS
  open "$PRESIGNED_URL"
elif [[ "$(uname -r)" == *"Microsoft"* || "$(uname -r)" == *"WSL"* ]]; then
  # Windows Subsystem for Linux (WSL)
  explorer.exe "$PRESIGNED_URL"
elif [[ "$(uname)" == "Linux" ]]; then
  # Native Linux (requires xdg-utils to be installed)
  if command -v xdg-open &> /dev/null; then
    xdg-open "$PRESIGNED_URL"
  else
    echo "Could not find 'xdg-open'. Please open the link above manually."
  fi
else
  echo "Unsupported OS for auto-opening. Please open the link above manually."
fi


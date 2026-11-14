# AWS Emulator: AWS CLI demos

Start one AWS Emulator container, then use familiar `aws` commands to try **S3**, **DynamoDB**, and **SQS** locally. An optional tiny Python example writes and reads the same DynamoDB table. No AWS account is needed.

Run the commands below in **Bash** on Linux, macOS, or Ubuntu WSL. Install Docker, AWS CLI v2, and curl first. If Docker runs inside WSL, keep the Ubuntu terminal open during the demo.

## 1. Start AWS Emulator

Build the image using the included Dockerfile:

```bash
docker build -t aws-emulator .
mkdir -p "$HOME/.aws/emulator"

docker run -d --rm --name aws-emulator-demo \
  --user "$(id -u):$(id -g)" \
  --memory=2g --memory-swap=2g \
  -p 127.0.0.1:9297:9297 \
  -e HOME="$HOME" -e EMULATOR_TELEMETRY=off \
  -v "$HOME/.aws/emulator:$HOME/.aws/emulator" \
  aws-emulator -p 9297
```

The Dockerfile uses x86_64. On ARM, change the RPM filename to `aws-emulator-aarch64.rpm` before building.

Configure the current shell to use the emulator's local endpoint, generated credentials, and certificate:

```bash
source scripts/env.sh
aws sts get-caller-identity --output table
```

Check that `Account` is **`000000000000`** before continuing. All subsequent `aws` commands in this shell use `https://127.0.0.1:9297`. The helper waits for startup and configures the shell; the demos below are plain AWS CLI commands.

The helper also sets `AWS_DEFAULT_OUTPUT=table` for readable output in this shell. Use `--query` to select columns, or override a command with `--output json` / `--output text` when needed.

## 2. S3: upload, download, and delete a file

```bash
# Create a bucket and list buckets.
aws s3 mb s3://demo-bucket
aws s3api list-buckets --query 'Buckets[].{Bucket:Name}' --output table

# Upload a file and list the bucket's objects.
printf 'Hello S3!\n' > hello.txt
aws s3 cp hello.txt s3://demo-bucket/hello.txt
aws s3api list-objects-v2 --bucket demo-bucket \
  --query 'Contents[].{File:Key,Bytes:Size}' --output table

# Download and read the file.
aws s3 cp s3://demo-bucket/hello.txt downloaded.txt
cat downloaded.txt

# Delete the file, confirm the bucket is empty, and remove the bucket.
aws s3 rm s3://demo-bucket/hello.txt
aws s3api list-objects-v2 --bucket demo-bucket \
  --query 'Contents[].{File:Key,Bytes:Size}' --output table
aws s3 rb s3://demo-bucket
```

The downloaded file should contain `Hello S3!`. Listing the bucket after deletion should show no objects.

`aws s3 ls` uses its own text format and ignores `--output`. The `s3api` list commands above support table output; `aws s3 cp`, `rm`, and `rb` keep their normal progress/status messages.

## 3. DynamoDB: write, read, and delete an item

```bash
# Create a table with a string partition key named id.
aws dynamodb create-table --table-name demo-table \
  --attribute-definitions AttributeName=id,AttributeType=S \
  --key-schema AttributeName=id,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --query 'TableDescription.{Table:TableName,Status:TableStatus}' --output table

aws dynamodb wait table-exists --table-name demo-table
aws dynamodb list-tables --output table

# Write an item.
aws dynamodb put-item --table-name demo-table \
  --item '{"id":{"S":"1"},"message":{"S":"Hello DynamoDB!"}}'

# Read it back.
aws dynamodb get-item --table-name demo-table \
  --key '{"id":{"S":"1"}}' --consistent-read \
  --query 'Item.{ID:id.S,Message:message.S}' --output table

# Delete the item and read again: the result should contain no Item.
aws dynamodb delete-item --table-name demo-table --key '{"id":{"S":"1"}}'
aws dynamodb get-item --table-name demo-table --key '{"id":{"S":"1"}}' --consistent-read \
  --query 'Item.{ID:id.S,Message:message.S}' --output table

```

DynamoDB uses `{"S":"value"}` to represent a string in these low-level API commands.

The read query flattens those types into `ID` and `Message` columns. After deletion, the same query has no item to display.

### Additional: Read and write DynamoDB data with Python

Requires Python 3 with venv support. Keep the emulator running and use the same terminal with `scripts/env.sh` sourced. Run this before deleting `demo-table`:

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements.txt
python dynamodb_read_write.py
```

[The Python example](dynamodb_read_write.py) uses Boto3's table resource to write a plain dictionary and read it back. It should print:

```text
WRITE: {'id': 'python-1', 'message': 'Hello from Python!'}
READ: {'id': 'python-1', 'message': 'Hello from Python!'}
```

When finished with the CLI and optional Python example, remove the table:

```bash
aws dynamodb delete-table --table-name demo-table \
  --query 'TableDescription.{Table:TableName,Status:TableStatus}' --output table
```

## 4. SQS: send, receive, and delete a message

```bash
# Create a queue and save its returned URL.
QUEUE_URL=$(aws sqs create-queue --queue-name demo-queue --query QueueUrl --output text)
aws sqs list-queues --output table

# Send a message.
aws sqs send-message --queue-url "$QUEUE_URL" --message-body 'Hello SQS!' \
  --query '{MessageId:MessageId}' --output table

# Receive it. Copy the ReceiptHandle from the output.
aws sqs receive-message --queue-url "$QUEUE_URL" \
  --max-number-of-messages 1 --wait-time-seconds 5 --visibility-timeout 300 \
  --query 'Messages[].{Body:Body,MessageId:MessageId,ReceiptHandle:ReceiptHandle}' --output table

# Replace the placeholder with the ReceiptHandle you just received.
aws sqs delete-message --queue-url "$QUEUE_URL" \
  --receipt-handle 'PASTE_RECEIPT_HANDLE_HERE'

# Remove the queue when finished.
aws sqs delete-queue --queue-url "$QUEUE_URL"
```

Receiving a message does not delete it. `DeleteMessage` uses its **ReceiptHandle**, not its MessageId. The receive command gives you five minutes to copy the handle before the message becomes visible again.

The queue URL assignment deliberately uses `--output text` so the variable contains only the URL. A ReceiptHandle can make the receive table wide; switch that command to `--output json` if it is easier to copy the full value. Successful write/delete commands may return no output.

## 5. Stop the emulator

```bash
docker exec aws-emulator-demo rpm -q aws-emulator
docker stop aws-emulator-demo
```

## References

- [AWS Emulator announcement](https://aws.amazon.com/about-aws/whats-new/2026/11/aws-emulator-now-available/)
- [Official Docker setup](https://docs.aws.amazon.com/emulator/latest/userguide/getting-started-docker.html)
- [Configure the AWS CLI and SDKs](https://docs.aws.amazon.com/emulator/latest/userguide/point-sdk-to-emulator.html)
- [AWS CLI: S3 commands](https://docs.aws.amazon.com/cli/latest/reference/s3/)
- [AWS CLI: DynamoDB commands](https://docs.aws.amazon.com/cli/latest/reference/dynamodb/)
- [AWS CLI: SQS commands](https://docs.aws.amazon.com/cli/latest/reference/sqs/)
- [AWS CLI output formats](https://docs.aws.amazon.com/cli/latest/userguide/cli-usage-output-format.html)

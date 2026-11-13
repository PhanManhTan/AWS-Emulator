"""Write and read one item in the table created by the CLI walkthrough."""
import os
import boto3

if os.environ.get("AWS_ENDPOINT_URL") != "https://127.0.0.1:9297":
    raise SystemExit("First run: source scripts/env.sh")

db = boto3.resource("dynamodb", endpoint_url="https://127.0.0.1:9297", region_name="us-east-1")
table = db.Table("demo-table")
item = {"id": "python-1", "message": "Hello from Python!"}
table.put_item(Item=item)
print("WRITE:", item)
saved = table.get_item(Key={"id": "python-1"}, ConsistentRead=True)["Item"]
print("READ:", saved)
assert saved == item, "The item read back does not match"

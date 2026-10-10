# Lab 04: Data Analytics Pipeline -- Kinesis Firehose to Athena

## Objective

Build a data analytics pipeline: Kinesis Data Firehose ingests data, delivers it to S3, Glue Crawler catalogs the schema, and Athena queries the data using SQL. This is the core analytics pattern tested on the SAA-C03.

## Estimated Cost

- **$1-3.** Kinesis Firehose charges per GB ingested (~$0.029/GB). Athena charges $5/TB scanned (our dataset is tiny). Glue Crawler charges per DPU-hour (~$0.44). Total for this lab should be well under $3.

## Architecture

```
Data Producer              Firehose              S3               Glue             Athena
(Boto3 script)          (delivery stream)     (data lake)      (catalog)         (query)
+-------------+       +----------------+     +-----------+    +-----------+    +-----------+
| Send JSON   |------>| Buffer (60s)   |---->| Raw JSON  |--->| Crawler   |--->| SQL       |
| records via |       | Transform      |     | files in  |    | discovers |    | queries   |
| PutRecord   |       | (optional)     |     | partitioned|   | schema,   |    | against   |
|             |       | Compress (gzip)|     | prefixes  |    | creates   |    | cataloged |
+-------------+       +----------------+     +-----------+    | table     |    | table     |
                                                              +-----------+    +-----------+
```

---

## Part 1: Create S3 Bucket for Data Lake

```bash
BUCKET_NAME="analytics-lab-$(date +%s)"
REGION="us-east-1"

aws s3 mb s3://$BUCKET_NAME --region $REGION

# Create folder structure for the data lake
aws s3api put-object --bucket $BUCKET_NAME --key raw/
aws s3api put-object --bucket $BUCKET_NAME --key processed/
aws s3api put-object --bucket $BUCKET_NAME --key athena-results/

echo "Data lake bucket: $BUCKET_NAME"
```

---

## Part 2: Create Kinesis Data Firehose Delivery Stream

### Create IAM Role for Firehose

```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Create the Firehose role
aws iam create-role \
    --role-name analytics-lab-firehose-role \
    --assume-role-policy-document '{
        "Version": "2012-10-17",
        "Statement": [{
            "Effect": "Allow",
            "Principal": {"Service": "firehose.amazonaws.com"},
            "Action": "sts:AssumeRole"
        }]
    }'

# Attach S3 write permissions
aws iam put-role-policy \
    --role-name analytics-lab-firehose-role \
    --policy-name S3DeliveryPolicy \
    --policy-document "{
        \"Version\": \"2012-10-17\",
        \"Statement\": [{
            \"Effect\": \"Allow\",
            \"Action\": [
                \"s3:AbortMultipartUpload\",
                \"s3:GetBucketLocation\",
                \"s3:GetObject\",
                \"s3:ListBucket\",
                \"s3:ListBucketMultipartUploads\",
                \"s3:PutObject\"
            ],
            \"Resource\": [
                \"arn:aws:s3:::${BUCKET_NAME}\",
                \"arn:aws:s3:::${BUCKET_NAME}/*\"
            ]
        }]
    }"

sleep 10  # Wait for role propagation

FIREHOSE_ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/analytics-lab-firehose-role"
```

### Create the Delivery Stream

```bash
aws firehose create-delivery-stream \
    --delivery-stream-name analytics-lab-stream \
    --delivery-stream-type DirectPut \
    --extended-s3-destination-configuration "{
        \"RoleARN\": \"${FIREHOSE_ROLE_ARN}\",
        \"BucketARN\": \"arn:aws:s3:::${BUCKET_NAME}\",
        \"Prefix\": \"raw/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/\",
        \"ErrorOutputPrefix\": \"errors/\",
        \"BufferingHints\": {
            \"SizeInMBs\": 1,
            \"IntervalInSeconds\": 60
        },
        \"CompressionFormat\": \"UNCOMPRESSED\"
    }" \
    --region $REGION

echo "Waiting for delivery stream to become active..."
aws firehose describe-delivery-stream \
    --delivery-stream-name analytics-lab-stream \
    --region $REGION \
    --query 'DeliveryStreamDescription.DeliveryStreamStatus'
```

---

## Part 3: Send Data with Boto3

```python
#!/usr/bin/env python3
"""
Analytics Lab - Data Producer
Sends simulated e-commerce event data to Kinesis Firehose.
"""

import boto3
import json
import random
import time
from datetime import datetime

firehose = boto3.client("firehose", region_name="us-east-1")
STREAM_NAME = "analytics-lab-stream"

# Simulated data
PRODUCTS = [
    {"id": "P001", "name": "Laptop", "category": "Electronics", "price": 999.99},
    {"id": "P002", "name": "Mouse", "category": "Electronics", "price": 29.99},
    {"id": "P003", "name": "T-Shirt", "category": "Clothing", "price": 24.99},
    {"id": "P004", "name": "Headphones", "category": "Electronics", "price": 149.99},
    {"id": "P005", "name": "Book", "category": "Books", "price": 14.99},
    {"id": "P006", "name": "Coffee Maker", "category": "Home", "price": 79.99},
    {"id": "P007", "name": "Backpack", "category": "Clothing", "price": 59.99},
    {"id": "P008", "name": "Monitor", "category": "Electronics", "price": 349.99},
]

ACTIONS = ["view", "add_to_cart", "purchase", "view", "view", "add_to_cart"]
REGIONS = ["us-east", "us-west", "eu-west", "ap-southeast"]


def generate_event():
    """Generate a single e-commerce event."""
    product = random.choice(PRODUCTS)
    action = random.choice(ACTIONS)
    return {
        "event_id": f"evt-{int(time.time()*1000)}-{random.randint(1000,9999)}",
        "timestamp": datetime.utcnow().isoformat(),
        "user_id": f"user-{random.randint(1, 500)}",
        "action": action,
        "product_id": product["id"],
        "product_name": product["name"],
        "category": product["category"],
        "price": product["price"],
        "quantity": random.randint(1, 3) if action == "purchase" else 0,
        "region": random.choice(REGIONS),
        "device": random.choice(["mobile", "desktop", "tablet"]),
    }


def send_batch(batch_size=25):
    """Send a batch of records to Firehose."""
    records = []
    for _ in range(batch_size):
        event = generate_event()
        records.append({"Data": json.dumps(event) + "\n"})

    response = firehose.put_record_batch(
        DeliveryStreamName=STREAM_NAME, Records=records
    )

    failed = response["FailedPutCount"]
    print(
        f"Sent {batch_size} records, {failed} failed. "
        f"Request ID: {response['ResponseMetadata']['RequestId'][:8]}"
    )
    return failed


def main():
    """Send multiple batches of data."""
    total_records = 0
    total_batches = 20  # Send 500 records total (20 batches x 25 records)

    print(f"Sending {total_batches * 25} records to Firehose...")
    for i in range(total_batches):
        failed = send_batch(25)
        total_records += 25 - failed
        time.sleep(0.5)  # Small delay between batches

    print(f"\nDone. Total records sent: {total_records}")
    print(
        "Firehose will buffer for ~60 seconds before delivering to S3."
    )
    print("Wait 2 minutes, then check S3 for data files.")


if __name__ == "__main__":
    main()
```

### Run the producer

```bash
python3 ~/analytics-lab/producer.py

# Wait 2 minutes for Firehose to deliver to S3
sleep 120

# Verify data arrived in S3
aws s3 ls s3://$BUCKET_NAME/raw/ --recursive
```

---

## Part 4: Create Glue Crawler

### Create IAM Role for Glue

```bash
aws iam create-role \
    --role-name analytics-lab-glue-role \
    --assume-role-policy-document '{
        "Version": "2012-10-17",
        "Statement": [{
            "Effect": "Allow",
            "Principal": {"Service": "glue.amazonaws.com"},
            "Action": "sts:AssumeRole"
        }]
    }'

aws iam attach-role-policy \
    --role-name analytics-lab-glue-role \
    --policy-arn arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole

aws iam put-role-policy \
    --role-name analytics-lab-glue-role \
    --policy-name S3AccessPolicy \
    --policy-document "{
        \"Version\": \"2012-10-17\",
        \"Statement\": [{
            \"Effect\": \"Allow\",
            \"Action\": [\"s3:GetObject\", \"s3:PutObject\"],
            \"Resource\": \"arn:aws:s3:::${BUCKET_NAME}/*\"
        }]
    }"

sleep 10
```

### Create Glue Database and Crawler

```bash
# Create Glue database
aws glue create-database \
    --database-input '{"Name": "analytics_lab_db"}' \
    --region $REGION

# Create Glue crawler
GLUE_ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/analytics-lab-glue-role"

aws glue create-crawler \
    --name analytics-lab-crawler \
    --role $GLUE_ROLE_ARN \
    --database-name analytics_lab_db \
    --targets "{
        \"S3Targets\": [{
            \"Path\": \"s3://${BUCKET_NAME}/raw/\"
        }]
    }" \
    --region $REGION

echo "Crawler created. Starting crawler..."

# Run the crawler
aws glue start-crawler --name analytics-lab-crawler --region $REGION

# Wait for crawler to complete (1-3 minutes)
echo "Waiting for crawler to complete..."
while true; do
    STATE=$(aws glue get-crawler --name analytics-lab-crawler --region $REGION \
        --query 'Crawler.State' --output text)
    echo "  Crawler state: $STATE"
    if [ "$STATE" = "READY" ]; then
        break
    fi
    sleep 15
done

echo "Crawler completed. Checking discovered tables..."
aws glue get-tables --database-name analytics_lab_db --region $REGION \
    --query 'TableList[*].{Name:Name,Columns:StorageDescriptor.Columns[*].Name}' \
    --output table
```

---

## Part 5: Query with Athena

### Configure Athena Results Location

```bash
# Create workgroup with output location
aws athena create-work-group \
    --name analytics-lab \
    --configuration "{
        \"ResultConfiguration\": {
            \"OutputLocation\": \"s3://${BUCKET_NAME}/athena-results/\"
        },
        \"EnforceWorkGroupConfiguration\": true
    }" \
    --region $REGION
```

### Run Queries with Boto3

```python
#!/usr/bin/env python3
"""
Analytics Lab - Query data with Athena.
"""

import boto3
import time

athena = boto3.client("athena", region_name="us-east-1")
DATABASE = "analytics_lab_db"
WORKGROUP = "analytics-lab"


def run_query(query, description=""):
    """Execute an Athena query and return results."""
    print(f"\n{'='*60}")
    print(f"Query: {description}")
    print(f"SQL: {query[:100]}...")

    response = athena.start_query_execution(
        QueryString=query,
        QueryExecutionContext={"Database": DATABASE},
        WorkGroup=WORKGROUP,
    )
    query_id = response["QueryExecutionId"]

    # Wait for query to complete
    while True:
        result = athena.get_query_execution(QueryExecutionId=query_id)
        state = result["QueryExecution"]["Status"]["State"]
        if state in ("SUCCEEDED", "FAILED", "CANCELLED"):
            break
        time.sleep(1)

    if state == "FAILED":
        reason = result["QueryExecution"]["Status"]["StateChangeReason"]
        print(f"FAILED: {reason}")
        return None

    # Get results
    results = athena.get_query_results(QueryExecutionId=query_id)
    rows = results["ResultSet"]["Rows"]

    # Print header
    header = [col["VarCharValue"] for col in rows[0]["Data"]]
    print(f"\n{'  |  '.join(header)}")
    print("-" * 60)

    # Print data rows
    for row in rows[1:]:
        values = [col.get("VarCharValue", "NULL") for col in row["Data"]]
        print(f"  {'  |  '.join(values)}")

    data_scanned = result["QueryExecution"]["Statistics"]["DataScannedInBytes"]
    print(f"\nData scanned: {data_scanned / 1024:.1f} KB")
    print(f"Cost: ${data_scanned / (1024**4) * 5:.6f}")

    return results


# --- Run Analytics Queries ---

# Query 1: Total events by action type
run_query(
    "SELECT action, COUNT(*) as count FROM raw GROUP BY action ORDER BY count DESC",
    "Event counts by action type",
)

# Query 2: Revenue by product category
run_query(
    """
    SELECT category,
           SUM(price * quantity) as total_revenue,
           COUNT(*) as purchase_count
    FROM raw
    WHERE action = 'purchase'
    GROUP BY category
    ORDER BY total_revenue DESC
    """,
    "Revenue by product category",
)

# Query 3: Events by device type
run_query(
    "SELECT device, COUNT(*) as count FROM raw GROUP BY device ORDER BY count DESC",
    "Events by device type",
)

# Query 4: Top products by views
run_query(
    """
    SELECT product_name, COUNT(*) as view_count
    FROM raw
    WHERE action = 'view'
    GROUP BY product_name
    ORDER BY view_count DESC
    LIMIT 5
    """,
    "Top 5 most viewed products",
)

# Query 5: Conversion funnel
run_query(
    """
    SELECT action,
           COUNT(*) as count,
           ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) as percentage
    FROM raw
    WHERE action IN ('view', 'add_to_cart', 'purchase')
    GROUP BY action
    ORDER BY count DESC
    """,
    "Conversion funnel (view -> cart -> purchase)",
)
```

---

## Part 6: Query with Athena CLI

```bash
# Simple query via CLI
QUERY_ID=$(aws athena start-query-execution \
    --query-string "SELECT action, COUNT(*) as cnt FROM raw GROUP BY action ORDER BY cnt DESC" \
    --query-execution-context Database=analytics_lab_db \
    --work-group analytics-lab \
    --region $REGION \
    --query 'QueryExecutionId' --output text)

echo "Query ID: $QUERY_ID"

# Wait and get results
sleep 5
aws athena get-query-results --query-execution-id $QUERY_ID --region $REGION \
    --query 'ResultSet.Rows[*].Data[*].VarCharValue' --output table
```

---

## Cleanup

```bash
# Delete Athena workgroup
aws athena delete-work-group --work-group analytics-lab --recursive-delete-option --region $REGION

# Delete Glue crawler and database
aws glue delete-crawler --name analytics-lab-crawler --region $REGION
aws glue delete-database --name analytics_lab_db --region $REGION

# Delete Firehose delivery stream
aws firehose delete-delivery-stream --delivery-stream-name analytics-lab-stream --region $REGION

# Delete IAM roles
aws iam delete-role-policy --role-name analytics-lab-firehose-role --policy-name S3DeliveryPolicy
aws iam delete-role --role-name analytics-lab-firehose-role

aws iam detach-role-policy --role-name analytics-lab-glue-role --policy-arn arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole
aws iam delete-role-policy --role-name analytics-lab-glue-role --policy-name S3AccessPolicy
aws iam delete-role --role-name analytics-lab-glue-role

# Delete S3 bucket
aws s3 rm s3://$BUCKET_NAME --recursive
aws s3 rb s3://$BUCKET_NAME

echo "All analytics lab resources cleaned up."
```

---

## What You Learned

1. How Kinesis Data Firehose buffers and delivers data to S3 automatically.
2. How to use Hive-style partitioning in Firehose delivery (year/month/day prefixes).
3. How Glue Crawlers automatically discover schemas and populate the Data Catalog.
4. How to query S3 data with Athena using standard SQL.
5. The cost model: Firehose charges per GB ingested, Athena charges per TB scanned.
6. The complete analytics pipeline: Ingest -> Store -> Catalog -> Query.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Create S3 Bucket for Data Lake
- Create Kinesis Data Firehose Delivery Stream
- Send Data with Boto3
- Create Glue Crawler

**The gap is not what you forgot. It is where you used a word instead of a mechanism.**

| | |
|---|---|
| ✗ | *"The security group allows the traffic."* |
| ✓ | *"A security group is a stateful allow-list attached to an ENI. Traffic matching an inbound rule is permitted and the reply is permitted automatically, because the connection is tracked — which is why you never write an outbound rule for a reply."* |

**Trace it:** A request from the internet to an instance in a private subnet. Name every hop, every route-table lookup, and every rule evaluated, in order.

Stop at the first component you cannot name. Reopen this file and read **only** that.

**Go deeper — only once the gap has a name:** [Timeouts, retries and backoff with jitter](https://aws.amazon.com/builders-library/timeouts-retries-and-backoff-with-jitter/) — 15 minutes from the AWS Builders' Library, and it changes how you write every client you touch afterwards.
Full list per domain: [`SOURCES.md`](../SOURCES.md#aws)

→ Protocol, the three levels of knowing, and worked examples: [`MASTERY.md`](../MASTERY.md)

<!-- /feynman-check -->

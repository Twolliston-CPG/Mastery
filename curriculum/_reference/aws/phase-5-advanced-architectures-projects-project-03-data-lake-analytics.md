# Project 03: Data Lake Analytics Platform

## Overview

Build a data lake with three storage zones (raw, processed, curated), real-time ingestion via Kinesis Firehose, ETL with Glue, SQL queries with Athena, and visualization with QuickSight. This project covers the full analytics pipeline architecture tested on the SAA-C03.

## Estimated Cost

- **$3-8.** Kinesis Firehose (~$0.029/GB), Glue ETL (~$0.44/DPU-hour, minimum 2 DPUs for 10 minutes = ~$0.15), Athena ($5/TB scanned, our data is tiny). QuickSight has a free trial. Tear down when done.

---

## Architecture Diagram

```
Data Sources                  Ingestion Layer              Storage Layer (S3 Data Lake)
+---------------+           +-------------------+
| IoT Devices   |           |                   |         +---------------------------+
| (simulated    |---------->| Kinesis Data      |-------->| Raw Zone                  |
|  via Boto3)   |           | Firehose          |         | s3://datalake/raw/        |
+---------------+           | (buffer, deliver) |         | - Original JSON           |
                            +-------------------+         | - Partitioned by date     |
+---------------+                                         | - year=YYYY/month=MM/     |
| Application   |           +-------------------+         +---------------------------+
| Logs          |---------->| CloudWatch Logs   |                    |
| (simulated)   |           | Subscription      |                    |
+---------------+           | Filter -> Firehose|                    |
                            +-------------------+                    v
                                                          +---------------------------+
+---------------+           +-------------------+         | Processed Zone            |
| Database      |---------->| AWS DMS (CDC)     |         | s3://datalake/processed/  |
| (existing     |           | (ongoing          |         | - Cleaned, validated      |
|  RDS/on-prem) |           |  replication)     |         | - Parquet format          |
+---------------+           +-------------------+         | - Deduplication applied   |
                                                          +---------------------------+
                                                                     |
                            Catalog Layer                             v
                            +-------------------+         +---------------------------+
                            | Glue Data Catalog |         | Curated Zone              |
                            | - Databases       |<--------| s3://datalake/curated/    |
                            | - Tables          |         | - Aggregated metrics      |
                            | - Partitions      |         | - Business-ready          |
                            +-------------------+         | - Optimized for queries   |
                                    |                     +---------------------------+
                            +-------+--------+
                            | Glue Crawlers  |
                            | (auto-discover |
                            |  schemas)      |
                            +----------------+

ETL Layer                    Query Layer                  Visualization
+-------------------+       +-------------------+        +-------------------+
| Glue ETL Jobs     |       | Amazon Athena     |        | Amazon QuickSight |
| (PySpark)         |       | (serverless SQL)  |------->| (dashboards,      |
| - Clean data      |       | - Ad-hoc queries  |        |  charts, ML       |
| - Transform       |       | - Scheduled       |        |  insights)        |
| - Aggregate       |       |   reports         |        |                   |
| - Partition       |       +-------------------+        +-------------------+
+-------------------+
```

---

## Data Lake Zone Design

| Zone | S3 Path | Format | Purpose | Retention |
|---|---|---|---|---|
| **Raw** | `s3://datalake/raw/` | JSON (original) | Landing zone, immutable copy of source data | 90 days (lifecycle to Glacier) |
| **Processed** | `s3://datalake/processed/` | Parquet (columnar) | Cleaned, validated, deduplicated data | 1 year |
| **Curated** | `s3://datalake/curated/` | Parquet (columnar) | Aggregated, business-ready datasets | Indefinite |

### Partitioning Strategy

```
s3://datalake/raw/events/year=2024/month=01/day=15/hour=14/
s3://datalake/processed/events/year=2024/month=01/day=15/
s3://datalake/curated/daily_metrics/year=2024/month=01/day=15/
```

Partitioning by date allows Athena to scan only relevant partitions, dramatically reducing cost and query time.

---

## Implementation

### Step 1: Create S3 Data Lake Bucket

```bash
LAKE_BUCKET="datalake-project-$(date +%s)"
REGION="us-east-1"

aws s3 mb s3://$LAKE_BUCKET --region $REGION

# Create zone prefixes
for zone in raw processed curated athena-results glue-temp; do
    aws s3api put-object --bucket $LAKE_BUCKET --key "${zone}/"
done

# Set lifecycle rules
aws s3api put-bucket-lifecycle-configuration \
    --bucket $LAKE_BUCKET \
    --lifecycle-configuration '{
        "Rules": [
            {
                "ID": "RawToGlacier",
                "Status": "Enabled",
                "Filter": {"Prefix": "raw/"},
                "Transitions": [
                    {"Days": 90, "StorageClass": "GLACIER"}
                ]
            },
            {
                "ID": "AthenaResultsCleanup",
                "Status": "Enabled",
                "Filter": {"Prefix": "athena-results/"},
                "Expiration": {"Days": 7}
            }
        ]
    }'

echo "Data lake bucket: $LAKE_BUCKET"
```

### Step 2: Create Kinesis Firehose Delivery Stream

```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Create Firehose IAM role (same as Lab 04)
aws iam create-role \
    --role-name datalake-firehose-role \
    --assume-role-policy-document '{
        "Version": "2012-10-17",
        "Statement": [{
            "Effect": "Allow",
            "Principal": {"Service": "firehose.amazonaws.com"},
            "Action": "sts:AssumeRole"
        }]
    }'

aws iam put-role-policy \
    --role-name datalake-firehose-role \
    --policy-name S3Access \
    --policy-document "{
        \"Version\": \"2012-10-17\",
        \"Statement\": [{
            \"Effect\": \"Allow\",
            \"Action\": [\"s3:AbortMultipartUpload\",\"s3:GetBucketLocation\",\"s3:GetObject\",\"s3:ListBucket\",\"s3:ListBucketMultipartUploads\",\"s3:PutObject\"],
            \"Resource\": [\"arn:aws:s3:::${LAKE_BUCKET}\", \"arn:aws:s3:::${LAKE_BUCKET}/*\"]
        }]
    }"

sleep 10

aws firehose create-delivery-stream \
    --delivery-stream-name datalake-ingestion \
    --delivery-stream-type DirectPut \
    --extended-s3-destination-configuration "{
        \"RoleARN\": \"arn:aws:iam::${ACCOUNT_ID}:role/datalake-firehose-role\",
        \"BucketARN\": \"arn:aws:s3:::${LAKE_BUCKET}\",
        \"Prefix\": \"raw/events/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/hour=!{timestamp:HH}/\",
        \"ErrorOutputPrefix\": \"raw/errors/\",
        \"BufferingHints\": {\"SizeInMBs\": 5, \"IntervalInSeconds\": 60},
        \"CompressionFormat\": \"UNCOMPRESSED\"
    }" \
    --region $REGION
```

### Step 3: Data Ingestion Script (Boto3)

```python
#!/usr/bin/env python3
"""
Data Lake Project - Simulated IoT + E-commerce Data Producer
Generates realistic event data and sends to Kinesis Firehose.
"""

import boto3
import json
import random
import time
from datetime import datetime

firehose = boto3.client("firehose", region_name="us-east-1")
STREAM_NAME = "datalake-ingestion"

DEVICES = [f"device-{i:03d}" for i in range(1, 51)]
LOCATIONS = [
    {"city": "New York", "state": "NY", "lat": 40.7128, "lon": -74.0060},
    {"city": "Los Angeles", "state": "CA", "lat": 34.0522, "lon": -118.2437},
    {"city": "Chicago", "state": "IL", "lat": 41.8781, "lon": -87.6298},
    {"city": "Houston", "state": "TX", "lat": 29.7604, "lon": -95.3698},
    {"city": "Seattle", "state": "WA", "lat": 47.6062, "lon": -122.3321},
]
EVENT_TYPES = ["temperature_reading", "humidity_reading", "motion_detected", "door_open", "door_close"]


def generate_iot_event():
    """Generate a simulated IoT sensor event."""
    device = random.choice(DEVICES)
    location = random.choice(LOCATIONS)
    event_type = random.choice(EVENT_TYPES)

    event = {
        "event_id": f"evt-{int(time.time()*1000)}-{random.randint(1000,9999)}",
        "timestamp": datetime.utcnow().isoformat() + "Z",
        "device_id": device,
        "event_type": event_type,
        "location": location,
    }

    if event_type == "temperature_reading":
        event["value"] = round(random.uniform(60, 100), 1)
        event["unit"] = "fahrenheit"
    elif event_type == "humidity_reading":
        event["value"] = round(random.uniform(20, 80), 1)
        event["unit"] = "percent"
    elif event_type == "motion_detected":
        event["value"] = 1
        event["confidence"] = round(random.uniform(0.7, 1.0), 2)
    else:
        event["value"] = 1

    return event


def send_events(count=500, batch_size=25):
    """Send events to Firehose in batches."""
    sent = 0
    failed = 0

    for batch_start in range(0, count, batch_size):
        current_batch = min(batch_size, count - batch_start)
        records = []
        for _ in range(current_batch):
            event = generate_iot_event()
            records.append({"Data": json.dumps(event) + "\n"})

        response = firehose.put_record_batch(
            DeliveryStreamName=STREAM_NAME, Records=records
        )
        sent += current_batch - response["FailedPutCount"]
        failed += response["FailedPutCount"]
        time.sleep(0.3)

    print(f"Sent: {sent}, Failed: {failed}")
    return sent


if __name__ == "__main__":
    print("Sending 1000 IoT events to Firehose...")
    total = send_events(count=1000)
    print(f"\nTotal events sent: {total}")
    print("Wait 2 minutes for Firehose to deliver to S3, then run the Glue Crawler.")
```

### Step 4: Glue Crawler and Data Catalog

```bash
# Create Glue IAM role
aws iam create-role \
    --role-name datalake-glue-role \
    --assume-role-policy-document '{
        "Version": "2012-10-17",
        "Statement": [{
            "Effect": "Allow",
            "Principal": {"Service": "glue.amazonaws.com"},
            "Action": "sts:AssumeRole"
        }]
    }'

aws iam attach-role-policy --role-name datalake-glue-role \
    --policy-arn arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole

aws iam put-role-policy --role-name datalake-glue-role --policy-name S3Access \
    --policy-document "{
        \"Version\": \"2012-10-17\",
        \"Statement\": [{
            \"Effect\": \"Allow\",
            \"Action\": [\"s3:GetObject\",\"s3:PutObject\"],
            \"Resource\": \"arn:aws:s3:::${LAKE_BUCKET}/*\"
        }]
    }"

sleep 10

# Create database
aws glue create-database --database-input '{"Name": "datalake_db"}' --region $REGION

# Create crawler for raw zone
aws glue create-crawler \
    --name datalake-raw-crawler \
    --role "arn:aws:iam::${ACCOUNT_ID}:role/datalake-glue-role" \
    --database-name datalake_db \
    --targets "{\"S3Targets\": [{\"Path\": \"s3://${LAKE_BUCKET}/raw/events/\"}]}" \
    --region $REGION

# Run crawler
aws glue start-crawler --name datalake-raw-crawler --region $REGION
echo "Crawler started. Wait 2-3 minutes for it to complete."
```

### Step 5: Athena Queries

```python
#!/usr/bin/env python3
"""Query the data lake with Athena."""

import boto3
import time

athena = boto3.client("athena", region_name="us-east-1")
LAKE_BUCKET = "datalake-project-REPLACE_ME"  # Replace with your bucket name
DATABASE = "datalake_db"


def run_query(sql, description=""):
    """Execute Athena query and print results."""
    print(f"\n{'='*60}\n{description}\n{'-'*60}")

    response = athena.start_query_execution(
        QueryString=sql,
        QueryExecutionContext={"Database": DATABASE},
        ResultConfiguration={
            "OutputLocation": f"s3://{LAKE_BUCKET}/athena-results/"
        },
    )
    query_id = response["QueryExecutionId"]

    while True:
        status = athena.get_query_execution(QueryExecutionId=query_id)
        state = status["QueryExecution"]["Status"]["State"]
        if state in ("SUCCEEDED", "FAILED", "CANCELLED"):
            break
        time.sleep(2)

    if state != "SUCCEEDED":
        print(f"Query {state}: {status['QueryExecution']['Status'].get('StateChangeReason','')}")
        return

    results = athena.get_query_results(QueryExecutionId=query_id)
    rows = results["ResultSet"]["Rows"]
    header = [col["VarCharValue"] for col in rows[0]["Data"]]
    print("  |  ".join(header))
    print("-" * 60)
    for row in rows[1:10]:  # Limit to first 10 rows
        values = [col.get("VarCharValue", "NULL") for col in row["Data"]]
        print("  |  ".join(values))

    scanned = status["QueryExecution"]["Statistics"]["DataScannedInBytes"]
    print(f"\nData scanned: {scanned/1024:.1f} KB | Cost: ${scanned/(1024**4)*5:.6f}")


# Analytics Queries
run_query(
    "SELECT event_type, COUNT(*) as cnt FROM events GROUP BY event_type ORDER BY cnt DESC",
    "Event Distribution by Type",
)

run_query(
    """SELECT device_id, event_type, AVG(value) as avg_value, MIN(value) as min_value, MAX(value) as max_value
       FROM events WHERE event_type = 'temperature_reading'
       GROUP BY device_id, event_type ORDER BY avg_value DESC LIMIT 10""",
    "Temperature Statistics by Device (Top 10 Hottest)",
)

run_query(
    """SELECT location.city, COUNT(*) as event_count,
              AVG(CASE WHEN event_type='temperature_reading' THEN value END) as avg_temp
       FROM events GROUP BY location.city ORDER BY event_count DESC""",
    "Events and Average Temperature by City",
)

run_query(
    """SELECT date_format(from_iso8601_timestamp(timestamp), '%Y-%m-%d %H:00') as hour,
              COUNT(*) as events_per_hour
       FROM events GROUP BY 1 ORDER BY 1""",
    "Event Volume by Hour",
)
```

### Step 6: Glue ETL Job (Conceptual PySpark)

```python
# glue_etl_job.py
# This would run as a Glue ETL job (PySpark)
# For the lab, review this code to understand the ETL pattern.

"""
Glue ETL Job: Transform raw JSON data to optimized Parquet in the processed zone.
"""

from awsglue.context import GlueContext
from awsglue.job import Job
from pyspark.context import SparkContext
from awsglue.dynamicframe import DynamicFrame

sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)

# Read from raw zone (via Glue Data Catalog)
raw_data = glueContext.create_dynamic_frame.from_catalog(
    database="datalake_db",
    table_name="events",
)

# Convert to Spark DataFrame for transformations
df = raw_data.toDF()

# Clean and transform
df_clean = df \
    .dropDuplicates(["event_id"]) \
    .filter(df["value"].isNotNull()) \
    .withColumn("processed_at", current_timestamp())

# Convert back to DynamicFrame
processed = DynamicFrame.fromDF(df_clean, glueContext, "processed")

# Write to processed zone as Parquet, partitioned by date
glueContext.write_dynamic_frame.from_options(
    frame=processed,
    connection_type="s3",
    connection_options={
        "path": "s3://LAKE_BUCKET/processed/events/",
        "partitionKeys": ["year", "month", "day"],
    },
    format="parquet",
)

job.commit()
```

---

## Terraform Infrastructure (Key Resources)

```hcl
# S3 Data Lake
resource "aws_s3_bucket" "datalake" {
  bucket = "datalake-project-${random_id.suffix.hex}"
}

resource "aws_s3_bucket_lifecycle_configuration" "datalake" {
  bucket = aws_s3_bucket.datalake.id

  rule {
    id     = "raw-to-glacier"
    status = "Enabled"
    filter { prefix = "raw/" }
    transition {
      days          = 90
      storage_class = "GLACIER"
    }
  }

  rule {
    id     = "athena-cleanup"
    status = "Enabled"
    filter { prefix = "athena-results/" }
    expiration { days = 7 }
  }
}

# Glue Catalog
resource "aws_glue_catalog_database" "datalake" {
  name = "datalake_db"
}

resource "aws_glue_crawler" "raw" {
  name          = "datalake-raw-crawler"
  role          = aws_iam_role.glue.arn
  database_name = aws_glue_catalog_database.datalake.name

  s3_target {
    path = "s3://${aws_s3_bucket.datalake.id}/raw/events/"
  }

  schedule = "cron(0 */6 * * ? *)"  # Every 6 hours
}

# Athena Workgroup
resource "aws_athena_workgroup" "datalake" {
  name = "datalake-analytics"

  configuration {
    result_configuration {
      output_location = "s3://${aws_s3_bucket.datalake.id}/athena-results/"
    }
    enforce_workgroup_configuration = true
    bytes_scanned_cutoff_per_query  = 1073741824  # 1 GB limit
  }
}
```

---

## Teardown

```bash
# Delete Glue resources
aws glue delete-crawler --name datalake-raw-crawler --region $REGION
aws glue delete-database --name datalake_db --region $REGION

# Delete Firehose
aws firehose delete-delivery-stream --delivery-stream-name datalake-ingestion --region $REGION

# Delete Athena workgroup
aws athena delete-work-group --work-group datalake-analytics --recursive-delete-option --region $REGION 2>/dev/null

# Delete IAM roles
aws iam delete-role-policy --role-name datalake-firehose-role --policy-name S3Access
aws iam delete-role --role-name datalake-firehose-role
aws iam detach-role-policy --role-name datalake-glue-role --policy-arn arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole
aws iam delete-role-policy --role-name datalake-glue-role --policy-name S3Access
aws iam delete-role --role-name datalake-glue-role

# Delete S3 bucket
aws s3 rm s3://$LAKE_BUCKET --recursive
aws s3 rb s3://$LAKE_BUCKET

echo "All data lake resources cleaned up."
```

---

## What You Learned

1. How to design a data lake with raw/processed/curated zones on S3.
2. How Kinesis Firehose delivers streaming data to S3 with partitioning.
3. How Glue Crawlers automatically discover schemas for the Data Catalog.
4. How Athena queries S3 data using SQL with pay-per-scan pricing.
5. How Parquet format and partitioning reduce Athena query costs.
6. How S3 lifecycle rules manage data retention (raw -> Glacier after 90 days).
7. The complete analytics pipeline: Ingest -> Store -> Catalog -> ETL -> Query -> Visualize.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Data Lake Zone Design
- Terraform Infrastructure (Key Resources)
- Partitioning Strategy
- Create S3 Data Lake Bucket

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

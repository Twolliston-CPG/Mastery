# Lab 02: DynamoDB CRUD Operations

## Objective

Create a DynamoDB table, perform CRUD operations with Boto3, add a Global Secondary Index (GSI), enable DynamoDB Streams, and configure TTL. This lab is entirely Python/Boto3 focused and runs within the Free Tier.

---

## Prerequisites

- AWS CLI configured with your `saa-study` profile.
- Python 3.10+ with `boto3` installed.
- No VPC or EC2 required -- DynamoDB is a fully managed, serverless service.

---

## Cost Estimate

| Resource | Cost |
|---|---|
| DynamoDB table (25 RCU/WCU Free Tier) | **Free** |
| DynamoDB Streams | **Free** (2.5M reads/month Free Tier) |
| GSI (shares Free Tier capacity) | **Free** |
| Storage (up to 25 GB Free Tier) | **Free** |
| **Total** | **$0** |

> DynamoDB Free Tier is **always free** (not just 12 months). This lab will cost nothing.

---

## Part 1: Create a DynamoDB Table

### Table Design

We will create an `Orders` table for an e-commerce application:

| Attribute | Type | Role |
|---|---|---|
| `user_id` | String (S) | Partition Key |
| `order_id` | String (S) | Sort Key |
| `product` | String (S) | Regular attribute |
| `amount` | Number (N) | Regular attribute |
| `status` | String (S) | Regular attribute (used for GSI) |
| `created_at` | Number (N) | Epoch timestamp (used for TTL) |

### Boto3: Create Table

Create a file `dynamodb_lab.py`:

```python
import boto3
import time
from datetime import datetime, timedelta
from decimal import Decimal

session = boto3.Session(profile_name='saa-study')
dynamodb = session.resource('dynamodb', region_name='us-east-1')
client = session.client('dynamodb', region_name='us-east-1')

TABLE_NAME = 'saa-lab-orders'


def create_table():
    """Create the Orders table with partition key + sort key."""
    print(f"Creating table '{TABLE_NAME}'...")
    table = dynamodb.create_table(
        TableName=TABLE_NAME,
        KeySchema=[
            {'AttributeName': 'user_id', 'KeyType': 'HASH'},   # Partition key
            {'AttributeName': 'order_id', 'KeyType': 'RANGE'},  # Sort key
        ],
        AttributeDefinitions=[
            {'AttributeName': 'user_id', 'AttributeType': 'S'},
            {'AttributeName': 'order_id', 'AttributeType': 'S'},
        ],
        BillingMode='PAY_PER_REQUEST',  # On-demand mode (simplest for labs)
    )
    table.wait_until_exists()
    print(f"Table '{TABLE_NAME}' created successfully.")
    print(f"  Status: {table.table_status}")
    print(f"  Item count: {table.item_count}")
    return table
```

### CLI: Create Table (Alternative)

```bash
aws dynamodb create-table \
  --table-name saa-lab-orders \
  --attribute-definitions \
    AttributeName=user_id,AttributeType=S \
    AttributeName=order_id,AttributeType=S \
  --key-schema \
    AttributeName=user_id,KeyType=HASH \
    AttributeName=order_id,KeyType=RANGE \
  --billing-mode PAY_PER_REQUEST \
  --profile saa-study
```

---

## Part 2: CRUD Operations with Boto3

### Create (PutItem)

```python
def put_items():
    """Insert sample order items."""
    table = dynamodb.Table(TABLE_NAME)
    now = int(datetime.now().timestamp())

    orders = [
        {
            'user_id': 'user-001',
            'order_id': 'ord-2024-001',
            'product': 'Laptop',
            'amount': Decimal('999.99'),
            'status': 'completed',
            'created_at': now,
        },
        {
            'user_id': 'user-001',
            'order_id': 'ord-2024-002',
            'product': 'Mouse',
            'amount': Decimal('29.99'),
            'status': 'pending',
            'created_at': now,
        },
        {
            'user_id': 'user-001',
            'order_id': 'ord-2024-003',
            'product': 'Keyboard',
            'amount': Decimal('79.99'),
            'status': 'completed',
            'created_at': now,
        },
        {
            'user_id': 'user-002',
            'order_id': 'ord-2024-004',
            'product': 'Monitor',
            'amount': Decimal('349.99'),
            'status': 'shipped',
            'created_at': now,
        },
        {
            'user_id': 'user-002',
            'order_id': 'ord-2024-005',
            'product': 'Webcam',
            'amount': Decimal('59.99'),
            'status': 'pending',
            'created_at': now,
        },
    ]

    with table.batch_writer() as batch:
        for order in orders:
            batch.put_item(Item=order)
            print(f"  Inserted: {order['user_id']} / {order['order_id']}")

    print(f"Inserted {len(orders)} items.")
```

### Read (GetItem, Query, Scan)

```python
from boto3.dynamodb.conditions import Key, Attr


def get_item():
    """Get a single item by primary key."""
    table = dynamodb.Table(TABLE_NAME)
    response = table.get_item(
        Key={
            'user_id': 'user-001',
            'order_id': 'ord-2024-001',
        }
    )
    item = response.get('Item')
    print(f"GetItem result: {item}")
    return item


def query_user_orders(user_id):
    """Query all orders for a specific user (uses partition key)."""
    table = dynamodb.Table(TABLE_NAME)
    response = table.query(
        KeyConditionExpression=Key('user_id').eq(user_id)
    )
    print(f"Orders for {user_id}:")
    for item in response['Items']:
        print(f"  {item['order_id']}: {item['product']} - ${item['amount']} ({item['status']})")
    return response['Items']


def query_with_sort_key_range(user_id, order_prefix):
    """Query orders with a sort key prefix (begins_with)."""
    table = dynamodb.Table(TABLE_NAME)
    response = table.query(
        KeyConditionExpression=(
            Key('user_id').eq(user_id) &
            Key('order_id').begins_with(order_prefix)
        )
    )
    print(f"Orders for {user_id} starting with '{order_prefix}':")
    for item in response['Items']:
        print(f"  {item['order_id']}: {item['product']}")
    return response['Items']


def scan_all():
    """Scan the entire table (expensive -- avoid in production)."""
    table = dynamodb.Table(TABLE_NAME)
    response = table.scan()
    print(f"Scan returned {response['Count']} items:")
    for item in response['Items']:
        print(f"  {item['user_id']} / {item['order_id']}: {item['product']}")
    return response['Items']


def scan_with_filter():
    """Scan with a filter (filter happens AFTER scan, still reads all data)."""
    table = dynamodb.Table(TABLE_NAME)
    response = table.scan(
        FilterExpression=Attr('status').eq('pending')
    )
    print(f"Pending orders ({response['Count']} items):")
    for item in response['Items']:
        print(f"  {item['user_id']} / {item['order_id']}: {item['product']}")
    return response['Items']
```

### Update (UpdateItem)

```python
def update_order_status(user_id, order_id, new_status):
    """Update the status of an order."""
    table = dynamodb.Table(TABLE_NAME)
    response = table.update_item(
        Key={
            'user_id': user_id,
            'order_id': order_id,
        },
        UpdateExpression='SET #s = :status',
        ExpressionAttributeNames={'#s': 'status'},   # 'status' is a reserved word
        ExpressionAttributeValues={':status': new_status},
        ReturnValues='ALL_NEW',
    )
    print(f"Updated {order_id}: status -> {response['Attributes']['status']}")
    return response['Attributes']
```

### Delete (DeleteItem)

```python
def delete_order(user_id, order_id):
    """Delete an order."""
    table = dynamodb.Table(TABLE_NAME)
    response = table.delete_item(
        Key={
            'user_id': user_id,
            'order_id': order_id,
        },
        ReturnValues='ALL_OLD',
    )
    print(f"Deleted: {response.get('Attributes', 'Item not found')}")
```

---

## Part 3: Add a Global Secondary Index (GSI)

A GSI lets you query by an attribute that is not the table's partition key.

### Use Case
"Find all orders with status = 'pending' across ALL users."

Without a GSI, you would have to do a full table Scan with a filter. With a GSI on `status`, you can do an efficient Query.

```python
def add_gsi():
    """Add a GSI to query orders by status."""
    print("Adding GSI 'status-index'...")
    client.update_table(
        TableName=TABLE_NAME,
        AttributeDefinitions=[
            {'AttributeName': 'status', 'AttributeType': 'S'},
            {'AttributeName': 'order_id', 'AttributeType': 'S'},
        ],
        GlobalSecondaryIndexUpdates=[
            {
                'Create': {
                    'IndexName': 'status-index',
                    'KeySchema': [
                        {'AttributeName': 'status', 'KeyType': 'HASH'},
                        {'AttributeName': 'order_id', 'KeyType': 'RANGE'},
                    ],
                    'Projection': {'ProjectionType': 'ALL'},
                }
            }
        ],
    )
    # Wait for GSI to become ACTIVE
    print("Waiting for GSI to become active (may take a few minutes)...")
    waiter = client.get_waiter('table_exists')
    waiter.wait(TableName=TABLE_NAME)
    print("GSI 'status-index' is active.")


def query_by_status(status):
    """Query orders by status using the GSI."""
    table = dynamodb.Table(TABLE_NAME)
    response = table.query(
        IndexName='status-index',
        KeyConditionExpression=Key('status').eq(status),
    )
    print(f"Orders with status '{status}':")
    for item in response['Items']:
        print(f"  {item['user_id']} / {item['order_id']}: {item['product']}")
    return response['Items']
```

---

## Part 4: Enable DynamoDB Streams

```python
def enable_streams():
    """Enable DynamoDB Streams to capture item changes."""
    print("Enabling DynamoDB Streams (NEW_AND_OLD_IMAGES)...")
    client.update_table(
        TableName=TABLE_NAME,
        StreamSpecification={
            'StreamEnabled': True,
            'StreamViewType': 'NEW_AND_OLD_IMAGES',
        },
    )
    # Get the stream ARN
    response = client.describe_table(TableName=TABLE_NAME)
    stream_arn = response['Table'].get('LatestStreamArn')
    print(f"Stream ARN: {stream_arn}")
    return stream_arn
```

### CLI: Enable Streams

```bash
aws dynamodb update-table \
  --table-name saa-lab-orders \
  --stream-specification StreamEnabled=true,StreamViewType=NEW_AND_OLD_IMAGES \
  --profile saa-study
```

---

## Part 5: Configure TTL

TTL automatically deletes items after a specified timestamp.

```python
def enable_ttl():
    """Enable TTL on the 'created_at' attribute."""
    print("Enabling TTL on 'created_at' attribute...")
    client.update_time_to_live(
        TableName=TABLE_NAME,
        TimeToLiveSpecification={
            'Enabled': True,
            'AttributeName': 'created_at',
        },
    )
    print("TTL enabled. Items will be deleted after their 'created_at' timestamp passes.")


def put_item_with_ttl():
    """Insert an item that expires in 5 minutes (for testing)."""
    table = dynamodb.Table(TABLE_NAME)
    expire_at = int((datetime.now() + timedelta(minutes=5)).timestamp())
    table.put_item(Item={
        'user_id': 'user-ttl-test',
        'order_id': 'ord-ttl-001',
        'product': 'Temporary Item',
        'amount': Decimal('0.01'),
        'status': 'test',
        'created_at': expire_at,
    })
    print(f"Inserted item with TTL expiring at {datetime.fromtimestamp(expire_at)}")
```

### CLI: Enable TTL

```bash
aws dynamodb update-time-to-live \
  --table-name saa-lab-orders \
  --time-to-live-specification Enabled=true,AttributeName=created_at \
  --profile saa-study
```

---

## Part 6: Run the Lab

Add this to the bottom of `dynamodb_lab.py`:

```python
if __name__ == '__main__':
    print("=" * 60)
    print("DYNAMODB LAB")
    print("=" * 60)

    # Step 1: Create table
    create_table()

    # Step 2: Insert items
    print("\n--- Put Items ---")
    put_items()

    # Step 3: Read operations
    print("\n--- Get Item ---")
    get_item()

    print("\n--- Query User Orders ---")
    query_user_orders('user-001')

    print("\n--- Query with Sort Key Range ---")
    query_with_sort_key_range('user-001', 'ord-2024')

    print("\n--- Scan All ---")
    scan_all()

    print("\n--- Scan with Filter ---")
    scan_with_filter()

    # Step 4: Update
    print("\n--- Update Order Status ---")
    update_order_status('user-001', 'ord-2024-002', 'shipped')

    # Step 5: Add GSI
    print("\n--- Add GSI ---")
    add_gsi()
    time.sleep(10)  # Allow GSI backfill time

    print("\n--- Query by Status (GSI) ---")
    query_by_status('completed')

    # Step 6: Enable Streams
    print("\n--- Enable Streams ---")
    enable_streams()

    # Step 7: Enable TTL
    print("\n--- Enable TTL ---")
    enable_ttl()
    put_item_with_ttl()

    # Step 8: Delete an item
    print("\n--- Delete Order ---")
    delete_order('user-002', 'ord-2024-005')

    print("\n" + "=" * 60)
    print("LAB COMPLETE")
    print("=" * 60)
```

---

## Cleanup

```bash
aws dynamodb delete-table \
  --table-name saa-lab-orders \
  --profile saa-study
```

Or in Python:

```python
def cleanup():
    """Delete the table."""
    table = dynamodb.Table(TABLE_NAME)
    table.delete()
    print(f"Table '{TABLE_NAME}' deletion initiated.")
```

---

## What You Learned

- [x] How to design a DynamoDB table with partition key and sort key.
- [x] CRUD operations with Boto3 (PutItem, GetItem, Query, Scan, UpdateItem, DeleteItem).
- [x] The difference between Query (efficient, uses key) and Scan (expensive, reads everything).
- [x] How to add a GSI to enable queries on non-key attributes.
- [x] How DynamoDB Streams captures item-level changes.
- [x] How TTL automatically deletes expired items.
- [x] How to use batch writes for efficient bulk inserts.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Create a DynamoDB Table
- CRUD Operations with Boto3
- Add a Global Secondary Index (GSI)
- Enable DynamoDB Streams

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

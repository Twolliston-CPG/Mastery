# Lab 03: SQS & SNS Messaging

## Objective

Create SQS queues (Standard and FIFO), send and receive messages, create an SNS topic, set up the fan-out pattern (SNS -> multiple SQS queues), and configure a Dead-Letter Queue (DLQ). Uses AWS CLI and Boto3.

---

## Prerequisites

- AWS CLI configured with your `saa-study` profile.
- Python 3.10+ with `boto3` installed.

---

## Cost Estimate

| Resource | Cost |
|---|---|
| SQS (1M requests Free Tier) | **Free** |
| SNS (1M publishes Free Tier) | **Free** |
| **Total** | **$0** |

---

## Part 1: SQS Standard Queue with AWS CLI

### Step 1: Create a Standard Queue

```bash
aws sqs create-queue \
  --queue-name saa-lab-orders-queue \
  --attributes '{"VisibilityTimeout":"30","MessageRetentionPeriod":"345600"}' \
  --profile saa-study
```

The response contains the `QueueUrl`. Save it.

### Step 2: Send Messages

```bash
# Send a single message
aws sqs send-message \
  --queue-url https://sqs.us-east-1.amazonaws.com/ACCOUNT_ID/saa-lab-orders-queue \
  --message-body '{"order_id": "ord-001", "product": "Laptop", "amount": 999.99}' \
  --profile saa-study

# Send with message attributes
aws sqs send-message \
  --queue-url https://sqs.us-east-1.amazonaws.com/ACCOUNT_ID/saa-lab-orders-queue \
  --message-body '{"order_id": "ord-002", "product": "Mouse", "amount": 29.99}' \
  --message-attributes '{"OrderType":{"DataType":"String","StringValue":"express"}}' \
  --profile saa-study
```

### Step 3: Receive Messages

```bash
# Receive (long polling with 5-second wait)
aws sqs receive-message \
  --queue-url https://sqs.us-east-1.amazonaws.com/ACCOUNT_ID/saa-lab-orders-queue \
  --max-number-of-messages 10 \
  --wait-time-seconds 5 \
  --message-attribute-names All \
  --profile saa-study
```

### Step 4: Delete a Message

```bash
# Use the ReceiptHandle from the receive-message response
aws sqs delete-message \
  --queue-url https://sqs.us-east-1.amazonaws.com/ACCOUNT_ID/saa-lab-orders-queue \
  --receipt-handle "AQEBxxxxxxxxxxxxxxxx" \
  --profile saa-study
```

### Step 5: Check Queue Attributes

```bash
aws sqs get-queue-attributes \
  --queue-url https://sqs.us-east-1.amazonaws.com/ACCOUNT_ID/saa-lab-orders-queue \
  --attribute-names All \
  --profile saa-study
```

---

## Part 2: SQS with Boto3

Create a file `sqs_lab.py`:

```python
import boto3
import json
import time

session = boto3.Session(profile_name='saa-study')
sqs = session.resource('sqs', region_name='us-east-1')
sqs_client = session.client('sqs', region_name='us-east-1')


def create_standard_queue():
    """Create a standard SQS queue."""
    queue = sqs.create_queue(
        QueueName='saa-lab-orders-queue',
        Attributes={
            'VisibilityTimeout': '30',
            'MessageRetentionPeriod': '345600',  # 4 days
            'ReceiveMessageWaitTimeSeconds': '5',  # Enable long polling
        }
    )
    print(f"Queue URL: {queue.url}")
    return queue


def send_messages(queue):
    """Send multiple messages to the queue."""
    orders = [
        {'order_id': 'ord-001', 'product': 'Laptop', 'amount': 999.99},
        {'order_id': 'ord-002', 'product': 'Mouse', 'amount': 29.99},
        {'order_id': 'ord-003', 'product': 'Keyboard', 'amount': 79.99},
        {'order_id': 'ord-004', 'product': 'Monitor', 'amount': 349.99},
        {'order_id': 'ord-005', 'product': 'Webcam', 'amount': 59.99},
    ]

    for order in orders:
        response = queue.send_message(
            MessageBody=json.dumps(order),
            MessageAttributes={
                'OrderType': {
                    'DataType': 'String',
                    'StringValue': 'standard',
                },
            },
        )
        print(f"Sent: {order['order_id']} (MessageId: {response['MessageId']})")


def receive_and_process(queue, max_messages=5):
    """Receive and process messages from the queue."""
    print(f"\nReceiving messages (long polling, 5 sec wait)...")
    messages = queue.receive_messages(
        MaxNumberOfMessages=max_messages,
        WaitTimeSeconds=5,
        MessageAttributeNames=['All'],
    )

    if not messages:
        print("No messages available.")
        return

    for msg in messages:
        body = json.loads(msg.body)
        print(f"  Processing: {body['order_id']} - {body['product']} - ${body['amount']}")

        # Simulate processing
        time.sleep(0.1)

        # Delete the message after successful processing
        msg.delete()
        print(f"    Deleted: {body['order_id']}")


def send_batch(queue):
    """Send messages in a batch (up to 10 at a time)."""
    entries = []
    for i in range(10):
        entries.append({
            'Id': str(i),
            'MessageBody': json.dumps({
                'order_id': f'batch-{i:03d}',
                'product': f'Product {i}',
                'amount': round(10.0 + i * 5.5, 2),
            }),
        })

    response = queue.send_messages(Entries=entries)
    print(f"Batch sent: {len(response.get('Successful', []))} succeeded, "
          f"{len(response.get('Failed', []))} failed")
```

---

## Part 3: Dead-Letter Queue (DLQ)

```python
def create_dlq():
    """Create a DLQ and configure the main queue to use it."""
    # Create the DLQ
    dlq = sqs.create_queue(
        QueueName='saa-lab-orders-dlq',
        Attributes={
            'MessageRetentionPeriod': '1209600',  # 14 days (max)
        }
    )
    print(f"DLQ URL: {dlq.url}")

    # Get the DLQ ARN
    dlq_attrs = sqs_client.get_queue_attributes(
        QueueUrl=dlq.url,
        AttributeNames=['QueueArn'],
    )
    dlq_arn = dlq_attrs['Attributes']['QueueArn']
    print(f"DLQ ARN: {dlq_arn}")

    # Configure the main queue to use the DLQ
    main_queue = sqs.get_queue_by_name(QueueName='saa-lab-orders-queue')
    main_queue.set_attributes(
        Attributes={
            'RedrivePolicy': json.dumps({
                'deadLetterTargetArn': dlq_arn,
                'maxReceiveCount': '3',  # After 3 failed attempts, send to DLQ
            }),
        }
    )
    print("DLQ configured on main queue (maxReceiveCount=3).")
    return dlq


def simulate_failure(queue):
    """Simulate a consumer that fails to process messages (does not delete them).
    After maxReceiveCount receives, the message moves to the DLQ."""
    print("\nSimulating consumer failures...")
    for attempt in range(4):
        messages = queue.receive_messages(
            MaxNumberOfMessages=1,
            WaitTimeSeconds=2,
        )
        if messages:
            body = json.loads(messages[0].body)
            print(f"  Attempt {attempt + 1}: Received {body['order_id']} - "
                  f"SIMULATING FAILURE (not deleting)")
            # Intentionally NOT deleting the message
            # Wait for visibility timeout to expire
            time.sleep(2)
        else:
            print(f"  Attempt {attempt + 1}: No messages (may have moved to DLQ)")


def check_dlq():
    """Check if any messages landed in the DLQ."""
    dlq = sqs.get_queue_by_name(QueueName='saa-lab-orders-dlq')
    messages = dlq.receive_messages(
        MaxNumberOfMessages=10,
        WaitTimeSeconds=5,
    )
    print(f"\nDLQ contains {len(messages)} message(s):")
    for msg in messages:
        print(f"  DLQ message: {msg.body}")
```

---

## Part 4: FIFO Queue

```python
def create_fifo_queue():
    """Create a FIFO queue with content-based deduplication."""
    queue = sqs.create_queue(
        QueueName='saa-lab-orders-queue.fifo',  # Must end with .fifo
        Attributes={
            'FifoQueue': 'true',
            'ContentBasedDeduplication': 'true',
            'VisibilityTimeout': '30',
        }
    )
    print(f"FIFO Queue URL: {queue.url}")
    return queue


def send_fifo_messages(queue):
    """Send ordered messages to a FIFO queue."""
    orders = [
        ('group-a', 'ord-f001', 'Laptop'),
        ('group-a', 'ord-f002', 'Mouse'),      # Same group -> guaranteed order
        ('group-b', 'ord-f003', 'Monitor'),     # Different group -> independent
        ('group-a', 'ord-f004', 'Keyboard'),    # Back to group-a -> ordered after f002
    ]

    for group_id, order_id, product in orders:
        response = queue.send_message(
            MessageBody=json.dumps({
                'order_id': order_id,
                'product': product,
            }),
            MessageGroupId=group_id,
            # No MessageDeduplicationId needed (ContentBasedDeduplication is on)
        )
        print(f"Sent: {order_id} (Group: {group_id}, Seq: {response.get('SequenceNumber')})")
```

---

## Part 5: SNS + SQS Fan-Out

Create a file `sns_fanout_lab.py`:

```python
import boto3
import json
import time

session = boto3.Session(profile_name='saa-study')
sns = session.client('sns', region_name='us-east-1')
sqs = session.client('sqs', region_name='us-east-1')

TOPIC_NAME = 'saa-lab-order-events'


def create_sns_topic():
    """Create an SNS topic."""
    response = sns.create_topic(Name=TOPIC_NAME)
    topic_arn = response['TopicArn']
    print(f"SNS Topic ARN: {topic_arn}")
    return topic_arn


def create_subscriber_queues():
    """Create two SQS queues to subscribe to the SNS topic."""
    queues = {}
    for name in ['saa-lab-order-processing', 'saa-lab-order-analytics']:
        response = sqs.create_queue(
            QueueName=name,
            Attributes={'ReceiveMessageWaitTimeSeconds': '5'},
        )
        queue_url = response['QueueUrl']

        # Get the queue ARN
        attrs = sqs.get_queue_attributes(
            QueueUrl=queue_url,
            AttributeNames=['QueueArn'],
        )
        queue_arn = attrs['Attributes']['QueueArn']
        queues[name] = {'url': queue_url, 'arn': queue_arn}
        print(f"Queue: {name} -> {queue_arn}")

    return queues


def set_sqs_policy_for_sns(queue_url, queue_arn, topic_arn):
    """Allow the SNS topic to send messages to the SQS queue."""
    policy = {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Sid": "AllowSNS",
                "Effect": "Allow",
                "Principal": {"Service": "sns.amazonaws.com"},
                "Action": "sqs:SendMessage",
                "Resource": queue_arn,
                "Condition": {
                    "ArnEquals": {"aws:SourceArn": topic_arn}
                },
            }
        ],
    }
    sqs.set_queue_attributes(
        QueueUrl=queue_url,
        Attributes={'Policy': json.dumps(policy)},
    )
    print(f"  Policy set on queue: {queue_arn}")


def subscribe_queues(topic_arn, queues):
    """Subscribe both SQS queues to the SNS topic."""
    for name, info in queues.items():
        # Set the SQS policy first
        set_sqs_policy_for_sns(info['url'], info['arn'], topic_arn)

        # Subscribe the queue to the topic
        response = sns.subscribe(
            TopicArn=topic_arn,
            Protocol='sqs',
            Endpoint=info['arn'],
            Attributes={'RawMessageDelivery': 'true'},
        )
        print(f"Subscribed {name} -> {response['SubscriptionArn']}")


def publish_event(topic_arn):
    """Publish an order event to the SNS topic."""
    message = {
        'order_id': 'ord-fan-001',
        'product': 'Laptop',
        'amount': 999.99,
        'event_type': 'order_placed',
    }
    response = sns.publish(
        TopicArn=topic_arn,
        Message=json.dumps(message),
        MessageAttributes={
            'event_type': {
                'DataType': 'String',
                'StringValue': 'order_placed',
            },
        },
    )
    print(f"Published to SNS: MessageId={response['MessageId']}")


def check_subscriber_queues(queues):
    """Check each subscriber queue for the fan-out message."""
    time.sleep(3)  # Allow time for delivery
    for name, info in queues.items():
        response = sqs.receive_message(
            QueueUrl=info['url'],
            MaxNumberOfMessages=10,
            WaitTimeSeconds=5,
        )
        messages = response.get('Messages', [])
        print(f"\n{name}: {len(messages)} message(s)")
        for msg in messages:
            print(f"  Body: {msg['Body']}")
            # Clean up
            sqs.delete_message(
                QueueUrl=info['url'],
                ReceiptHandle=msg['ReceiptHandle'],
            )


if __name__ == '__main__':
    print("=== SNS + SQS Fan-Out Lab ===\n")

    # Step 1: Create SNS topic
    topic_arn = create_sns_topic()

    # Step 2: Create subscriber queues
    queues = create_subscriber_queues()

    # Step 3: Subscribe queues to the topic
    subscribe_queues(topic_arn, queues)

    # Step 4: Publish a message (fan-out to both queues)
    print("\n--- Publishing Event ---")
    publish_event(topic_arn)

    # Step 5: Check both queues received the message
    print("\n--- Checking Subscriber Queues ---")
    check_subscriber_queues(queues)

    print("\n=== Fan-Out Lab Complete ===")
```

---

## Cleanup

```bash
# Delete SQS queues
aws sqs delete-queue --queue-url https://sqs.us-east-1.amazonaws.com/ACCOUNT_ID/saa-lab-orders-queue --profile saa-study
aws sqs delete-queue --queue-url https://sqs.us-east-1.amazonaws.com/ACCOUNT_ID/saa-lab-orders-dlq --profile saa-study
aws sqs delete-queue --queue-url https://sqs.us-east-1.amazonaws.com/ACCOUNT_ID/saa-lab-orders-queue.fifo --profile saa-study
aws sqs delete-queue --queue-url https://sqs.us-east-1.amazonaws.com/ACCOUNT_ID/saa-lab-order-processing --profile saa-study
aws sqs delete-queue --queue-url https://sqs.us-east-1.amazonaws.com/ACCOUNT_ID/saa-lab-order-analytics --profile saa-study

# Delete SNS topic
aws sns delete-topic --topic-arn arn:aws:sns:us-east-1:ACCOUNT_ID:saa-lab-order-events --profile saa-study
```

---

## What You Learned

- [x] How to create and use SQS Standard and FIFO queues.
- [x] Sending, receiving, and deleting messages with CLI and Boto3.
- [x] Long polling vs short polling behavior.
- [x] How to configure a Dead-Letter Queue for failed messages.
- [x] FIFO queue ordering with Message Group IDs.
- [x] SNS topic creation and SQS subscription (fan-out pattern).
- [x] Setting SQS resource policies to allow SNS to send messages.
- [x] The fan-out pattern: one publish, multiple subscribers receive.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- SQS Standard Queue with AWS CLI
- SQS with Boto3
- Dead-Letter Queue (DLQ)
- FIFO Queue

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

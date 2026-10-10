# Project 02: Serverless Event-Driven Order Processing Platform

## Overview

Build a complete serverless, event-driven order processing system. This project combines CloudFront, S3, API Gateway, Lambda, DynamoDB, Cognito, SQS, SNS, Step Functions, and EventBridge into a production-like platform. This is the type of complex serverless architecture the SAA-C03 expects you to understand.

## Estimated Cost

- **$1-5.** All services are within Free Tier for low-volume usage. Step Functions charges $0.025 per 1,000 state transitions (Standard). Tear down when done.

---

## Architecture Diagram

```
                         +-------------------+
                         | CloudFront (CDN)  |
                         +--------+----------+
                                  |
                   +--------------+--------------+
                   |                             |
          +--------+--------+          +--------+--------+
          | S3 Bucket       |          | API Gateway     |
          | (Static Site)   |          | (REST API)      |
          | React/HTML/CSS  |          | POST /orders    |
          +-----------------+          | GET /orders     |
                                       | GET /orders/{id}|
                                       +--------+--------+
                                                |
                                       +--------+--------+
                                       | Cognito         |
                                       | (JWT Authorizer)|
                                       +--------+--------+
                                                |
                                       +--------+--------+
                                       | Lambda          |
                                       | (API Handler)   |
                                       +--------+--------+
                                                |
                              +-----------------+-----------------+
                              |                                   |
                    +---------+---------+               +---------+---------+
                    | DynamoDB          |               | SQS Queue         |
                    | (Orders Table)    |               | (Order Processing)|
                    | PK: userId        |               +---------+---------+
                    | SK: orderId       |                         |
                    +-------------------+               +---------+---------+
                                                        | Lambda            |
                                                        | (Queue Consumer)  |
                                                        +---------+---------+
                                                                  |
                                                        +---------+---------+
                                                        | Step Functions    |
                                                        | (Order Workflow)  |
                                                        +---------+---------+
                                                                  |
                                          +----------+------------+----------+
                                          |          |                       |
                                  +-------+--+ +----+------+        +-------+-------+
                                  | Lambda   | | Lambda    |        | Lambda        |
                                  | Validate | | Process   |        | Ship          |
                                  | Payment  | | Inventory |        | (mock)        |
                                  +-------+--+ +----+------+        +-------+-------+
                                          |          |                       |
                                          +----------+-----------+-----------+
                                                                 |
                                                        +--------+---------+
                                                        | EventBridge      |
                                                        | (Order Events)   |
                                                        +--------+---------+
                                                                 |
                                                  +--------------+--------------+
                                                  |                             |
                                         +--------+--------+          +--------+--------+
                                         | SNS Topic       |          | Lambda          |
                                         | (Notifications) |          | (Analytics      |
                                         | -> Email        |          |  Aggregator)    |
                                         +-----------------+          +--------+--------+
                                                                               |
                                                                      +--------+--------+
                                                                      | DynamoDB        |
                                                                      | (Metrics Table) |
                                                                      +-----------------+
```

---

## System Components

### 1. Frontend (S3 + CloudFront)

Static website served from S3 through CloudFront. Contains order form and order history page.

### 2. API Layer (API Gateway + Cognito + Lambda)

| Endpoint | Method | Description | Lambda |
|---|---|---|---|
| `/orders` | POST | Create new order | `order-api-handler` |
| `/orders` | GET | List user's orders | `order-api-handler` |
| `/orders/{id}` | GET | Get order details | `order-api-handler` |
| `/orders/{id}/status` | GET | Get order status | `order-api-handler` |

### 3. Order Processing Pipeline (SQS + Step Functions)

When an order is created, it is placed in an SQS queue. A consumer Lambda picks it up and starts a Step Functions workflow.

### 4. Order Workflow (Step Functions State Machine)

```
                    Start
                      |
                      v
              +--Validate Order--+
              |                  |
          (valid)            (invalid)
              |                  |
              v                  v
       Process Payment     Reject Order --> Notify Customer (SNS)
              |                                    |
          (success)                               End
              |
              v
       Update Inventory
              |
              v
       Ship Order (mock)
              |
              v
       Emit Event (EventBridge: OrderCompleted)
              |
              v
       Notify Customer (SNS: Order Shipped)
              |
              v
              End
```

### 5. Event Bus (EventBridge)

Order lifecycle events published to EventBridge:
- `order.created`
- `order.validated`
- `order.payment_processed`
- `order.shipped`
- `order.completed`
- `order.failed`

### 6. Notifications (SNS)

Customer receives email notifications at key stages (order confirmed, order shipped, order failed).

---

## Lambda Functions (Python Skeletons)

### Order API Handler

```python
# lambda/order_api_handler.py
"""Handles API Gateway requests for order CRUD operations."""

import json
import boto3
import uuid
import os
from datetime import datetime

dynamodb = boto3.resource("dynamodb")
orders_table = dynamodb.Table(os.environ["ORDERS_TABLE"])
sqs = boto3.client("sqs")
QUEUE_URL = os.environ["ORDER_QUEUE_URL"]


def lambda_handler(event, context):
    method = event["httpMethod"]
    path = event["path"]
    user_id = event["requestContext"]["authorizer"]["claims"]["sub"]

    if method == "POST" and path == "/orders":
        return create_order(user_id, json.loads(event["body"]))
    elif method == "GET" and path == "/orders":
        return list_orders(user_id)
    elif method == "GET" and "/orders/" in path:
        order_id = path.split("/")[-1]
        return get_order(user_id, order_id)
    return response(404, {"error": "Not found"})


def create_order(user_id, body):
    """Create order, save to DynamoDB, send to SQS for processing."""
    order_id = str(uuid.uuid4())
    order = {
        "userId": user_id,
        "orderId": order_id,
        "items": body.get("items", []),
        "total": sum(item["price"] * item["quantity"] for item in body.get("items", [])),
        "status": "PENDING",
        "createdAt": datetime.utcnow().isoformat(),
    }

    orders_table.put_item(Item=order)

    # Send to SQS for async processing
    sqs.send_message(
        QueueUrl=QUEUE_URL,
        MessageBody=json.dumps(order, default=str),
        MessageAttributes={
            "OrderId": {"StringValue": order_id, "DataType": "String"},
        },
    )

    return response(201, {"order": order})


def list_orders(user_id):
    result = orders_table.query(
        KeyConditionExpression=boto3.dynamodb.conditions.Key("userId").eq(user_id),
        ScanIndexForward=False,
        Limit=50,
    )
    return response(200, {"orders": result["Items"]})


def get_order(user_id, order_id):
    result = orders_table.get_item(Key={"userId": user_id, "orderId": order_id})
    item = result.get("Item")
    if not item:
        return response(404, {"error": "Order not found"})
    return response(200, {"order": item})


def response(status_code, body):
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
        },
        "body": json.dumps(body, default=str),
    }
```

### Queue Consumer (starts Step Functions)

```python
# lambda/queue_consumer.py
"""Consumes orders from SQS and starts Step Functions execution."""

import json
import boto3
import os

sfn = boto3.client("stepfunctions")
STATE_MACHINE_ARN = os.environ["STATE_MACHINE_ARN"]


def lambda_handler(event, context):
    for record in event["Records"]:
        order = json.loads(record["body"])
        print(f"Processing order: {order['orderId']}")

        sfn.start_execution(
            stateMachineArn=STATE_MACHINE_ARN,
            name=f"order-{order['orderId']}",
            input=json.dumps(order, default=str),
        )
```

### Validate Payment Lambda

```python
# lambda/validate_payment.py
"""Validates payment (mock implementation for lab)."""

import json
import random


def lambda_handler(event, context):
    order = event
    print(f"Validating payment for order {order['orderId']}, total: ${order['total']}")

    # Mock: 95% success rate
    success = random.random() < 0.95

    return {
        **order,
        "paymentStatus": "SUCCESS" if success else "FAILED",
        "paymentId": f"pay-{order['orderId'][:8]}",
    }
```

### Event Emitter Lambda

```python
# lambda/event_emitter.py
"""Publishes order events to EventBridge."""

import json
import boto3
import os

events = boto3.client("events")
EVENT_BUS_NAME = os.environ.get("EVENT_BUS_NAME", "default")


def lambda_handler(event, context):
    order = event
    detail_type = f"order.{order.get('currentStep', 'unknown')}"

    events.put_events(
        Entries=[
            {
                "Source": "com.serverlesslab.orders",
                "DetailType": detail_type,
                "Detail": json.dumps(order, default=str),
                "EventBusName": EVENT_BUS_NAME,
            }
        ]
    )

    print(f"Published event: {detail_type} for order {order['orderId']}")
    return order
```

---

## Step Functions State Machine Definition

```json
{
  "Comment": "Order Processing Workflow",
  "StartAt": "ValidateOrder",
  "States": {
    "ValidateOrder": {
      "Type": "Task",
      "Resource": "arn:aws:lambda:us-east-1:ACCOUNT:function:validate-order",
      "Next": "IsOrderValid",
      "Catch": [
        {
          "ErrorEquals": ["States.ALL"],
          "Next": "OrderFailed"
        }
      ]
    },
    "IsOrderValid": {
      "Type": "Choice",
      "Choices": [
        {
          "Variable": "$.paymentStatus",
          "StringEquals": "SUCCESS",
          "Next": "ProcessInventory"
        }
      ],
      "Default": "OrderFailed"
    },
    "ProcessInventory": {
      "Type": "Task",
      "Resource": "arn:aws:lambda:us-east-1:ACCOUNT:function:process-inventory",
      "Next": "ShipOrder"
    },
    "ShipOrder": {
      "Type": "Task",
      "Resource": "arn:aws:lambda:us-east-1:ACCOUNT:function:ship-order",
      "Next": "EmitCompletedEvent"
    },
    "EmitCompletedEvent": {
      "Type": "Task",
      "Resource": "arn:aws:lambda:us-east-1:ACCOUNT:function:event-emitter",
      "Parameters": {
        "orderId.$": "$.orderId",
        "userId.$": "$.userId",
        "currentStep": "completed"
      },
      "Next": "NotifyCustomer"
    },
    "NotifyCustomer": {
      "Type": "Task",
      "Resource": "arn:aws:states:::sns:publish",
      "Parameters": {
        "TopicArn": "arn:aws:sns:us-east-1:ACCOUNT:order-notifications",
        "Message.$": "States.Format('Your order {} has been shipped.', $.orderId)"
      },
      "End": true
    },
    "OrderFailed": {
      "Type": "Task",
      "Resource": "arn:aws:states:::sns:publish",
      "Parameters": {
        "TopicArn": "arn:aws:sns:us-east-1:ACCOUNT:order-notifications",
        "Message.$": "States.Format('Your order {} has failed. Please try again.', $.orderId)"
      },
      "End": true
    }
  }
}
```

---

## Terraform Infrastructure (Key Resources)

```hcl
# Abbreviated Terraform for key resources. Full implementation would be much longer.

# DynamoDB Tables
resource "aws_dynamodb_table" "orders" {
  name         = "serverless-orders"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "userId"
  range_key    = "orderId"

  attribute {
    name = "userId"
    type = "S"
  }
  attribute {
    name = "orderId"
    type = "S"
  }
}

# SQS Queue
resource "aws_sqs_queue" "order_processing" {
  name                       = "order-processing-queue"
  visibility_timeout_seconds = 300
  message_retention_seconds  = 86400

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.order_dlq.arn
    maxReceiveCount     = 3
  })
}

resource "aws_sqs_queue" "order_dlq" {
  name                      = "order-processing-dlq"
  message_retention_seconds = 1209600  # 14 days
}

# SNS Topic
resource "aws_sns_topic" "order_notifications" {
  name = "order-notifications"
}

# EventBridge Rule
resource "aws_cloudwatch_event_rule" "order_completed" {
  name        = "order-completed"
  description = "Capture order completed events"

  event_pattern = jsonencode({
    source      = ["com.serverlesslab.orders"]
    detail-type = ["order.completed"]
  })
}

resource "aws_cloudwatch_event_target" "analytics_lambda" {
  rule = aws_cloudwatch_event_rule.order_completed.name
  arn  = aws_lambda_function.analytics_aggregator.arn
}
```

---

## Deployment Steps

1. Deploy DynamoDB tables, SQS queues, SNS topics.
2. Deploy Lambda functions with correct IAM roles.
3. Deploy Step Functions state machine.
4. Deploy API Gateway with Cognito authorizer.
5. Deploy EventBridge rules.
6. Deploy S3 static site and CloudFront.
7. Test end-to-end by creating an order through the API.

---

## Teardown

```bash
# Delete in reverse order of dependency
terraform destroy -auto-approve

# Or manual cleanup:
# 1. Delete CloudFront distribution (disable first, wait, then delete)
# 2. Delete API Gateway
# 3. Delete Lambda functions
# 4. Delete Step Functions state machine
# 5. Delete SQS queues
# 6. Delete SNS topics
# 7. Delete EventBridge rules
# 8. Delete DynamoDB tables
# 9. Delete Cognito User Pool
# 10. Delete S3 buckets
# 11. Delete IAM roles
```

---

## What You Learned

1. How to design an event-driven serverless architecture using 10+ AWS services.
2. How SQS decouples the API from the processing pipeline.
3. How Step Functions orchestrate multi-step workflows with error handling.
4. How EventBridge enables loose coupling between system components.
5. How SNS delivers notifications to end users.
6. How DLQs capture failed messages for debugging.
7. The complete flow: API -> Queue -> Workflow -> Events -> Notifications.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- System Components
- Lambda Functions (Python Skeletons)
- Terraform Infrastructure (Key Resources)
- Deployment Steps

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

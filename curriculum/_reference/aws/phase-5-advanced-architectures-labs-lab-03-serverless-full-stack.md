# Lab 03: Full Serverless Application

## Objective

Build a complete serverless application: S3 (static website hosting) + API Gateway (REST API) + Lambda (backend logic) + DynamoDB (data store) + Cognito (authentication). This lab demonstrates the most common serverless pattern tested on the SAA-C03.

## Estimated Cost

- **Mostly Free Tier.** All services used (Lambda, API Gateway, DynamoDB, Cognito, S3) have generous free tiers. You will not incur meaningful charges for this lab.

## Architecture

```
+-------------------+                  +-------------------+
| S3 Bucket         |                  | Cognito User Pool |
| (Static Website)  |                  | (Authentication)  |
| index.html        |                  |                   |
| app.js            |                  | Sign Up / Sign In |
+--------+----------+                  +--------+----------+
         |                                      |
         | User loads page                      | JWT Token
         v                                      v
+-----------------------------------------------------------+
| Browser                                                   |
| 1. Loads static files from S3                             |
| 2. User signs in via Cognito                              |
| 3. Sends API requests with JWT token in Authorization     |
+----------------------------+------------------------------+
                             |
                             | HTTPS + JWT Token
                             v
                  +-------------------+
                  | API Gateway       |
                  | (REST API)        |
                  | - /items GET      |
                  | - /items POST     |
                  | - /items/{id} GET |
                  | - /items/{id} DEL |
                  | Cognito Authorizer|
                  +--------+----------+
                           |
                           | Lambda Proxy Integration
                           v
                  +-------------------+
                  | Lambda Function   |
                  | (Python 3.12)     |
                  | - CRUD operations |
                  +--------+----------+
                           |
                           | Boto3 SDK
                           v
                  +-------------------+
                  | DynamoDB Table    |
                  | (items)           |
                  | PK: userId        |
                  | SK: itemId        |
                  +-------------------+
```

---

## Part 1: Create DynamoDB Table

### AWS CLI

```bash
TABLE_NAME="serverless-lab-items"

aws dynamodb create-table \
    --table-name $TABLE_NAME \
    --attribute-definitions \
        AttributeName=userId,AttributeType=S \
        AttributeName=itemId,AttributeType=S \
    --key-schema \
        AttributeName=userId,KeyType=HASH \
        AttributeName=itemId,KeyType=RANGE \
    --billing-mode PAY_PER_REQUEST \
    --region us-east-1

echo "DynamoDB table created: $TABLE_NAME"
```

---

## Part 2: Create Lambda Function

### Lambda Code (Python)

```python
# File: lambda_function.py
"""
Serverless Lab - CRUD Lambda Function
Handles API Gateway proxy integration for items CRUD operations.
"""

import json
import boto3
import uuid
import os
from datetime import datetime

dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(os.environ.get("TABLE_NAME", "serverless-lab-items"))


def lambda_handler(event, context):
    """Main handler for API Gateway proxy integration."""
    http_method = event["httpMethod"]
    path = event["path"]

    # Extract userId from Cognito JWT claims
    user_id = event["requestContext"]["authorizer"]["claims"]["sub"]

    try:
        if http_method == "GET" and path == "/items":
            return get_all_items(user_id)
        elif http_method == "POST" and path == "/items":
            body = json.loads(event["body"])
            return create_item(user_id, body)
        elif http_method == "GET" and path.startswith("/items/"):
            item_id = path.split("/")[-1]
            return get_item(user_id, item_id)
        elif http_method == "DELETE" and path.startswith("/items/"):
            item_id = path.split("/")[-1]
            return delete_item(user_id, item_id)
        else:
            return response(404, {"error": "Not found"})
    except Exception as e:
        print(f"Error: {str(e)}")
        return response(500, {"error": "Internal server error"})


def get_all_items(user_id):
    """Get all items for a user."""
    result = table.query(
        KeyConditionExpression=boto3.dynamodb.conditions.Key("userId").eq(user_id)
    )
    return response(200, {"items": result["Items"]})


def create_item(user_id, body):
    """Create a new item."""
    item_id = str(uuid.uuid4())
    item = {
        "userId": user_id,
        "itemId": item_id,
        "name": body.get("name", "Untitled"),
        "description": body.get("description", ""),
        "createdAt": datetime.utcnow().isoformat(),
    }
    table.put_item(Item=item)
    return response(201, {"item": item})


def get_item(user_id, item_id):
    """Get a specific item."""
    result = table.get_item(Key={"userId": user_id, "itemId": item_id})
    item = result.get("Item")
    if not item:
        return response(404, {"error": "Item not found"})
    return response(200, {"item": item})


def delete_item(user_id, item_id):
    """Delete an item."""
    table.delete_item(Key={"userId": user_id, "itemId": item_id})
    return response(200, {"message": "Item deleted"})


def response(status_code, body):
    """Create API Gateway proxy response."""
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Headers": "Content-Type,Authorization",
            "Access-Control-Allow-Methods": "GET,POST,DELETE,OPTIONS",
        },
        "body": json.dumps(body, default=str),
    }
```

### Deploy Lambda with CLI

```bash
# Create the deployment package
mkdir -p ~/serverless-lab/lambda
# Save the Python code above as lambda_function.py in ~/serverless-lab/lambda/

cd ~/serverless-lab/lambda
zip function.zip lambda_function.py

# Create IAM role for Lambda
ROLE_ARN=$(aws iam create-role \
    --role-name serverless-lab-lambda-role \
    --assume-role-policy-document '{
        "Version": "2012-10-17",
        "Statement": [{
            "Effect": "Allow",
            "Principal": {"Service": "lambda.amazonaws.com"},
            "Action": "sts:AssumeRole"
        }]
    }' \
    --query 'Role.Arn' --output text)

# Attach policies
aws iam attach-role-policy \
    --role-name serverless-lab-lambda-role \
    --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

# Create inline policy for DynamoDB access
aws iam put-role-policy \
    --role-name serverless-lab-lambda-role \
    --policy-name DynamoDBAccess \
    --policy-document '{
        "Version": "2012-10-17",
        "Statement": [{
            "Effect": "Allow",
            "Action": [
                "dynamodb:GetItem",
                "dynamodb:PutItem",
                "dynamodb:DeleteItem",
                "dynamodb:Query"
            ],
            "Resource": "arn:aws:dynamodb:us-east-1:*:table/serverless-lab-items"
        }]
    }'

# Wait for role propagation
sleep 10

# Create Lambda function
LAMBDA_ARN=$(aws lambda create-function \
    --function-name serverless-lab-api \
    --runtime python3.12 \
    --handler lambda_function.lambda_handler \
    --role $ROLE_ARN \
    --zip-file fileb://function.zip \
    --environment Variables="{TABLE_NAME=serverless-lab-items}" \
    --timeout 30 \
    --memory-size 128 \
    --region us-east-1 \
    --query 'FunctionArn' --output text)

echo "Lambda ARN: $LAMBDA_ARN"
```

---

## Part 3: Create Cognito User Pool

```bash
# Create User Pool
USER_POOL_ID=$(aws cognito-idp create-user-pool \
    --pool-name serverless-lab-users \
    --auto-verified-attributes email \
    --username-attributes email \
    --policies '{"PasswordPolicy":{"MinimumLength":8,"RequireUppercase":true,"RequireLowercase":true,"RequireNumbers":true,"RequireSymbols":false}}' \
    --region us-east-1 \
    --query 'UserPool.Id' --output text)

echo "User Pool ID: $USER_POOL_ID"

# Create App Client
CLIENT_ID=$(aws cognito-idp create-user-pool-client \
    --user-pool-id $USER_POOL_ID \
    --client-name serverless-lab-web-client \
    --explicit-auth-flows ALLOW_USER_PASSWORD_AUTH ALLOW_REFRESH_TOKEN_AUTH \
    --generate-secret \
    --region us-east-1 \
    --query 'UserPoolClient.ClientId' --output text)

echo "App Client ID: $CLIENT_ID"
```

---

## Part 4: Create API Gateway

```bash
# Create REST API
API_ID=$(aws apigateway create-rest-api \
    --name serverless-lab-api \
    --description "Serverless Lab REST API" \
    --endpoint-configuration types=REGIONAL \
    --region us-east-1 \
    --query 'id' --output text)

echo "API ID: $API_ID"

# Get root resource ID
ROOT_ID=$(aws apigateway get-resources \
    --rest-api-id $API_ID \
    --region us-east-1 \
    --query 'items[?path==`/`].id' --output text)

# Create /items resource
ITEMS_ID=$(aws apigateway create-resource \
    --rest-api-id $API_ID \
    --parent-id $ROOT_ID \
    --path-part items \
    --region us-east-1 \
    --query 'id' --output text)

# Create /items/{id} resource
ITEM_ID_RESOURCE=$(aws apigateway create-resource \
    --rest-api-id $API_ID \
    --parent-id $ITEMS_ID \
    --path-part "{id}" \
    --region us-east-1 \
    --query 'id' --output text)

# Create Cognito Authorizer
AUTHORIZER_ID=$(aws apigateway create-authorizer \
    --rest-api-id $API_ID \
    --name CognitoAuthorizer \
    --type COGNITO_USER_POOLS \
    --provider-arns arn:aws:cognito-idp:us-east-1:$(aws sts get-caller-identity --query Account --output text):userpool/$USER_POOL_ID \
    --identity-source 'method.request.header.Authorization' \
    --region us-east-1 \
    --query 'id' --output text)

# Create GET method on /items with Cognito authorizer
aws apigateway put-method \
    --rest-api-id $API_ID \
    --resource-id $ITEMS_ID \
    --http-method GET \
    --authorization-type COGNITO_USER_POOLS \
    --authorizer-id $AUTHORIZER_ID \
    --region us-east-1

# Create Lambda integration for GET /items
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
aws apigateway put-integration \
    --rest-api-id $API_ID \
    --resource-id $ITEMS_ID \
    --http-method GET \
    --type AWS_PROXY \
    --integration-http-method POST \
    --uri "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/${LAMBDA_ARN}/invocations" \
    --region us-east-1

# Create POST method on /items
aws apigateway put-method \
    --rest-api-id $API_ID \
    --resource-id $ITEMS_ID \
    --http-method POST \
    --authorization-type COGNITO_USER_POOLS \
    --authorizer-id $AUTHORIZER_ID \
    --region us-east-1

aws apigateway put-integration \
    --rest-api-id $API_ID \
    --resource-id $ITEMS_ID \
    --http-method POST \
    --type AWS_PROXY \
    --integration-http-method POST \
    --uri "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/${LAMBDA_ARN}/invocations" \
    --region us-east-1

# Grant API Gateway permission to invoke Lambda
aws lambda add-permission \
    --function-name serverless-lab-api \
    --statement-id apigateway-invoke \
    --action lambda:InvokeFunction \
    --principal apigateway.amazonaws.com \
    --source-arn "arn:aws:execute-api:us-east-1:${ACCOUNT_ID}:${API_ID}/*" \
    --region us-east-1

# Deploy the API
aws apigateway create-deployment \
    --rest-api-id $API_ID \
    --stage-name prod \
    --region us-east-1

API_URL="https://${API_ID}.execute-api.us-east-1.amazonaws.com/prod"
echo "API URL: $API_URL"
```

---

## Part 5: Create S3 Static Website

```bash
WEBSITE_BUCKET="serverless-lab-site-$(date +%s)"

# Create bucket
aws s3 mb s3://$WEBSITE_BUCKET --region us-east-1

# Enable static website hosting
aws s3 website s3://$WEBSITE_BUCKET --index-document index.html --error-document error.html

# Create the frontend HTML
cat > ~/serverless-lab/index.html << HTMLEOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Serverless Lab - Items Manager</title>
    <style>
        body { font-family: Arial, sans-serif; max-width: 800px; margin: 40px auto; padding: 0 20px; }
        h1 { color: #232f3e; }
        .btn { padding: 8px 16px; background: #ff9900; border: none; cursor: pointer; margin: 4px; }
        #items { margin-top: 20px; }
        .item { padding: 10px; border: 1px solid #ddd; margin: 5px 0; }
        input { padding: 8px; margin: 4px; }
    </style>
</head>
<body>
    <h1>Serverless Items Manager</h1>
    <p>API Gateway + Lambda + DynamoDB + Cognito</p>
    <div id="auth">
        <h3>Sign In</h3>
        <input id="email" placeholder="Email" type="email">
        <input id="password" placeholder="Password" type="password">
        <button class="btn" onclick="signIn()">Sign In</button>
    </div>
    <div id="app" style="display:none;">
        <h3>Add Item</h3>
        <input id="name" placeholder="Item name">
        <input id="desc" placeholder="Description">
        <button class="btn" onclick="createItem()">Add</button>
        <button class="btn" onclick="loadItems()">Refresh</button>
        <div id="items"></div>
    </div>
    <script>
        // Configuration -- replace with your values
        const API_URL = "${API_URL}";
        let authToken = "";
        // Simplified auth flow for lab purposes
        // In production, use the Cognito SDK (amazon-cognito-identity-js)
    </script>
</body>
</html>
HTMLEOF

# Upload to S3
aws s3 cp ~/serverless-lab/index.html s3://$WEBSITE_BUCKET/index.html --content-type text/html

# Set bucket policy for public read (static website)
aws s3api put-public-access-block \
    --bucket $WEBSITE_BUCKET \
    --public-access-block-configuration \
    "BlockPublicAcls=false,IgnorePublicAcls=false,BlockPublicPolicy=false,RestrictPublicBuckets=false"

aws s3api put-bucket-policy --bucket $WEBSITE_BUCKET --policy "{
    \"Version\": \"2012-10-17\",
    \"Statement\": [{
        \"Sid\": \"PublicReadGetObject\",
        \"Effect\": \"Allow\",
        \"Principal\": \"*\",
        \"Action\": \"s3:GetObject\",
        \"Resource\": \"arn:aws:s3:::${WEBSITE_BUCKET}/*\"
    }]
}"

WEBSITE_URL="http://${WEBSITE_BUCKET}.s3-website-us-east-1.amazonaws.com"
echo "Website URL: $WEBSITE_URL"
```

---

## Part 6: Test the API with Boto3

```python
#!/usr/bin/env python3
"""Test the serverless API by creating and retrieving items."""

import boto3
import json
import requests

# Configuration -- replace with your values
API_URL = "https://YOUR_API_ID.execute-api.us-east-1.amazonaws.com/prod"
USER_POOL_ID = "us-east-1_XXXXXXXXX"
CLIENT_ID = "your-client-id"

cognito = boto3.client("cognito-idp", region_name="us-east-1")

# Create a test user
try:
    cognito.admin_create_user(
        UserPoolId=USER_POOL_ID,
        Username="testuser@example.com",
        TemporaryPassword="TempPass123!",
        UserAttributes=[{"Name": "email", "Value": "testuser@example.com"}],
    )
    print("Test user created.")
except cognito.exceptions.UsernameExistsException:
    print("Test user already exists.")

# Set permanent password
cognito.admin_set_user_password(
    UserPoolId=USER_POOL_ID,
    Username="testuser@example.com",
    Password="PermanentPass123!",
    Permanent=True,
)

# Authenticate and get token
auth_response = cognito.admin_initiate_auth(
    UserPoolId=USER_POOL_ID,
    ClientId=CLIENT_ID,
    AuthFlow="ADMIN_USER_PASSWORD_AUTH",
    AuthParameters={
        "USERNAME": "testuser@example.com",
        "PASSWORD": "PermanentPass123!",
    },
)
token = auth_response["AuthenticationResult"]["IdToken"]
print(f"Authenticated. Token (first 50 chars): {token[:50]}...")

# Test API endpoints
headers = {"Authorization": token, "Content-Type": "application/json"}

# Create an item
create_response = requests.post(
    f"{API_URL}/items",
    headers=headers,
    json={"name": "Test Item", "description": "Created via Python script"},
)
print(f"Create: {create_response.status_code} - {create_response.json()}")

# Get all items
get_response = requests.get(f"{API_URL}/items", headers=headers)
print(f"Get All: {get_response.status_code} - {get_response.json()}")
```

---

## Cleanup

```bash
# Delete API Gateway
aws apigateway delete-rest-api --rest-api-id $API_ID --region us-east-1

# Delete Lambda function
aws lambda delete-function --function-name serverless-lab-api --region us-east-1

# Delete IAM role and policies
aws iam delete-role-policy --role-name serverless-lab-lambda-role --policy-name DynamoDBAccess
aws iam detach-role-policy --role-name serverless-lab-lambda-role --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
aws iam delete-role --role-name serverless-lab-lambda-role

# Delete DynamoDB table
aws dynamodb delete-table --table-name serverless-lab-items --region us-east-1

# Delete Cognito User Pool
aws cognito-idp delete-user-pool --user-pool-id $USER_POOL_ID --region us-east-1

# Delete S3 website bucket
aws s3 rm s3://$WEBSITE_BUCKET --recursive
aws s3 rb s3://$WEBSITE_BUCKET

echo "All serverless lab resources cleaned up."
```

---

## What You Learned

1. How to build a complete serverless application from individual AWS services.
2. How API Gateway proxy integration works with Lambda.
3. How Cognito User Pools provide authentication with JWT tokens.
4. How Lambda uses IAM roles (task role) to access DynamoDB.
5. How to create a DynamoDB table with composite primary key (userId + itemId).
6. The full request flow: Client -> S3 (static) -> API Gateway -> Cognito (auth) -> Lambda -> DynamoDB.
7. All of these services are within the Free Tier for low-volume usage.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Create DynamoDB Table
- Create Lambda Function
- Create Cognito User Pool
- Create API Gateway

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

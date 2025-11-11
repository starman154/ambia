# Ambia Llama Prediction Scheduler

AWS Lambda function that runs every 5 minutes to analyze user behavior patterns and queue predictions.

## Purpose

This Lambda function powers Ambia's ambient intelligence by:
1. Analyzing user behavior patterns from `activity_log` (last 30 days)
2. Using Llama to detect patterns and predict what users will need next
3. Queueing high-confidence predictions (≥0.7) to `generation_queue`

**IMPORTANT**: This Lambda does NOT generate UI content. It only detects patterns and queues predictions. A separate Claude Lambda (to be created) will process the `generation_queue` and generate actual content for `page_cache`.

## Architecture

```
EventBridge (every 5 min) → Llama Scheduler Lambda → {
  Query activity_log (last 30 days)
  → Llama analyzes patterns
  → Queue predictions to generation_queue (confidence ≥0.7)
}

Separate Claude Lambda → {
  Query generation_queue
  → Claude generates content
  → Store in page_cache
}
```

## What This Lambda Does

1. **Get Active Users**: Find users active in last 7 days
2. **Analyze Activity**: Pull 30 days of activity history per user
3. **Pattern Detection**: Call Llama API to identify behavioral patterns
4. **Queue Predictions**: Write high-confidence predictions (≥0.7) to `generation_queue`

## What This Lambda Does NOT Do

- Generate UI content (that's Claude's job in a separate Lambda)
- Handle real-time user requests
- Block any user-facing operations
- Pre-generate content directly

## Thresholds

- **MIN_CONFIDENCE**: 0.6 (Llama must be at least 60% confident to return a pattern)
- **QUEUE_CONFIDENCE**: 0.7 (Only patterns ≥70% confidence are queued)

## Environment Variables

Required:
- `DB_HOST` - MySQL database host
- `DB_PORT` - MySQL port (default: 3306)
- `DB_NAME` - Database name
- `DB_USER` - Database user
- `DB_PASSWORD` - Database password
- `TOGETHER_AI_KEY` - Together AI API key (for Llama)

## Deployment

### 1. Install Dependencies

```bash
cd lambda/prediction_scheduler
pip install -r requirements.txt -t .
```

### 2. Create Deployment Package

```bash
# Remove old package if exists
rm -f function.zip

# Create new package
zip -r function.zip lambda_function.py pymysql certifi
```

### 3. Deploy to AWS Lambda

Using AWS CLI:
```bash
aws lambda create-function \
  --function-name ambia-llama-prediction-scheduler \
  --runtime python3.11 \
  --role arn:aws:iam::YOUR_ACCOUNT:role/lambda-execution-role \
  --handler lambda_function.lambda_handler \
  --zip-file fileb://function.zip \
  --timeout 300 \
  --memory-size 512
```

### 4. Configure Environment Variables

```bash
aws lambda update-function-configuration \
  --function-name ambia-llama-prediction-scheduler \
  --environment Variables="{
    DB_HOST=your-db-host,
    DB_PORT=3306,
    DB_NAME=ambia,
    DB_USER=admin,
    DB_PASSWORD=your-password,
    TOGETHER_AI_KEY=your-together-key
  }"
```

### 5. Create EventBridge Trigger

```bash
# Create rule to run every 5 minutes
aws events put-rule \
  --name ambia-llama-prediction-scheduler \
  --schedule-expression "rate(5 minutes)"

# Add Lambda as target
aws events put-targets \
  --rule ambia-llama-prediction-scheduler \
  --targets "Id"="1","Arn"="arn:aws:lambda:REGION:ACCOUNT:function:ambia-llama-prediction-scheduler"

# Grant EventBridge permission to invoke Lambda
aws lambda add-permission \
  --function-name ambia-llama-prediction-scheduler \
  --statement-id EventBridgeInvoke \
  --action lambda:InvokeFunction \
  --principal events.amazonaws.com \
  --source-arn arn:aws:events:REGION:ACCOUNT:rule/ambia-llama-prediction-scheduler
```

## Testing Locally

You can test the Lambda function locally:

```python
import os

# Set environment variables
os.environ['DB_HOST'] = 'your-db-host'
os.environ['DB_PORT'] = '3306'
os.environ['DB_NAME'] = 'ambia'
os.environ['DB_USER'] = 'admin'
os.environ['DB_PASSWORD'] = 'your-password'
os.environ['TOGETHER_AI_KEY'] = 'your-together-key'

# Import and run
from lambda_function import lambda_handler

result = lambda_handler({}, {})
print(result)
```

## Monitoring

**CloudWatch Logs**:
- Log group: `/aws/lambda/ambia-llama-prediction-scheduler`
- Check for pattern detection counts and errors

**Key Metrics**:
- Invocations per 5 minutes
- Duration (should be < 300s)
- Error rate
- Patterns detected per run
- Predictions queued per run

**Expected Output**:
```json
{
  "statusCode": 200,
  "body": {
    "success": true,
    "active_users": 15,
    "patterns_detected": 42,
    "predictions_queued": 28
  }
}
```

## Database Tables Used

**Reads from:**
- `activity_log` - User activity history (last 30 days)

**Writes to:**
- `generation_queue` - Queued predictions for Claude to process later

**Checks:**
- `page_cache` - Prevents duplicate predictions if already cached

## Cost Optimization

- Lambda runs every 5 minutes = ~8,640 invocations/month
- Each run: ~10-30 seconds on average (no Claude generation)
- Estimated Lambda cost: $2-5/month
- Llama API cost: ~$10-20/month (Together AI pricing)

**Total estimated cost**: $12-25/month

## Next Steps

After deploying this Lambda:
1. Create a separate Claude Generator Lambda that:
   - Reads from `generation_queue`
   - Generates UI with Claude
   - Stores in `page_cache`
   - Updates queue status
2. Set up CloudWatch alarms for errors
3. Monitor queue depth and processing times

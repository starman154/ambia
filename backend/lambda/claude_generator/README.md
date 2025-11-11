# Ambia Claude Generator Lambda

AWS Lambda function that processes the generation_queue and generates UI components with Claude.

## Purpose

This Lambda completes Ambia's ambient intelligence loop:
1. **Llama Scheduler** (every 5 min) → Detects patterns, queues predictions
2. **Claude Generator** (every 2 min) → Generates UI from queued predictions
3. **API Endpoint** → Serves cached content instantly

## What It Does

1. Queries `generation_queue` for pending jobs (status='queued')
2. For each job:
   - Gets user activity context from `activity_log`
   - Calls Claude API with Llama's pattern + user context
   - Parses Claude's JSON response (component structure)
   - Stores components in `page_cache` for instant delivery
   - Updates queue status to 'completed'

## What It Does NOT Do

- Real-time generation (that's the API endpoint)
- Pattern detection (that's Llama's job)
- User-facing requests (100% background)

## Architecture

```
EventBridge (every 2 min)
    ↓
Claude Generator Lambda
    ↓
1. SELECT * FROM generation_queue WHERE status='queued'
2. For each job:
   - Get user context
   - Call Claude API
   - Parse components
   - INSERT INTO page_cache
   - UPDATE generation_queue SET status='completed'
```

## Environment Variables

Required:
- `DB_HOST` - MySQL database host
- `DB_PORT` - MySQL port (default: 3306)
- `DB_NAME` - Database name
- `DB_USER` - Database user
- `DB_PASSWORD` - Database password
- `CLAUDE_API_KEY` - Anthropic API key

## Deployment

### 1. Install Dependencies

```bash
cd backend/lambda/claude_generator
pip3 install -r requirements.txt -t .
```

### 2. Create Deployment Package

```bash
# Remove old package if exists
rm -f function.zip

# Create new package
zip -r function.zip lambda_function.py pymysql anthropic certifi -x "*.pyc" -x "*__pycache__*"
```

### 3. Deploy to AWS Lambda

```bash
aws lambda create-function \
  --function-name ambia-claude-generator \
  --runtime python3.11 \
  --role arn:aws:iam::867112023447:role/lambda-prediction-scheduler-role \
  --handler lambda_function.lambda_handler \
  --zip-file fileb://function.zip \
  --timeout 300 \
  --memory-size 512 \
  --region us-east-2
```

### 4. Configure Environment Variables

```bash
aws lambda update-function-configuration \
  --function-name ambia-claude-generator \
  --environment Variables="{
    DB_HOST=ambia-production.cpkies6y2q57.us-east-2.rds.amazonaws.com,
    DB_PORT=3306,
    DB_NAME=ambia,
    DB_USER=admin,
    DB_PASSWORD=your-password,
    CLAUDE_API_KEY=your-claude-key
  }" \
  --region us-east-2
```

### 5. Create EventBridge Trigger

```bash
# Create rule to run every 2 minutes
aws events put-rule \
  --name ambia-claude-generator \
  --schedule-expression "rate(2 minutes)" \
  --region us-east-2

# Add Lambda as target
aws events put-targets \
  --rule ambia-claude-generator \
  --targets "Id"="1","Arn"="arn:aws:lambda:us-east-2:867112023447:function:ambia-claude-generator" \
  --region us-east-2

# Grant EventBridge permission to invoke Lambda
aws lambda add-permission \
  --function-name ambia-claude-generator \
  --statement-id EventBridgeInvoke \
  --action lambda:InvokeFunction \
  --principal events.amazonaws.com \
  --source-arn arn:aws:events:us-east-2:867112023447:rule/ambia-claude-generator \
  --region us-east-2
```

## Testing

### Local Testing

```python
import os

# Set environment variables
os.environ['DB_HOST'] = 'ambia-production.cpkies6y2q57.us-east-2.rds.amazonaws.com'
os.environ['DB_PORT'] = '3306'
os.environ['DB_NAME'] = 'ambia'
os.environ['DB_USER'] = 'admin'
os.environ['DB_PASSWORD'] = 'your-password'
os.environ['CLAUDE_API_KEY'] = 'your-claude-key'

# Import and run
from lambda_function import lambda_handler

result = lambda_handler({}, {})
print(result)
```

### Manual Invocation

```bash
aws lambda invoke \
  --function-name ambia-claude-generator \
  --region us-east-2 \
  --log-type Tail \
  response.json

cat response.json
```

## Monitoring

**CloudWatch Logs**:
- Log group: `/aws/lambda/ambia-claude-generator`
- Check for generation counts and errors

**Key Metrics**:
- Invocations per 2 minutes
- Duration (should be < 300s)
- Error rate
- Jobs processed per run
- Pages generated per run

**Expected Output**:
```json
{
  "statusCode": 200,
  "body": {
    "success": true,
    "jobs_processed": 5,
    "pages_generated": 5,
    "errors": 0
  }
}
```

## Database Tables

**Reads from:**
- `generation_queue` - Jobs queued by Llama
- `activity_log` - User context (last 14 days)

**Writes to:**
- `page_cache` - Generated components for instant delivery
- `generation_queue` - Updates status to 'completed'/'failed'

## Error Handling

- Max 3 attempts per job (`MAX_ATTEMPTS = 3`)
- Failed jobs marked as 'failed' after 3 attempts
- Errors logged to CloudWatch
- Continues processing other jobs if one fails
- Duplicate cache keys handled gracefully (updates existing)

## Cost Estimate

- Lambda invocations: ~21,600/month (every 2 min)
- Average execution: ~500ms (Claude API call)
- Claude API cost: ~$20-40/month (depends on usage patterns)
- **Total**: $20-40/month

**Note**: Only generates when Llama queues jobs, so cost scales with active users.

## Retry Logic

1. Job fails → increment `attempts`
2. If `attempts < 3` → requeue (status='queued')
3. If `attempts >= 3` → mark failed (status='failed')
4. Next run skips jobs with `attempts >= 3`

## Cache Management

- Cache validity: 30 minutes from generation
- Uses same cache_key algorithm as backend
- Duplicate keys update existing cache entry
- Relevance score from Llama's confidence

# Deploy to AWS - Quick Steps

Your `ambia-backend.zip` is ready! Follow these steps:

## Step 1: Go to AWS Console
**Link**: https://console.aws.amazon.com/elasticbeanstalk/home?region=us-east-2

## Step 2: Create Application (2 minutes)

1. Click **"Create Application"**
2. Fill in:
   - Application name: `ambia-backend`
   - Platform: **Node.js**
   - Application code: **Upload your code**
   - Click **"Choose file"** → Select:
     ```
     /Users/jacobkaplan/ambia/backend/ambia-backend.zip
     ```
3. Click **"Create application"**
4. Wait 3-5 minutes for deployment

## Step 3: Add Environment Variables (1 minute)

Once deployment finishes:

1. Click **"Configuration"** (left sidebar)
2. Scroll to **"Software"** → Click **"Edit"**
3. Scroll to **"Environment properties"**
4. Add these (copy-paste each line):

```
PORT=8080
DB_HOST=your-rds-endpoint.rds.amazonaws.com
DB_PORT=3306
DB_NAME=ambia
DB_USER=admin
DB_PASSWORD=your-database-password
CLAUDE_API_KEY=your-anthropic-api-key
NODE_ENV=production
```

5. Click **"Apply"** (takes ~1 minute)

## Step 4: Fix RDS Security (30 seconds)

1. Open new tab: https://console.aws.amazon.com/rds/home?region=us-east-2
2. Click **"Databases"** → **"ambia-production"**
3. Scroll to **"Security group rules"**
4. Click on the security group link (sg-xxxxx)
5. Click **"Edit inbound rules"**
6. Click **"Add rule"**:
   - Type: **MySQL/Aurora**
   - Source: **Anywhere-IPv4** (0.0.0.0/0)
7. Click **"Save rules"**

## Step 5: Get Your URL

1. Back in Elastic Beanstalk, copy the URL at the top
   - Example: `ambia-backend-env.eba-xxxxx.us-east-2.elasticbeanstalk.com`

2. Test it:
   ```bash
   curl http://YOUR-URL-HERE/api/health
   ```

## Step 6: Update Flutter App

I'll do this part - just give me the URL from Step 5!

---

## If Something Goes Wrong

Check logs:
1. Go to your EB environment
2. Click **"Logs"** → **"Request Logs"** → **"Last 100 Lines"**
3. Send me any errors you see

---

**Time estimate**: ~5-7 minutes total

Ready? Go to: https://console.aws.amazon.com/elasticbeanstalk/home?region=us-east-2

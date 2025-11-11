# Ambia Backend - AWS Elastic Beanstalk Deployment Guide

## Quick Deploy (Step-by-Step)

### 1. Open AWS Console
- Go to: https://console.aws.amazon.com/
- Sign in with your AWS account
- Select region: **us-east-2 (Ohio)** (same as your RDS)

### 2. Create Elastic Beanstalk Application

1. Search for "Elastic Beanstalk" in AWS Console
2. Click **Create Application**
3. Fill in:
   - **Application name**: `ambia-backend`
   - **Platform**: Node.js
   - **Platform branch**: Node.js 18 running on 64bit Amazon Linux 2023
   - **Application code**: Upload your code
   - Click **Choose file** → Select `/Users/jacobkaplan/ambia/backend/ambia-backend.zip`
4. Click **Create application**

### 3. Configure Environment Variables

After the environment is created:

1. Go to **Configuration** → **Software** → **Edit**
2. Scroll to **Environment properties**
3. Add these variables:

```
PORT = 8080
DB_HOST = your-rds-endpoint.rds.amazonaws.com
DB_PORT = 3306
DB_NAME = ambia
DB_USER = admin
DB_PASSWORD = your-database-password-here
CLAUDE_API_KEY = your-anthropic-api-key-here
NODE_ENV = production
```

4. Click **Apply**

### 4. Update RDS Security Group

Your RDS needs to allow connections from Elastic Beanstalk:

1. Go to **RDS Console** → **Databases** → **ambia-production**
2. Click on **VPC security groups** link
3. Click **Inbound rules** → **Edit inbound rules**
4. Click **Add rule**:
   - **Type**: MySQL/Aurora
   - **Source**: Custom → Select the Elastic Beanstalk security group
   - Or: **Source**: Anywhere-IPv4 (0.0.0.0/0) - Less secure but easier
5. **Save rules**

### 5. Get Your API URL

1. In Elastic Beanstalk console, click on your environment
2. Copy the **Environment URL** (e.g., `ambia-backend.us-east-2.elasticbeanstalk.com`)
3. This is your new backend URL!

### 6. Update Flutter App

Open `/Users/jacobkaplan/ambia/lib/services/ambia_service.dart` and change:

```dart
// OLD:
static const String _backendUrl = 'http://localhost:3000/api/ambia';

// NEW:
static const String _backendUrl = 'http://YOUR-EB-URL-HERE/api/ambia';
// Example: 'http://ambia-backend.us-east-2.elasticbeanstalk.com/api/ambia'
```

### 7. Test Your Deployment

```bash
# Test health check
curl http://YOUR-EB-URL/api/health

# Should return:
# {"status":"healthy","timestamp":"..."}
```

---

## Alternative: Faster Deploy with EB CLI

If you have AWS CLI configured:

```bash
# Install EB CLI
pip install awsebcli --upgrade

# Initialize (in backend directory)
cd /Users/jacobkaplan/ambia/backend
eb init -p node.js-18 ambia-backend --region us-east-2

# Create environment with environment variables
eb create ambia-backend-env \
  --envvars PORT=8080,DB_HOST=your-rds-endpoint.rds.amazonaws.com,DB_PORT=3306,DB_NAME=ambia,DB_USER=admin,DB_PASSWORD=your-password,CLAUDE_API_KEY=your-api-key,NODE_ENV=production

# Get URL
eb status | grep CNAME
```

---

## Troubleshooting

### App shows "502 Bad Gateway"
- Check environment logs in EB Console
- Verify environment variables are set correctly
- Make sure PORT is 8080 (not 3000)

### Database connection timeout
- Update RDS security group to allow EB connection
- Verify DB credentials in environment variables

### Need to update code?
```bash
# Update package
cd /Users/jacobkaplan/ambia/backend
zip -r ambia-backend.zip . -x "*.git*" "node_modules/*" ".env" "database/*"

# Upload in EB Console: Application versions → Upload
```

---

## Cost Estimate
- **Elastic Beanstalk**: Free tier (t2.micro)
- **EC2 Instance**: ~$10/month (after free tier)
- **Load Balancer** (optional): ~$16/month

**Total**: ~$0-26/month depending on usage

---

## Next Steps After Deployment

1. Set up HTTPS (free with AWS Certificate Manager)
2. Configure auto-scaling for production
3. Set up monitoring with CloudWatch
4. Configure backup strategy

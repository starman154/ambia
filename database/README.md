# Ambia Database

This directory contains the database schema and migrations for Ambia's backend.

## Database Information

- **Engine**: MySQL 8.0.42
- **Instance**: ambia-production (AWS RDS)
- **Region**: us-east-2
- **Instance Class**: db.t4g.micro
- **Storage**: 20GB GP3

## Schema Overview

### Tables

1. **users** - User accounts and authentication
   - Supports email or phone number authentication
   - Stores device ID for device-based auth
   - User preferences stored as JSONB

2. **conversations** - Chat sessions
   - Links to users
   - Stores contextual information (location, time, weather)
   - Tracks conversation metadata

3. **messages** - Individual messages
   - User messages and Ambia responses
   - Stores full layout JSON from Claude API
   - Links to conversations

4. **interactions** - User interaction tracking
   - Tracks taps, swipes, expansions, dismissals
   - Links to specific cards in messages
   - Stores interaction metadata

## Running Migrations

### Prerequisites

Make sure your database is running. You can check with:

```bash
aws rds describe-db-instances \
  --profile jacob \
  --db-instance-identifier ambia-production \
  --region us-east-2 \
  --query 'DBInstances[0].[DBInstanceStatus,Endpoint.Address]' \
  --output table
```

### Apply Migrations

Once the database is available, run:

```bash
./database/apply_migrations.sh
```

Or manually with mysql:

```bash
# Load credentials from .env.database
source .env.database

# Apply migration
mysql -h $DB_HOST -P $DB_PORT -u $DB_USER -p"$DB_PASSWORD" < database/migrations/001_initial_schema.sql
```

## Connection

Database credentials are stored in `.env.database` (git-ignored).

Connection string format:
```
mysql -h ambia-production.xxx.us-east-2.rds.amazonaws.com -P 3306 -u admin -p
```

## Security

- Database is encrypted at rest (AWS KMS)
- Credentials stored in `.env.database` (never commit)
- Publicly accessible for development (restrict in production)
- 7-day backup retention

## Maintenance

- Automatic backups: Daily at 3:00-4:00 AM EST
- Maintenance window: Monday 4:00-5:00 AM EST
- Auto minor version upgrades: Enabled

#!/bin/bash

# Ambia Database Migration Script
# Applies all SQL migrations in order

set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Ambia Database Migration Tool${NC}"
echo "================================"
echo ""

# Check if .env.database exists
if [ ! -f ".env.database" ]; then
    echo -e "${RED}Error: .env.database file not found${NC}"
    echo "Please ensure the database credentials file exists"
    exit 1
fi

# Load environment variables
source .env.database

# Check if DB_HOST is set
if [ -z "$DB_HOST" ]; then
    echo -e "${YELLOW}Warning: DB_HOST is not set${NC}"
    echo "Checking if database is ready..."

    # Try to get the endpoint from AWS
    DB_ENDPOINT=$(aws rds describe-db-instances \
        --profile jacob \
        --db-instance-identifier ambia-production \
        --region us-east-2 \
        --query 'DBInstances[0].Endpoint.Address' \
        --output text 2>/dev/null)

    if [ "$DB_ENDPOINT" == "None" ] || [ -z "$DB_ENDPOINT" ]; then
        echo -e "${RED}Error: Database is not ready yet${NC}"
        echo "The RDS instance is still being created. Please wait a few minutes."
        exit 1
    fi

    echo -e "${GREEN}Database endpoint found: $DB_ENDPOINT${NC}"
    DB_HOST=$DB_ENDPOINT

    # Update .env.database with the endpoint
    sed -i.bak "s|^DB_HOST=.*|DB_HOST=$DB_HOST|" .env.database
    echo -e "${GREEN}Updated .env.database with endpoint${NC}"
fi

# MySQL client path
MYSQL="/opt/homebrew/opt/mysql-client/bin/mysql"

# Test database connection with mysql
echo "Testing database connection..."
if ! $MYSQL -h $DB_HOST -P $DB_PORT -u $DB_USER -p"$DB_PASSWORD" -e "SELECT 1" > /dev/null 2>&1; then
    echo -e "${RED}Error: Cannot connect to database${NC}"
    echo "Please check your credentials and network connection"
    exit 1
fi

echo -e "${GREEN}✓ Database connection successful${NC}"
echo ""

# Apply migrations
echo "Applying migrations..."
for migration in database/migrations/*.sql; do
    if [ -f "$migration" ]; then
        echo -e "${YELLOW}Applying: $(basename $migration)${NC}"
        $MYSQL -h $DB_HOST -P $DB_PORT -u $DB_USER -p"$DB_PASSWORD" < "$migration"
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ Migration applied successfully${NC}"
        else
            echo -e "${RED}✗ Migration failed${NC}"
            exit 1
        fi
        echo ""
    fi
done

echo -e "${GREEN}All migrations completed successfully!${NC}"
echo ""
echo "Database is ready for use."

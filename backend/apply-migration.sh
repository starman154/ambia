#!/bin/bash

# Apply page_cache migration
# Run this script from the EB instance

# Load environment variables from .env
export $(cat /var/app/current/.env | grep -v '^#' | xargs)

# Apply the migration
/usr/bin/mysql -h $DB_HOST -P $DB_PORT -u $DB_USER -p$DB_PASSWORD $DB_NAME < /var/app/current/database/migrations/002_page_cache.sql

echo "Migration applied successfully!"

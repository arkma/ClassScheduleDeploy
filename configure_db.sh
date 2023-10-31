#!/bin/bash

if [ ! -f "$ENV_FILE" ]; then
    echo "$ENV_FILE does not exists!"
    exit 1
fi

source "$ENV_FILE"

# Configure PostgreSQL
sudo -u postgres psql -c "CREATE USER $POSTGRES_ADMIN_USERNAME WITH PASSWORD '$POSTGRES_ADMIN_PASSWORD';" \
                      -c "CREATE DATABASE $POSTGRES_DB_NAME OWNER $POSTGRES_ADMIN_USERNAME;" \
                      -c "CREATE DATABASE $POSTGRES_TEST_DB_NAME OWNER $POSTGRES_ADMIN_USERNAME;"

# Create .pgpass file
sudo touch "$POSTGRES_PGPASS_FILE"
echo "127.0.0.1:5432:*:$POSTGRES_ADMIN_USERNAME:$POSTGRES_ADMIN_PASSWORD" | sudo tee "$POSTGRES_PGPASS_FILE" > /dev/null
sudo chmod 0600 "$POSTGRES_PGPASS_FILE"
sudo chown postgres:postgres "$POSTGRES_PGPASS_FILE"
echo "PGPASSFILE=$POSTGRES_PGPASS_FILE" | sudo tee -a /etc/environment > /dev/null
sudo systemctl restart postgresql

if [ -f "$DUMP_FILE" ]; then
    echo "Restoring initial data from the dump..."
    sudo -u postgres psql --set ON_ERROR_STOP=off -U "$POSTGRES_ADMIN_USERNAME" -h 127.0.0.1 -d "$POSTGRES_DB_NAME" -f "$DUMP_FILE" > /dev/null 2>&1
    else
    echo "Warning: Initial data file $DUMP_FILE is not provided. Skipping data restoration."
fi
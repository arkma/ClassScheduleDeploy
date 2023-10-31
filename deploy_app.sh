#!/bin/bash

if [ ! -f "$ENV_FILE" ]; then
    echo "$ENV_FILE does not exists!"
    exit 1
fi

source "$ENV_FILE"

# Deploy application to tomcat
sudo systemctl stop tomcat9

# Create `setenv.sh` with credentials
cat <<EOT | sudo tee "$TOMCAT_SETENV_PATH/setenv.sh" > /dev/null
# Postgres
export POSTGRES_URL=$POSTGRES_URL
export POSTGRES_USERNAME=$POSTGRES_ADMIN_USERNAME
export POSTGRES_PASSWORD=$POSTGRES_ADMIN_PASSWORD
# Redis
export REDIS_URL=$REDIS_URL
# Mongo
export MONGO_DATABASE=$MONGO_DATABASE
export MONGO_URL=$MONGO_URL
# JWT
export JWT_TOKEN=$JWT_TOKEN
export JWT_EXPIRED=$JWT_EXPIRED
EOT

sudo chown tomcat:adm "$TOMCAT_SETENV_PATH/setenv.sh"
sudo chmod 700 "$TOMCAT_SETENV_PATH/setenv.sh"
sudo rm -r "$TOMCAT_WEBAPPS_PATH/ROOT"
sudo cp "$PROJECT_PATH/$PROJECT_DIR/build/libs/class_schedule.war" "$TOMCAT_WEBAPPS_PATH/ROOT.war"

# Restart Tomcat to deploy the application
sudo systemctl start tomcat9

echo "Waiting for application to start..."
attempt_counter=0
max_attempts=10
until $(curl --output /dev/null --silent --head --fail "$APP_RUNNING_TEST_URL"); do
    if [ ${attempt_counter} -ge ${max_attempts} ];then
      echo "Max attempts reached. Application is not running!"
      exit 1
    fi

    printf '.'
    attempt_counter=$(($attempt_counter+1))
    sleep 5
done

# Check if all works
if [ $(curl --silent "$APP_RUNNING_TEST_URL"| jq length) -ge 1 ];then
   echo "Application deployed successfully."
else
   echo "No data in the database. Application might not be functioning correctly."
fi
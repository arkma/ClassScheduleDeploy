#!/bin/bash

sudo apt-get install -y gnupg wget curl

# Configure Postgres repositories
sudo sh -c 'echo "deb https://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add - ## Change apt-key

# Configure MongoDB repositories
curl -fsSL https://pgp.mongodb.com/server-7.0.asc | \
   sudo gpg -o /usr/share/keyrings/mongodb-server-7.0.gpg \
   --dearmor
echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list

# Install packages
sudo apt-get update
sudo apt-get install -y openjdk-11-jdk \
                        tomcat9 \
                        postgresql-15 \
                        postgresql-client-15 \
                        redis-server \
                        nodejs npm \
                        mongodb-org \
                        git \
                        jq

## Install gradle
GRADLE_VERSION="7.6.3"
wget -c https://services.gradle.org/distributions/gradle-${GRADLE_VERSION}-bin.zip -P /tmp
sudo mkdir /opt/gradle
sudo unzip -d /opt/gradle/ /tmp/gradle-${GRADLE_VERSION}-bin.zip
export PATH=$PATH:/opt/gradle/gradle-${GRADLE_VERSION}/bin


# Enable and start services
sudo systemctl enable postgresql
sudo systemctl enable redis-server
sudo systemctl enable mongod
sudo systemctl enable tomcat9

sudo systemctl start postgresql
sudo systemctl start redis-server
sudo systemctl start mongod


# Load .env file
source ~/.env


# Configure PostgreSQL
sudo -u postgres psql -c "CREATE DATABASE schedule;" \
                      -c "CREATE DATABASE schedule_test;" \
                      -c "CREATE USER $POSTGRES_ADMIN_USERNAME WITH PASSWORD '$POSTGRES_ADMIN_PASSWORD';" \
                      -c "GRANT ALL PRIVILEGES ON DATABASE schedule TO $POSTGRES_ADMIN_USERNAME;" \
                      -c "ALTER DATABASE schedule OWNER TO $POSTGRES_ADMIN_USERNAME;" \
                      -c "GRANT ALL PRIVILEGES ON DATABASE schedule_test TO $POSTGRES_ADMIN_USERNAME;" \
                      -c "ALTER DATABASE schedule_test OWNER TO $POSTGRES_ADMIN_USERNAME;"

# Create .pgpass file
sudo touch /var/lib/postgresql/15/main/.pgpass
echo "127.0.0.1:5432:*:$POSTGRES_ADMIN_USERNAME:$POSTGRES_ADMIN_PASSWORD" | sudo tee /var/lib/postgresql/15/main/.pgpass > /dev/null
sudo chmod 0600 /var/lib/postgresql/15/main/.pgpass
sudo chown postgres:postgres /var/lib/postgresql/15/main/.pgpass
echo PGPASSFILE="/var/lib/postgresql/15/main/.pgpass" | sudo tee -a /etc/environment > /dev/null
sudo systemctl restart postgresql

# Restore database
sudo -u postgres psql --set ON_ERROR_STOP=off -U "$POSTGRES_ADMIN_USERNAME" -h 127.0.0.1 -d schedule -f /tmp/initial_data.dump > /dev/null 2>&1

# Clone and build project
git clone https://github.com/BlueTeam2/ClassSchedule.git ~/ClassSchedule/

# Build frontend
cd ~/ClassSchedule/frontend
echo "REACT_APP_API_BASE_URL=$REACT_APP_API_BASE_URL" > .env
npm install
npm run build

sudo rm -r ~/ClassSchedule/src/main/webapp/*
sudo cp -r ~/ClassSchedule/frontend/build/static/ ~/ClassSchedule/src/main/webapp/
sudo cp -r ~/ClassSchedule/frontend/build/assets/ ~/ClassSchedule/src/main/webapp/
sudo mkdir -p ~/ClassSchedule/src/main/webapp/WEB-INF/view/
sudo cp ~/ClassSchedule/frontend/build/*.* ~/ClassSchedule/src/main/webapp/WEB-INF/view/

# Build backend and run tests
cd ~/ClassSchedule/
sudo chmod u+x gradlew

# swap_cred() {
#     mapping="$1"
#     shift
#     awk -i inplace -F= -v OFS="=" -v env_m="$mapping" 'BEGIN {split(env_m, env_vars, "|"); for(i in env_vars) {split(env_vars[i], p, "="); m[p[1]] = p[2];}} {if($1 in m) {print $1, m[$1]} else {print;}}' "$@"
# }
# swap_cred "$PROP_MAPPING" "file1" "file2" "file3" "file4"

POSTGRES_TEST_URL=$POSTGRES_TEST_URL \
 POSTGRES_TEST_USERNAME=$POSTGRES_ADMIN_USERNAME \
 POSTGRES_TEST_PASSWORD=$POSTGRES_ADMIN_PASSWORD \
 POSTGRES_URL=$POSTGRES_URL \
 POSTGRES_USERNAME=$POSTGRES_ADMIN_USERNAME \
 POSTGRES_PASSWORD=$POSTGRES_ADMIN_PASSWORD \
 REDIS_URL=$REDIS_URL \
 MONGO_DATABASE=$MONGO_DATABASE \
 MONGO_URL=$MONGO_URL \
 JWT_TOKEN=$JWT_TOKEN \
 JWT_EXPIRED=$JWT_EXPIRED \
 ./gradlew build 


# Deploy application to tomcat
sudo systemctl stop tomcat9

# Create `setenv.sh` with credentials
cat <<EOT | sudo tee /usr/share/tomcat9/bin/setenv.sh > /dev/null
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

sudo chown tomcat:adm /usr/share/tomcat9/bin/setenv.sh
sudo chmod 700 /usr/share/tomcat9/bin/setenv.sh
sudo rm -r /var/lib/tomcat9/webapps/ROOT
sudo cp ~/ClassSchedule/build/libs/class_schedule.war /var/lib/tomcat9/webapps/ROOT.war

# Restart Tomcat to deploy the application
sudo systemctl start tomcat9

echo "Wait appltication to start."
attempt_counter=0
max_attempts=10
until $(curl --output /dev/null --silent --head --fail http://localhost:8080/public/semesters); do
    if [ ${attempt_counter} -ge ${max_attempts} ];then
      echo "Max attempts reached. Application is not running!"
      exit 1
    fi

    printf '.'
    attempt_counter=$(($attempt_counter+1))
    sleep 10
done

# sudo -u postgres psql --set ON_ERROR_STOP=off -U $POSTGRES_ADMIN_USERNAME -h 127.0.0.1 -d schedule -f /tmp/initial_data.sql > /dev/null 2>&1
# sudo -u postgres psql --set ON_ERROR_STOP=off -U $POSTGRES_ADMIN_USERNAME -h 127.0.0.1 -d schedule -f /tmp/initial_data.sql > /dev/null 2>&1

# Check if all works
if [ $(curl --silent http://localhost:8080/public/semesters | jq length) -ge 1 ];then
   echo "Application deployed successfully."
else
   echo "No data in database."
fi
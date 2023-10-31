#!/bin/bash

sudo apt-get install -y gnupg wget curl

# Configure Postgres repositories
sudo sh -c 'echo "deb https://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add - 

# Configure MongoDB repositories
curl -fsSL https://pgp.mongodb.com/server-7.0.asc | \
   sudo gpg -o /usr/share/keyrings/mongodb-server-7.0.gpg \
   --dearmor
echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list

# Install packages
sudo apt-get update
sudo apt-get install -y "openjdk-${OPENJDK_VERSION}-jdk" \
                        "tomcat${TOMCAT_VERSION}" \
                        "postgresql-$POSTGRES_VERSION" \
                        "postgresql-client-$POSTGRES_VERSION" \
                        redis-server \
                        nodejs npm \
                        mongodb-org \
                        git \
                        jq

## Install gradle
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
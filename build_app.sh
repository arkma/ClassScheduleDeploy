#!/bin/bash

if [ ! -f "$ENV_FILE" ]; then
    echo "$ENV_FILE does not exists!"
    exit 1
fi

source "$ENV_FILE"

# Clone and build project
git clone "$GIT_REPO_URL" "$PROJECT_PATH/$PROJECT_DIR/"

# Build frontend
frontend_dir="$PROJECT_PATH/$PROJECT_DIR/frontend"
cd "$frontend_dir"
echo "REACT_APP_API_BASE_URL=$REACT_APP_API_BASE_URL" > "$frontend_dir/.env"
npm install
npm run build

# Copy frontend files to backend directory
backend_static_dir="$PROJECT_PATH/$PROJECT_DIR/src/main/webapp/"
sudo rm -r "$backend_static_dir"*
sudo cp -r "$frontend_dir/build/static/" "$backend_static_dir"
sudo cp -r "$frontend_dir/build/assets/" "$backend_static_dir"
sudo mkdir -p "$backend_static_dir/WEB-INF/view/"
sudo cp "$frontend_dir/build/"*.* "$backend_static_dir/WEB-INF/view/"


# Build backend and run tests
cd "$PROJECT_PATH/$PROJECT_DIR/"
sudo chmod u+x gradlew


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
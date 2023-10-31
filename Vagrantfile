# VM configuration
RAM_MB = "2048"
CPU_COUNT = "4"

# Project configuration
GRADLE_VERSION="7.6.3"
POSTGRES_VERSION="15"
OPENJDK_VERSION="11"
TOMCAT_VERSION="9"
GIT_REPO_URL="https://github.com/BlueTeam2/ClassSchedule.git"
PROJECT_PATH="$HOME"
PROJECT_DIR="ClassSchedule"
APP_RUNNING_TEST_URL="http://localhost:8080/public/semesters"
TOMCAT_SETENV_PATH="/usr/share/tomcat9/bin"
TOMCAT_WEBAPPS_PATH="/var/lib/tomcat9/webapps"
ENV_FILE_DEST="$HOME/.env"
DUMP_FILE_DEST="/tmp/initial_data.dump"
POSTGRES_PGPASS_FILE="/var/lib/postgresql/#{POSTGRES_VERSION}/main/.pgpass"

Vagrant.configure("2") do |config|

  config.vm.box = "generic/ubuntu2204"
  # This solves ssl error while downloading box from cloud. (on Windows)
  config.vm.box_download_options = {"ssl-revoke-best-effort" => true}

  config.vm.provider "vmware_desktop" do |vmware|
    vmware.memory = RAM_MB
    vmware.cpus = CPU_COUNT
  end
  # Provisioning
  config.vm.provision "UPLOAD_ENV", type: "file", source: "./.env", destination: ENV_FILE_DEST
  config.vm.provision "UPLOAD_DUMP", type: "file", source: "./initial_data.dump", destination: DUMP_FILE_DEST
  
  config.vm.provision "DEPS", type: "shell", privileged: false, path: "install_deps.sh", env: {
    "GRADLE_VERSION" => GRADLE_VERSION,
    "POSTGRES_VERSION" => POSTGRES_VERSION,
    "OPENJDK_VERSION" => OPENJDK_VERSION,
    "TOMCAT_VERSION" => TOMCAT_VERSION
  }
  config.vm.provision "DB", type: "shell", after: "DEPS", privileged: false, path: "configure_db.sh", env: {
    "ENV_FILE" => ENV_FILE_DEST,
    "DUMP_FILE" => DUMP_FILE_DEST,
    "POSTGRES_PGPASS_FILE" => POSTGRES_PGPASS_FILE 
  }
  config.vm.provision "BUILD", type: "shell", after: "DB", privileged: false, path: "build_app.sh", env: {
    "ENV_FILE" => ENV_FILE_DEST, 
    "GIT_REPO_URL" => GIT_REPO_URL, 
    "PROJECT_PATH" => PROJECT_PATH, 
    "PROJECT_DIR" => PROJECT_DIR
  }
  config.vm.provision "DEPLOY", type: "shell", after: "BUILD", privileged: false, path: "deploy_app.sh", env: {
    "ENV_FILE" => ENV_FILE_DEST, 
    "PROJECT_PATH" => PROJECT_PATH, 
    "PROJECT_DIR" => PROJECT_DIR, 
    "APP_RUNNING_TEST_URL" => APP_RUNNING_TEST_URL,
    "TOMCAT_SETENV_PATH" => TOMCAT_SETENV_PATH,
    "TOMCAT_WEBAPPS_PATH" => TOMCAT_WEBAPPS_PATH 
  }
  config.vm.provision "APP_ADRESS", type: "shell", after: "DEPLOY", inline:<<-SHELL
  echo "Application is avaliable at http://$(hostname -I | cut -d' ' -f1):8080/"
  SHELL
  
end

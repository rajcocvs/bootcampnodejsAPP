#!/bin/bash
set -e

# ==========================================================
# SonarQube 26.3 + PostgreSQL Installation Script for EC2
# Ubuntu 22.04 / 24.04
# ==========================================================

SONAR_VERSION="26.3.0.120487"
SONAR_USER="sonarqube"
SONAR_GROUP="sonarqube"
SONAR_HOME="/opt/sonarqube"

DB_NAME="sonarqube"
DB_USER="sonar"
DB_PASS="Sonar@123"

echo "Updating system..."
apt update -y
apt upgrade -y

echo "Installing dependencies..."
apt install -y openjdk-21-jdk unzip wget postgresql postgresql-contrib

echo "Checking Java..."
java -version

# ==========================================================
# Configure PostgreSQL
# ==========================================================
echo "Configuring PostgreSQL..."
systemctl enable postgresql
systemctl start postgresql

sudo -u postgres psql <<EOF
CREATE USER ${DB_USER} WITH ENCRYPTED PASSWORD '${DB_PASS}';
CREATE DATABASE ${DB_NAME} OWNER ${DB_USER};
GRANT ALL PRIVILEGES ON DATABASE ${DB_NAME} TO ${DB_USER};
EOF

# ==========================================================
# System tuning
# ==========================================================
echo "Applying system tuning..."

cat >> /etc/sysctl.conf <<EOF
vm.max_map_count=524288
fs.file-max=131072
EOF

sysctl -p

cat >> /etc/security/limits.conf <<EOF
${SONAR_USER}   -   nofile   131072
${SONAR_USER}   -   nproc    8192
EOF

# ==========================================================
# Create SonarQube user
# ==========================================================
echo "Creating SonarQube user..."
if ! id "$SONAR_USER" >/dev/null 2>&1; then
    groupadd ${SONAR_GROUP}
    useradd -r -d ${SONAR_HOME} -g ${SONAR_GROUP} ${SONAR_USER}
fi

# ==========================================================
# Download SonarQube
# ==========================================================
echo "Downloading SonarQube..."
cd /tmp
wget https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-${SONAR_VERSION}.zip

echo "Extracting SonarQube..."
unzip sonarqube-${SONAR_VERSION}.zip -d /opt/
mv /opt/sonarqube-${SONAR_VERSION} ${SONAR_HOME}

chown -R ${SONAR_USER}:${SONAR_GROUP} ${SONAR_HOME}

# ==========================================================
# Configure SonarQube
# ==========================================================
echo "Configuring SonarQube..."

cat >> ${SONAR_HOME}/conf/sonar.properties <<EOF

sonar.jdbc.username=${DB_USER}
sonar.jdbc.password=${DB_PASS}
sonar.jdbc.url=jdbc:postgresql://localhost/${DB_NAME}

sonar.web.host=0.0.0.0
sonar.web.port=9000
EOF

sed -i "s|#RUN_AS_USER=.*|RUN_AS_USER=${SONAR_USER}|" \
${SONAR_HOME}/bin/linux-x86-64/sonar.sh

# ==========================================================
# Create systemd service
# ==========================================================
echo "Creating SonarQube service..."

cat > /etc/systemd/system/sonarqube.service <<EOF
[Unit]
Description=SonarQube service
After=network.target postgresql.service

[Service]
Type=forking
ExecStart=${SONAR_HOME}/bin/linux-x86-64/sonar.sh start
ExecStop=${SONAR_HOME}/bin/linux-x86-64/sonar.sh stop
User=${SONAR_USER}
Group=${SONAR_GROUP}
Restart=always
LimitNOFILE=131072
LimitNPROC=8192
TimeoutStartSec=5
SuccessExitStatus=143

[Install]
WantedBy=multi-user.target
EOF

# ==========================================================
# Start SonarQube
# ==========================================================
echo "Starting SonarQube..."
systemctl daemon-reload
systemctl enable sonarqube
systemctl start sonarqube

sleep 25

echo ""
echo "=================================================="
echo "SonarQube Installed Successfully"
echo "URL: http://YOUR-EC2-PUBLIC-IP:9000"
echo ""
echo "Login:"
echo "Username: admin"
echo "Password: admin"
echo ""
echo "Database:"
echo "DB Name : ${DB_NAME}"
echo "DB User : ${DB_USER}"
echo "=================================================="
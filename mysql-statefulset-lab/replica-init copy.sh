#!/bin/bash
set -e

MASTER_HOST="mysql-0.mysql"
MASTER_USER="root"
MASTER_PASSWORD="$MYSQL_ROOT_PASSWORD"

# Setup replication user on master (run only once)
if [ "$HOSTNAME" == "mysql-1" ] || [ "$HOSTNAME" == "mysql-2" ]; then
# Wait for master to be ready
  until mysqladmin ping -h "$MASTER_HOST" --silent; do
    echo "Waiting for master..."
    sleep 5
  done

  mysql -h "$MASTER_HOST" -u "$MASTER_USER" -p"$MASTER_PASSWORD" -e "CREATE USER IF NOT EXISTS 'replica'@'%' IDENTIFIED BY 'replica_pass'; GRANT REPLICATION SLAVE ON *.* TO 'replica'@'%'; FLUSH PRIVILEGES;"

  # Get master status
  STATUS=$(mysql -h "$MASTER_HOST" -u "$MASTER_USER" -p"$MASTER_PASSWORD" -e "SHOW MASTER STATUS;" | awk 'NR==2 {print $1,$2}')
  FILE=$(echo $STATUS | awk '{print $1}')
  POS=$(echo $STATUS | awk '{print $2}')

  # Configure replica
  mysql -u "$MASTER_USER" -p"$MASTER_PASSWORD" -e "CHANGE MASTER TO MASTER_HOST='$MASTER_HOST', MASTER_USER='replica', MASTER_PASSWORD='replica_pass', MASTER_LOG_FILE='$FILE', MASTER_LOG_POS=$POS; START SLAVE;"
fi

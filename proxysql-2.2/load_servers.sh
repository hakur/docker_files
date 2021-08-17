#!/bin/bash
PROXYSQL_ADMIN_PORT=6032
PROXYSQL_ADMIN_USER=$1
PROXYSQL_ADMIN_PASSWORD=$2

function proxysqlCmd(){
  mysql -u${PROXYSQL_ADMIN_USER} -p${PROXYSQL_ADMIN_PASSWORD} -P${PROXYSQL_ADMIN_PORT} -h127.0.0.1 -N -se "$1"
}

proxysqlCmd "LOAD MYSQL SERVERS FROM CONFIG;" > /dev/null 2>&1 # fresh for every shell call, this should be an standalone scheduler, write this ocde later
if [ $? != 0 ] ;then
  echo "proxysql load disk config failed"
  exit 1;
fi
proxysqlCmd "LOAD MYSQL SERVERS TO RUNTIME;" > /dev/null # fresh for every shell call, this should be an standalone scheduler, write this ocde later
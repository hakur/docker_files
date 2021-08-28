#!/bin/bash

CNF_FILE=${CNF_FILE:-/etc/my.cnf}

MYSQL_USER=${MYSQL_USER:-root}
MYSQL_PASSWORD=${MYSQL_PASSWORD:-$MYSQL_ROOT_PASSWORD}
MYSQL_CONN_PORT=${MYSQL_CONN_PORT:-3306}
MYSQL_NODES=${MYSQL_NODES}
CLUSTER_MODE=${CLUSTER_MODE:-SemiSync} #cluster mode , values are [ Async SemiSync MGRSP MGRMP ] 
MAX_SERVER_ID=${MAX_SERVER_ID:-2}

FULL_BACKUP_ENABLED=${FULL_BACKUP_ENABLED:-"true"}
FULL_BACKUP_DIR=${FULL_BACKUP_DIR:-/data/full}

INCREMENT_BACKUP_ENABLED=${INCREMENT_BACKUP_ENABLED:-"true"}
INCREMENT_BACKUP_DIR=${INCREMENT_BACKUP_DIR:-/data/increment}

function echolog() {
    local timeStr=$(date '+%Y-%m-%d %H:%M:%S')
    echo "function.sh log $timeStr -> $1"
}

function fullBackup() {
    local targetDir=$1
    local server=$(findMasterServer)

    if [ "$targetDir" == "" ];then
        echolog "targetDir argument is empty"
        return 1
    fi

    if [ "$server" == "" ];then
        echolog "master server not found"
        return 1
    fi

    if [ -d $targetDir ];then
        # dir exists , skip that means last backup is successfully
        echolog "targetDir=[$targetDir] caontains files, skip backup"
        return 1
    else
        mkdir -p $targetDir
    fi

    echolog "start full backup, master server is ${server}"
    xtrabackup --default-file=$CNF_FILE --host=$server --user=$MYSQL_USER --password=$MYSQL_PASSWORD --backup --port=$MYSQL_CONN_PORT --target-dir=$targetDir --datadir=/data/mysql/$server
    local code=$?
    if [ $code != 0 ];then
        rm -rf $targetDir
    fi

    return $code
}

function incrementBackup() {
    local targetDir=$1
    local fullBackupDir=$targetDir"_base"
    local server=$(findMasterServer)

    if [ "$targetDir" == "" ];then
        echolog "targetDir argument is empty"
        return 1
    fi

    if [ "$server" == "" ];then
        echolog "master server not found"
        return 1
    fi

    fullBackup $fullBackupDir

    if [ -d $targetDir ];then
        #dir exists , skip that means last backup is successfully
        return 0
    else
        mkdir -p $targetDir
    fi

    xtrabackup --default-file=$CNF_FILE --host=$server --user=$MYSQL_USER --password=$MYSQL_PASSWORD --backup --port=$MYSQL_CONN_PORT --target-dir=$targetDir --incremental-basedir=$fullBackupDir
    local code=$?
    if [ $code != 0 ];then
        rm -rf $targetDir
    fi
    return $code
}

# prepare , sync mysql and backup data before restore
function prepare() {
    local targetDir=$1
    xtrabackup --default-file=$CNF_FILE --prepare --target-dir=$targetDir
    local code=$?
    if [ $code != 0 ];then
        echolog "xtrabackup prepare for dir=[$targetDir] failed"
    fi
    return $code
}

function restore() {
    local targetDir=$1
    prepare $targetDir
    local code=$?
    if [ $code != 0 ];then
        echolog "restore from dir=[$targetDir] failed"
        return $code
    fi

    xtrabackup --default-file=$CNF_FILE --copy-back --target-dir=$targetDir
}

function findMasterServer() {
    local serverID=0
    local masterAddr=""

    if [ "$CLUSTER_MODE" == "SemiSync" ];then
        masterAddr=$(findMasterServerSymiSync)
        if [ "$masterAddr" != "" ];then
            echo $masterAddr
        fi
    fi
}

function findMasterServerSymiSync() {
    for i in $MYSQL_NODES;do 
        mysqladmin -uroot -p${MYSQL_ROOT_PASSWORD} -h$i ping > /dev/null 2>/dev/null
        if [ $? == 0 ] ;then
            lastHealthHost=$i
            masterOn=$(mysql -uroot -p${MYSQL_ROOT_PASSWORD} -h$i -N -se "show  variables like 'rpl_semi_sync_master_enabled';" 2>/dev/null | awk '{print $2}')
            if [ $masterOn == "ON" ];then
                echo $i
                break
            fi
        fi
    done
}

function findBestPrimaryServer() {
    for server in $MYSQL_NODES;do
        if [ "$(checkWriteNodeIsOk $server)" == "true" ];then
            local serverUUID=$(mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -P$MYSQL_PORT -h$server -N -se "show variables like 'server_uuid';" | awk '{print $2}')
            local primaryServerUUID=$(mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -P$MYSQL_PORT -h$server -N -se "SELECT VARIABLE_VALUE FROM performance_schema.global_status WHERE VARIABLE_NAME= 'group_replication_primary_member' AND VARIABLE_VALUE='${serverUUID}';")
            if [ "$primaryServerUUID" == "$serverUUID" ] && [ "$serverUUID" != "" ];then
                echo $server
                break
            fi
        fi
    done
}

function uploadS3() {
    mc alias set myminio/ http://MINIO-SERVER MYUSER MYPASSWORD
}
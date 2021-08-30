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

S3_ENDPOINT=${S3_ENDPOINT}
S3_BUCKET=${S3_BUCKET}
S3_ACCESS_KEY=${S3_ACCESS_KEY}
S3_SECURITY_KEY=${S3_SECURITY_KEY}
S3_OBJECT_DIR=${S3_OBJECT_DIR}

ATTACHED_MYSQL_HOST=${ATTACHED_MYSQL_HOST}

function echolog() {
    local timeStr=$(date '+%Y-%m-%d %H:%M:%S')
    echo "function.sh log $timeStr -> $1"
}

function fullBackup() {
    local targetDir=$1
    local server=$(findMasterServer)

    if [ "$server" == "" ];then
        echolog "master server not found"
        return 1
    fi

    if [ "$server" != "$ATTACHED_MYSQL_HOST" ];then
        local timePassed=0
        while [ true ];do
            let timePassed+2
            # 持续检测master一段时间，防止master因为故障转移跑到别的节点去了导致备份失败
            server=$(findMasterServer)
            if [ "$server" != "$ATTACHED_MYSQL_HOST" ];then
                if [ $timePassed -gt 600 ];then # 持续检测十分钟
                    echolog "not first available master node, skip backup"
                    break
                fi
            else
                break
            fi 
            sleep 1
        done
    fi

    echolog "start full backup, master server is ${server}"
    if [ "$ENABLE_S3_UPLOAD" == "true" ];then
        mc alias set auth $S3_ENDPOINT $S3_ACCESS_KEY $S3_SECURITY_KEY
        xtrabackup --default-file=$CNF_FILE --host=$server --user=$MYSQL_USER --password=$MYSQL_PASSWORD --backup --port=$MYSQL_CONN_PORT --datadir=/data/mysql --stream=tar | gzip | mc pipe auth/$S3_BUCKET/$S3_OBJECT_DIR/$(basename $targetDir)_from-${ATTACHED_MYSQL_HOST}.tar.gz
    else
        if [ "$targetDir" == "" ];then
            echolog "targetDir argument is empty"
            return 1
        fi

        if [ -d $targetDir ];then
            # dir exists , skip that means last backup is successfully
            echolog "targetDir=[$targetDir] caontains files, skip backup"
            return 1
        else
            mkdir -p $targetDir
        fi

        xtrabackup --default-file=$CNF_FILE --host=$server --user=$MYSQL_USER --password=$MYSQL_PASSWORD --backup --port=$MYSQL_CONN_PORT --target-dir=$targetDir --datadir=/data/mysql
    fi

    local code=$?
    if [ $code != 0 ];then
        rm -rf $targetDir
    fi

    return $code
}

# function incrementBackup() {
#     local targetDir=$1
#     local fullBackupDir=$targetDir"_base"
#     local server=$(findMasterServer)

#     if [ "$targetDir" == "" ];then
#         echolog "targetDir argument is empty"
#         return 1
#     fi

#     if [ "$server" == "" ];then
#         echolog "master server not found"
#         return 1
#     fi

#     fullBackup $fullBackupDir

#     if [ -d $targetDir ];then
#         #dir exists , skip that means last backup is successfully
#         return 0
#     else
#         mkdir -p $targetDir
#     fi

#     if [ "ENABLE_S3_UPLOAD" =="true" ];then
#         xtrabackup --default-file=$CNF_FILE --host=$server --user=$MYSQL_USER --password=$MYSQL_PASSWORD --backup --port=$MYSQL_CONN_PORT --incremental-basedir=$fullBackupDir --stream=tar | gzip | mc alias set auth $S3_ENDPOINT $S3_ACCESS_KEY $S3_SECURITY_KEY
#     else
#         xtrabackup --default-file=$CNF_FILE --host=$server --user=$MYSQL_USER --password=$MYSQL_PASSWORD --backup --port=$MYSQL_CONN_PORT --target-dir=$targetDir --incremental-basedir=$fullBackupDir
#     fi 

#     local code=$?
#     if [ $code != 0 ];then
#         rm -rf $targetDir
#     fi
#     return $code
# }

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
            masterOn=$(mysql --connect-timeout=2 -uroot -p${MYSQL_ROOT_PASSWORD} -h$i -N -se "show  variables like 'rpl_semi_sync_master_enabled';" 2>/dev/null | awk '{print $2}')
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
            local serverUUID=$(mysql --connect-timeout=2 -u$MYSQL_USER -p$MYSQL_PASSWORD -P$MYSQL_PORT -h$server -N -se "show variables like 'server_uuid';" | awk '{print $2}')
            local primaryServerUUID=$(mysql --connect-timeout=2 -u$MYSQL_USER -p$MYSQL_PASSWORD -P$MYSQL_PORT -h$server -N -se "SELECT VARIABLE_VALUE FROM performance_schema.global_status WHERE VARIABLE_NAME= 'group_replication_primary_member' AND VARIABLE_VALUE='${serverUUID}';")
            if [ "$primaryServerUUID" == "$serverUUID" ] && [ "$serverUUID" != "" ];then
                echo $server
                break
            fi
        fi
    done
}

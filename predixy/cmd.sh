#!/bin/bash
CONFIG_FILE=${CONFIG_FILE:-/etc/predixy.cnf}
CURRENT_SERVICE_NAME=${CURRENT_SERVICE_NAME:-redis}
WORKER_THREADS=${WORKER_THREADS:-$(nproc)}
MAX_MEMORY=${MAX_MEMORY:-1G}
CLIENT_TIMEOUT=${CLIENT_TIMEOUT:-300}
BUF_SIZE=${BUF_SIZE:-8096}


LOG_FILE=${LOG_FILE:-/var/log/predixy.log}
LOG_ROTATE=${LOG_ROTATE:-2G}
LOG_LEVEL=${LOG_LEVEL:-info}
LOG_MERGE_OUTPUT=${LOG_MERGE_OUTPUT:-1}

REDIS_PASSWORD=${REDIS_PASSWORD}
REDIS_PORT=${REDIS_PORT:-6379}
REDIS_NODES=${REDIS_NODES}

function redisServers() {
    for server in $REDIS_NODES;do
        echo "      + ${server}:${REDIS_PORT}"
    done
}

cat > $CONFIG_FILE << EOF
MaxMemory ${MAX_MEMORY}
ClientTimeout ${CLIENT_TIMEOUT}
BufSize ${BUF_SIZE}
Log ${LOG_FILE}
LogRotate ${LOG_ROTATE}

Authority {
    Auth "${REDIS_PASSWORD}" {
        Mode admin
    }
}

ClusterServerPool {
    Password "${REDIS_PASSWORD}"
    MasterReadPriority 0
    StaticSlaveReadPriority 50
    DynamicSlaveReadPriority 50
    RefreshInterval 1
    ServerTimeout 1
    ServerFailureLimit 10
    ServerRetryTimeout 1
    KeepAlive 120
    Servers {
$(redisServers)
    }
}
EOF

predixy $CONFIG_FILE \
--Name=$CURRENT_SERVICE_NAME \
--Bind=0.0.0.0:6379 \
--WorkerThreads=$WORKER_THREADS
#!/bin/bash
php-fpm -R
nginx

function watchPHP() {
    sleep 1
    fpmCount=$(ps aux|grep php-fpm|wc -l)
    if [ $fpmCount -lt 2 ] ; then
        echo "php-fpm 挂了 , 执行杀死nginx 容器执行退出"
        pkill -9 nginx
        exit 1;
    else
        watchPHP
    fi
}

function watchNginx() {
    sleep 1
    ngxCount=$(ps aux|grep nginx|wc -l)
    if [ $ngxCount -lt 2 ] ; then
        echo "nginx挂了, 执行杀死php-fpm 容器执行退出"
        pkill -9 php-fpm
        exit 1;
    else
        watchNginx
    fi
}



watchPHP&
watchNginx&

# trap ctrl-c and call ctrl_c()
trap ctrl_c INT

function ctrl_c() {
        echo "检测到CTRL-C信号 容器执行退出"
        exit 0
}

sleep infinity

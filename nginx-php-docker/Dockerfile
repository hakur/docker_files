#构建工具集合
FROM centos:7.5.1804 as build-box
RUN rm -rf /etc/yum.repos.d/* && mkdir /build
COPY Centos-7.repo /etc/yum.repos.d/CentOS-Base.repo
RUN yum clean all && yum makecache fast
WORKDIR /build
#RUN yum -y groupinstall "Development tools"
RUN yum -y install gcc libxml2-devel gd-devel libmcrypt-devel libcurl-devel openssl-devel make autoconf gcc-c++ uuid-devel libuuid-devel
# 编译mcrypt ftp://mcrypt.hellug.gr/pub/crypto/mcrypt/attic/libmcrypt/
COPY libmcrypt-2.5.7.tar.gz /build
RUN tar -xf /build/libmcrypt-2.5.7.tar.gz
RUN cd /build/libmcrypt-2.5.7 && ./configure prefix=/usr/local/libmcrypt/ && make -j $(nproc) && make install
#编译cmake
COPY cmake-3.6.2.tar.gz /build/cmake-3.6.2.tar.gz
RUN tar -xf /build/cmake-3.6.2.tar.gz
WORKDIR /build/cmake-3.6.2
RUN ./bootstrap
RUN make -j $(nproc)
RUN make install
WORKDIR /build

#构建php
FROM build-box as php-build
COPY php-7.2.12.tar.gz /build
RUN tar -xf php-7.2.12.tar.gz
RUN cd php-7.2.12 && ./configure --prefix=/server/php --with-config-file-path=/server/php/etc --with-iconv-dir --with-freetype-dir --with-jpeg-dir --with-png-dir --with-zlib --with-libxml-dir=/usr --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem --enable-inline-optimization --with-curl --enable-mbregex --enable-fpm --enable-mbstring --with-mcrypt --disable-ftp --with-gd --enable-gd-native-ttf --with-openssl --with-mhash --enable-pcntl --enable-sockets --with-xmlrpc --enable-soap --without-pear --with-gettext --enable-opcache=no --with-mysql --with-mysqli --with-pdo-mysql && \ 
    make -j $(nproc) && \
    make install

#构建nginx
FROM build-box as nginx-build
COPY nginx-1.15.6.tar.gz /build
RUN tar -xf nginx-1.15.6.tar.gz
WORKDIR /build/nginx-1.15.6
#--user=www --group=www
RUN ./configure --prefix=/server/nginx --with-http_ssl_module --with-pcre && make -j $(nproc) && make install

#构建 php phalcon mvc框架
FROM php-build as php-ext-phalcon
WORKDIR /build/
ENV PATH $PATH:/server/php/sbin:/server/php/bin
ENV getconf _NPROCESSORS_ONLN $(nproc)
COPY --from=php-build /server/php /server/
COPY cphalcon-3.4.1.tar.gz /build/cphalcon-3.4.1.tar.gz
RUN tar -xf /build/cphalcon-3.4.1.tar.gz
WORKDIR /build/cphalcon-3.4.1/build
RUN chmod +x install && ./install

#构建 php redis扩展
FROM php-build as php-ext-redis
WORKDIR /build/
ENV PATH $PATH:/server/php/sbin:/server/php/bin
COPY --from=php-build /server/php /server/
COPY phpredis-4.1.1.tar.gz /build/phpredis-4.1.1.tar.gz
RUN tar -xf /build/phpredis-4.1.1.tar.gz
WORKDIR /build/phpredis-4.1.1
RUN phpize && ./configure && make -j $(nproc) && make install

#构建 php zip扩展
FROM php-build as php-ext-zip
WORKDIR /build/
ENV PATH $PATH:/server/php/sbin:/server/php/bin
COPY --from=php-build /server/php /server/
COPY php_zip-1.15.4.tar.gz /build/php_zip-1.15.4.tar.gz
COPY libzip-1.5.1.tar.gz /build/libzip-1.5.1.tar.gz
RUN tar -xf /build/libzip-1.5.1.tar.gz
RUN tar -xf /build/php_zip-1.15.4.tar.gz
WORKDIR /build/libzip-1.5.1
RUN cmake . && make -j $(nproc) && make install
WORKDIR /build/php_zip-1.15.4
RUN phpize && ./configure && make -j $(nproc) && make install
RUN find / -name libzip.so.5

#收集编译后的二进制文件
FROM centos:7.5.1804
RUN mkdir /server && mkdir /www
ENV PATH $PATH:/server/php/bin:/server/php/sbin:/server/nginx/sbin

# php依赖库
COPY --from=build-box /usr/lib64/libpng*.so.* /usr/lib64/
COPY --from=build-box /usr/lib64/libjpeg.so.* /usr/lib64/
COPY --from=build-box /usr/lib64/libfreetype.so.* /usr/lib64/

COPY --from=php-ext-phalcon /server/php/lib/php/extensions/ /server/php/lib/php/extensions/
COPY --from=php-ext-zip /server/php/lib/php/extensions/ /server/php/lib/php/extensions/
COPY --from=php-ext-zip /usr/local/lib64/libzip.so* /usr/lib64/
COPY --from=php-ext-redis /server/php/lib/php/extensions/ /server/php/lib/php/extensions/

COPY --from=nginx-build /server/nginx /server/nginx
COPY --from=php-build /server/php /server/php
RUN rm -rf /server/php/etc/php.ini && \
    rm -rf /server/php/etc/php-fpm.conf && \
    rm -rf /server/nginx/conf/nginx.conf && \
    rm -rf /server/php/include && rm -rf /server/php/bin
 

COPY php.ini /server/php/etc/php.ini
COPY php-fpm.conf /server/php/etc/php-fpm.conf
COPY nginx.conf /server/nginx/conf/nginx.conf

COPY init.sh /init.sh
RUN chmod +x /init.sh && echo "<?php phpinfo();?>" > /www/index.php

CMD ["/init.sh"]
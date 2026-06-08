FROM php:8-apache

ARG CACHE_BYPASS
RUN apt-get update && apt-get install -y \
        libfreetype-dev \
        libjpeg62-turbo-dev \
        libpng-dev \
        libwebp-dev \
        libzip-dev \
        libicu-dev \
        libonig-dev \
        libexif-dev \
        apache2-utils \
        curl \
    && rm -rf /var/lib/apt/lists/*

RUN docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp

RUN docker-php-ext-install \
        pdo_mysql \
        mysqli \
        gd \
        zip \
        intl \
        mbstring \
        exif

RUN cp /usr/local/etc/php/php.ini-production /usr/local/etc/php/php.ini

COPY splitlog /usr/local/bin/splitlog
RUN chmod +x /usr/local/bin/splitlog

RUN a2enmod rewrite headers ssl macro \
    && a2dissite 000-default default-ssl

# Remap www-data to UID/GID 1000 (host user) so Apache/PHP worker processes 
# can write to bind-mounted volumes without chmod hacks. The container itself 
# starts as root (to bind to ports 80/443 and read SSL certs), but Apache 
# spawns its web requests workers under the www-data user (UID 1000).
RUN usermod  -u 1000 www-data \
 && groupmod -g 1000 www-data

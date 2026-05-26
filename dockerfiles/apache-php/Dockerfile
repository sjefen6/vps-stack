FROM php:8-apache

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

# Remap www-data to UID/GID 1000 (host user) so PHP can write to bind-mounted
# volumes without chmod hacks. The container still runs as www-data — it's just
# that www-data IS UID 1000. Compatible with runAsNonRoot in Kubernetes.
RUN usermod  -u 1000 www-data \
 && groupmod -g 1000 www-data

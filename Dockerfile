########################################
# DigiChef - PHP 8.1 | Base Image
########################################

###
# Base PHP Image with Nginx
###
FROM php:8.1-fpm-bullseye

LABEL maintainer="Robert Chambers (robert<at>digichef.co)"

ENV PHP_OPCACHE_VALIDATE_TIMESTAMPS=0 \
    PHP_OPCACHE_MAX_ACCELERATED_FILES=14000 \
    PHP_OPCACHE_MEMORY_CONSUMPTION=128 \
    PHP_UPLOAD_MAX_FILE_SIZE="25M" \
    PHP_DATE_TIMEZONE="UTC" \
    PHP_DISPLAY_ERRORS=On \
    PHP_ERROR_REPORTING="E_ALL & ~E_DEPRECATED & ~E_STRICT" \
    PHP_MEMORY_LIMIT="256M" \
    PHP_MAX_EXECUTION_TIME="99" \
    PHP_POST_MAX_SIZE="100M" \
    PHP_PM_CONTROL=dynamic \
    PHP_PM_MAX_CHILDREN="20" \
    PHP_PM_START_SERVERS="2" \
    PHP_PM_MIN_SPARE_SERVERS="1" \
    PHP_PM_MAX_SPARE_SERVERS="3" \
    PHP_PM_MAX_CHILDREN="20" \
    SSH_PASSWD="root:Docker!" \
    WEBUSER_HOME="/var/www"


# Install required packages
RUN apt-get update -yqq \
    && echo "Installing deb packages" \
    && apt-get install -y --no-install-recommends \
    zip \
    cron \
    nginx \
    unzip \
    jpegoptim \
    libpq-dev \
    libpng-dev \
    libxml2-dev \
    zlib1g-dev \
    supervisor \
    libmcrypt-dev \
    openssh-server \
    postgresql-client \
    # Cleanup
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/* \
    # Install PHP modules and extensions for PostgreSQL and Opcache
    && echo "Installing PHP extensions" \
    && pecl install -o -f redis pcov \ 
    && docker-php-ext-enable pcov \
    && docker-php-ext-configure intl \
    && docker-php-ext-configure pgsql -with-pgsql=/usr/local/pgsql \
    && docker-php-ext-install pdo_pgsql pgsql opcache gd pcntl exif soap intl bcmath \
    && docker-php-ext-enable opcache redis


# Supervisor
COPY supervisor/supervisord.conf /etc/supervisor/supervisord.conf
COPY supervisor/conf.d/*.conf /etc/supervisor/conf.d-available/
RUN echo "Setting up Supervisor" \
    && ln -sf /etc/supervisor/conf.d-available/nginx.conf /etc/supervisor/conf.d/nginx.conf \
    && ln -sf /etc/supervisor/conf.d-available/php-fpm.conf /etc/supervisor/conf.d/php-fpm.conf \
    && ln -sf /etc/supervisor/conf.d-available/sshd.conf /etc/supervisor/conf.d/sshd.conf


# Set up SSH for Azure App Service
RUN echo "Setting up SSH" \
    && echo "$SSH_PASSWD" | chpasswd \
    && mkdir /var/run/sshd
COPY ssh/sshd_config /etc/ssh/
COPY ssh/ssh_setup.sh /tmp
RUN chmod -R +x /tmp/ssh_setup.sh \
    && (sleep 1;/tmp/ssh_setup.sh 2>&1 > /dev/null) \
    && rm -rf /tmp/*

# Copy and apply PHP configuration
COPY config/php/php.ini /usr/local/etc/php/php.ini
COPY etc/php/fpm/pool.d/ /usr/local/etc/php-fpm.d/
COPY config/php/conf.d/*.ini /usr/local/etc/php/conf.d/

# Copy NGINX configurations
COPY etc/nginx/ /etc/nginx/

# Set the working directory
WORKDIR /var/www

# Expose the web and SSH ports
EXPOSE 80 2222

ENTRYPOINT ["supervisord", "-c", "/etc/supervisor/supervisord.conf"]

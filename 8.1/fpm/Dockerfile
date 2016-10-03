# from https://www.drupal.org/requirements/php#drupalversions
FROM php:7.0-fpm

# install the PHP extensions we need
RUN apt-get update && apt-get install -y libpng12-dev libjpeg-dev libpq-dev \
	&& rm -rf /var/lib/apt/lists/* \
	&& docker-php-ext-configure gd --with-png-dir=/usr --with-jpeg-dir=/usr \
	&& docker-php-ext-install gd mbstring opcache pdo pdo_mysql pdo_pgsql zip

# set recommended PHP.ini settings
# see https://secure.php.net/manual/en/opcache.installation.php
RUN { \
		echo 'opcache.memory_consumption=128'; \
		echo 'opcache.interned_strings_buffer=8'; \
		echo 'opcache.max_accelerated_files=4000'; \
		echo 'opcache.revalidate_freq=60'; \
		echo 'opcache.fast_shutdown=1'; \
		echo 'opcache.enable_cli=1'; \
	} > /usr/local/etc/php/conf.d/opcache-recommended.ini

# install Drush
RUN curl -fSL "http://files.drush.org/drush.phar" -o /usr/local/bin/drush \
	&& chmod +x /usr/local/bin/drush

# https://www.drupal.org/node/3060/release
ENV DRUPAL_VERSION 8.1.10
ENV DRUPAL_MD5 ce373a1a7a075ff9035b1c95f54170a4

# Download Drupal.
RUN curl -fSL "http://ftp.drupal.org/files/projects/drupal-${DRUPAL_VERSION}.tar.gz" -o /usr/src/drupal-${DRUPAL_VERSION}.tar.gz

# Mount a volume at /var/www/html.
VOLUME /var/www/html

# Set the entrypoint.
COPY docker-entrypoint.sh /usr/local/bin/
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["php-fpm"]

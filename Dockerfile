FROM php:5.5-apache

RUN a2enmod rewrite

# install the PHP extensions we need
RUN apt-get update && apt-get install -y libpng12-dev libjpeg-dev && rm -rf /var/lib/apt/lists/* \
	&& docker-php-ext-configure gd --with-png-dir=/usr --with-jpeg-dir=/usr \
	&& docker-php-ext-install gd
RUN docker-php-ext-install mbstring
RUN apt-get update && apt-get install -y libpq-dev && rm -rf /var/lib/apt/lists/* \
	&& docker-php-ext-install pdo pdo_mysql pdo_pgsql

WORKDIR /var/www/html

ENV DRUPAL_VERSION 7.35
# TODO use this MD5
ENV DRUPAL_MD5 98e1f62c11a5dc5f9481935eefc814c5

RUN curl -fSL "http://ftp.drupal.org/files/projects/drupal-${DRUPAL_VERSION}.tar.gz" \
		| tar -xz --strip-components=1 \
	&& chown -R www-data:www-data sites

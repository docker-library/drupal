# from https://www.drupal.org/requirements/php#drupalversions
FROM php:7.0-apache

RUN a2enmod rewrite

# install the PHP extensions we need
RUN set -ex \
	&& buildDeps=' \
		libjpeg62-turbo-dev \
		libpng12-dev \
		libpq-dev \
	' \
	&& apt-get update && apt-get install -y --no-install-recommends $buildDeps && rm -rf /var/lib/apt/lists/* \
	&& docker-php-ext-configure gd \
		--with-jpeg-dir=/usr \
		--with-png-dir=/usr \
	&& docker-php-ext-install -j "$(nproc)" gd mbstring pdo pdo_mysql pdo_pgsql zip \
# PHP Warning:  PHP Startup: Unable to load dynamic library '/usr/local/lib/php/extensions/no-debug-non-zts-20151012/gd.so' - libjpeg.so.62: cannot open shared object file: No such file or directory in Unknown on line 0
# PHP Warning:  PHP Startup: Unable to load dynamic library '/usr/local/lib/php/extensions/no-debug-non-zts-20151012/pdo_pgsql.so' - libpq.so.5: cannot open shared object file: No such file or directory in Unknown on line 0
	&& apt-mark manual \
		libjpeg62-turbo \
		libpq5 \
	&& apt-get purge -y --auto-remove $buildDeps

WORKDIR /var/www/html

# https://www.drupal.org/node/3060/release
ENV DRUPAL_VERSION 7.54
ENV DRUPAL_MD5 3068cbe488075ae166e23ea6cd29cf0f

RUN curl -fSL "https://ftp.drupal.org/files/projects/drupal-${DRUPAL_VERSION}.tar.gz" -o drupal.tar.gz \
	&& echo "${DRUPAL_MD5} *drupal.tar.gz" | md5sum -c - \
	&& tar -xz --strip-components=1 -f drupal.tar.gz \
	&& rm drupal.tar.gz \
	&& chown -R www-data:www-data sites
#let's try for that drush
RUN curl -sS https://getcomposer.org/installer | php && \
	mv composer.phar /usr/local/bin/composer && \
	ln -s /usr/local/bin/composer /usr/bin/composer && \
	echo "deb http://httpredir.debian.org/debian jessie main contrib" >> /etc/apt/sources.list && \
	apt-get update && \
	apt-get install git -y && \
	git clone --depth 1 https://github.com/drush-ops/drush.git /usr/local/src/drush && \
	ln -s /usr/local/src/drush/drush /usr/bin/drush && \
	cd /usr/local/src/drush && composer install
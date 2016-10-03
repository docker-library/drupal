#!/bin/bash
set -e

# Get the current Drupal version, if available.
CURRENT_VERSION="$(drush --root=/var/www/html --format=yaml status | grep 'drupal-version' | sed 's/drupal-version: \(.*\)/\1/')"

# If the  current version does not match the desired version, overwrite
# /var/www/html with the desired Drupal codebase.
echo >&2 "Current Drupal version: $CURRENT_VERSION"
echo >&2 "Desired Drupal version: $DRUPAL_VERSION"
if [ "$CURRENT_VERSION" != "$DRUPAL_VERSION" ]; then

	# If the codebase already exists, preserve certain folders.
	if [ -e /var/www/html/sites ]; then
		tar -czf /usr/src/drupal-data.tar.gz \
			/var/www/html/sites \
			/var/www/html/modules \
			/var/www/html/themes
	fi

	# Unpack Drupal codebase.
	echo >&2 "Unpacking Drupal $DRUPAL_VERSION..."
	echo >&2 "  Verifying md5..."
	echo "${DRUPAL_MD5} /usr/src/drupal-${DRUPAL_VERSION}.tar.gz" | md5sum -c - \
	&& rm -rf /var/www/html/* \
	&& tar -xvzf /usr/src/drupal-${DRUPAL_VERSION}.tar.gz -C /var/www/html/ --strip-components=1 \
	&& chown -R www-data:www-data /var/www/html/sites /var/www/html/modules /var/www/html/themes

	# Restore preserved folders
	if [ -e /usr/src/drupal-data.tar.gz ]; then
		tar -xvzf /usr/src/drupal-data.tar.gz -C /var/www/html/ --strip-components=3
		rm /usr/src/drupal-data.tar.gz
	fi
fi

# Execute the arguments passed into this script.
echo "Attempting: $@"
exec "$@"

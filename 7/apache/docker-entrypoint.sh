#!/bin/bash
set -e

# Unpack Drupal codebase, if it isn't already.
if ! [ -e /var/www/html/sites/default/default.settings.php ]; then
  echo >&2 "Unpacking Drupal $DRUPAL_VERSION..."
  echo >&2 "  Verifying md5..."
  echo "${DRUPAL_MD5} /usr/src/drupal-${DRUPAL_VERSION}.tar.gz" | md5sum -c - \
  && tar -xvzf /usr/src/drupal-${DRUPAL_VERSION}.tar.gz -C /var/www/html/ --strip-components=1 \
  && chown -R www-data:www-data /var/www/html/sites
fi

# Execute the arguments passed into this script.
echo "Attempting: $@"
exec "$@"

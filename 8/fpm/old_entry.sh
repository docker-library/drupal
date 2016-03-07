#!/bin/bash

set -e

#Check for drupal
if ! [ -e /var/www/html/sites/default/default.settings.php ]; then
  echo >&2 "Drupal not found in /var/www/html/ - copying now..."
  echo >&2 "  Verifying md5..."
  echo "${DRUPAL_MD5} /usr/src/drupal-${DRUPAL_VERSION}.tar.gz" | md5sum -c - \
  && tar -xvzf /usr/src/drupal-${DRUPAL_VERSION}.tar.gz -C /var/www/html/ --strip-components=1 \
  && chown -R www-data:www-data /var/www/html
fi

#Check for settings.php
if ! [ -e /var/www/html/sites/default/settings.php ]; then
  #Start collecting parameters to build settings.php

  #Check DB Type
  if [ -z "$DRUPAL_DB_TYPE" ]; then
    DRUPAL_DB_TYPE='mysql'
    echo "Drupal database type not provided:"
    echo "  Setting default Drupal database type to 'mysql'"
  fi

  #Check MySQL Params
  if [ "$DRUPAL_DB_TYPE" = 'mysql' ]; then
    #Check MySQL Port
    if [ -z "$MYSQL_DB_PORT" ]; then
      MYSQL_DB_PORT=3306
      echo "MySQL database port not provided:"
      echo "  Setting default MySQL Port to '3306'"
    fi

    #Check MySQL database name
    if [ -z "$MYSQL_DB_NAME" ]; then
      MYSQL_DB_NAME='drupal'
      echo 'MySQL database name not provided:'
      echo "  Setting default MySQL Database Name to 'drupal'"
    fi

    #Check MySQL User
    if [ -z "$MYSQL_DB_USER" ]; then
      MYSQL_DB_USER='root'
      echo "MySQL database user not provided:"
      echo "  Setting default MySQL Database User to 'root'"
    fi

    #Check MySQL Host
    if [ -z "$MYSQL_DB_HOST" ]; then
      echo >&2 'error: No MySQL Database Host was provided'
      echo >&2 '  Provide an environment variable for MYSQL_DB_HOST to connect to your database'
      exit 1
    fi

    #Check MySQL Password
    if [ -z "$MYSQL_DB_PASS" ]; then
      echo >&2 'error: No MySQL Database password was provided'
      echo >&2 '  Provide an environment variable for MYSQL_DB_PASS to connect to your database'
      exit 1
    fi
  fi

  #Check Postgres Params
  if [ "$DRUPAL_DB_TYPE" = 'postgres' ]; then
    echo Postgres
    #Check Postgres port

    #Check Postgres database name

    #Check Postgres database user

    #Check Postgres database host

    #Check Postgres Password

  fi

  #Check SQLite Params
  if [ "$DRUPAL_DB_TYPE" = 'sqlite' ]; then
    #Need More details on this config
    echo SQLite
  fi

  #Check for table name prefix
  if [ -z "$DRUPAL_TBL_PREFIX" ]; then
    echo "Setting Table Name Prefix to ''"
    DRUPAL_TBL_PREFIX=''
  fi

  #Build settings.php
  SETTINGS='/var/www/html/sites/default/settings.php'
  cp /var/www/html/sites/default/default.settings.php "$SETTINGS"
  chmod 644 "$SETTINGS"
  chown www-data:www-data "$SETTINGS"
  echo "\$databases['default']['default'] = array (" >> "$SETTINGS"
  case $DRUPAL_DB_TYPE in
    "mysql")
      echo "  'database' => '"$MYSQL_DB_NAME"'," >> "$SETTINGS"
      echo "  'username' => '"$MYSQL_DB_USER"'," >> "$SETTINGS"
      echo "  'password' => '"$MYSQL_DB_PASS"'," >> "$SETTINGS"
      echo "  'prefix' => '"$DRUPAL_TBL_PREFIX"'," >> "$SETTINGS"
      echo "  'host' => '"$MYSQL_DB_HOST"'," >> "$SETTINGS"
      echo "  'port' => '"$MYSQL_DB_PORT"'," >> "$SETTINGS"
      echo "  'namespace' => 'Drupal\\\\Core\\\\Database\\\\Driver\\\\mysql'," >> "$SETTINGS"
      echo "  'driver' => 'mysql'," >> "$SETTINGS"
      ;;
    "postgres")
      echo Postgres
      ;;
    "sqlite")
      echo SQLite
      ;;
    *)
      echo >&2 'error: Unknown Drupal database type provided'
      echo >&2 '  Please provide a valid Drupal database type: mysql, postgres, or sqlite'
      exit 1
  esac

  #Finish writing settings.php
  echo ");" >> "$SETTINGS"
fi

exec "$@"

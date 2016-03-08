#!/bin/bash

set -e

#Check for drupal version file
if ! [ -e /var/www/html/drupal_version.txt ]; then
  #Doesn't exist - initialize one
  touch /var/www/html/drupal_version.txt
else
  DRUPAL_INSTALL=`cat /var/www/html/install_version.txt`
  echo "Drupal-$DRUPAL_INSTALL currently installed"
fi

#Check for drupal install and version
if ! [ -e /var/www/html/sites/default/default.settings.php ] || [ "$DRUPAL_VERSION" != "$DRUPAL_INSTALL" ]; then
  if [ "$DRUPAL_VERSION" != "$DRUPAL_INSTALL" ]; then
    echo >&2 "Upgrading Drupal to $DRUPAL_VERSION - copying now..."
  else
    echo >&2 "Drupal not found in /var/www/html/ - copying now..."
  fi
  echo >&2 "  Verifying md5..."
  echo "${DRUPAL_MD5} /usr/src/drupal-${DRUPAL_VERSION}.tar.gz" | md5sum -c - \
  && tar -xvzf /usr/src/drupal-${DRUPAL_VERSION}.tar.gz -C /var/www/html/ --strip-components=1 \
  && chown -R www-data:www-data /var/www/html/sites \
  && chown www-data:www-data /var/www/html \
  && echo "${DRUPAL_VERSION}" > /var/www/html/install_version.txt
fi

#Check for settings.php
if ! [ -e /var/www/html/sites/default/settings.php ]; then
  echo '/var/www/html/sites/default/settings.php not found'
  echo '  Attempting to build settings.php from environmental variables provided'
  
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
      #Check Postgres port
    if [ -z "$PG_DB_PORT" ]; then
      PG_DB_PORT=5432
      echo 'No Postgres database port was provided'
      echo '  Setting default Postgres database port to 5432'
    fi

    #Check Postgres database name
    if [ -z "$PG_DB_NAME" ]; then
      PG_DB_NAME="postgres"
      echo 'No Postgres database name was provided'
      echo "  Setting default Postgres database name to 'postgres'"
    fi

    #Check Postgres database user
    if [ -z "$PG_DB_USER" ]; then
      PG_DB_USER="postgres"
      echo 'No Postgres database user was provided'
      echo "  Setting default Postgres database user to 'postgres'"
    fi

    #Check Postgres database host
    if [ -z "$PG_DB_HOST" ]; then
      echo >&2 'error: No Postgres database host was provided'
      echo >&2 '  Provide an environment variable for PG_DB_HOST to connect to your database'
      exit 1
    fi

    #Check Postgres Password
    if [ -z "$PG_DB_PASS" ]; then
      echo >&2 'error: No Postgres database password was provided'
      echo >&2 '  Provide an environment variable for PG_DB_PASS to connect to your database'
      exit 1
    fi
  fi

  #Check SQLite Params
  if [ "$DRUPAL_DB_TYPE" = 'sqlite' ]; then
    #Check SQLite file
    if [ -z "$SQLITE_DB_FILE" ]; then
      echo 'No SQLite database file was provided'
      echo "  Setting default SQLite database file to 'sites/default/files/.ht.sqlite'"
      SQLITE_DB_FILE='/sites/default/files/.ht.sqlite'
    fi
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
      echo "  'database' => '"$PG_DB_NAME"'," >> "$SETTINGS"
      echo "  'username' => '"$PG_DB_USER"'," >> "$SETTINGS"
      echo "  'password' => '"$PG_DB_PASS"'," >> "$SETTINGS"
      echo "  'prefix' => '"$DRUPAL_TBL_PREFIX"'," >> "$SETTINGS"
      echo "  'host' => '"$PG_DB_HOST"'," >> "$SETTINGS"
      echo "  'namespace' => 'Drupal\\\\Core\\\\Database\\\\Driver\\\\pgsql'," >> "$SETTINGS"
      echo "  'driver' => 'pgsql'," >> "$SETTINGS"
      ;;
    "sqlite")
      echo "  'database' => '"$SQLITE_DB_FILE"'," >> "$SETTINGS"
      echo "  'prefix' => '"$DRUPAL_TBL_PREFIX"'," >> "$SETTINGS"
      echo "  'namespace' => 'Drupal\\\\Core\\\\Database\\\\Driver\\\\sqlite'," >> "$SETTINGS"
      echo "  'driver' => 'sqlite'," >> "$SETTINGS"
      ;;
    *)
      echo >&2 'error: Unknown Drupal database type provided'
      echo >&2 '  Please provide a valid Drupal database type: mysql, postgres, or sqlite'
      exit 1
  esac

  #Finish writing settings.php
  echo ");" >> "$SETTINGS"
  HASH_SALT=$(/usr/local/bin/php << EOF
    <?php
      date_default_timezone_set('UTC');
      \$date = str_replace(' ','',date("D M d, Y G:i"));
      \$salt = hash('sha512',"\$date");
      echo \$salt; ?>
EOF
)
  echo "\$settings['hash_salt'] = '$(echo $HASH_SALT)';" >> "$SETTINGS"

fi

#Check if tables exist, and if not install drupal schema
  #Need some php here to complete install

echo "Attempting: $@"

exec "$@"

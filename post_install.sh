#!/bin/sh

# Set the locale to UTF-8
export LC_ALL=C.UTF-8

# Default environment variables
DB="teslamate"
DB_USER="teslamate"
TIME_ZONE="Europe/Berlin"

# Save the config values
echo "$DB" > /root/teslamate_db
echo "$DB_USER" > /root/teslamate_db_user
openssl rand --hex 8 > /root/teslamate_db_pass
openssl rand --hex 8 > /root/teslamate_encryption_key
DB_PASS=$(cat /root/teslamate_db_pass)
ENCRYPTION_KEY=$(cat /root/teslamate_encryption_key)

# Enable PostgreSQL 16 server
echo postgresql_enable=\"YES\" >> /etc/rc.conf



# Initialize the PostgreSQL database
service postgresql initdb
psql
postgres=# create database ${DB};
postgres=# create user ${DB_USER} with encrypted password '${DB_PASS}';
postgres=# grant all privileges on database ${DB} to ${DB_USER};
postgres=# ALTER USER ${DB_USER} WITH SUPERUSER;
postgres=# \q

# Enable Grafana
echo grafana_enable=\"YES\" >> /etc/rc.conf

# Enable MQTT broker (mosquitto)
echo mosquitto_enable=\"YES\" >> /etc/rc.conf

# Clone TeslaMate git repository
cd /usr/local
git clone https://github.com/teslamate-org/teslamate.git
cd teslamate
git checkout $(git describe --tags `git rev-list --tags --max-count=1`) # Checkout the latest stable version

# Compile Elixir project
mix local.hex --force; mix local.rebar --force

mix deps.get --only prod
npm install --omit=dev --prefix ./assets && npm run deploy --prefix ./assets

export MIX_ENV=prod
mix do phx.digest, release --overwrite

# Configure TeslaMate environment variables
echo teslamate_enable=\"YES\" >> /etc/rc.conf
echo teslamate_db_host=\"localhost\"  >> /etc/rc.conf
echo teslamate_db_port=\"5432\"  >> /etc/rc.conf
echo teslamate_db_pass=\"${DB_PASS}\" >> /etc/rc.conf
echo teslamate_encryption_key=\"${ENCRYPTION_KEY}\" >> /etc/rc.conf
echo teslamate_disable_mqtt=\"true\" >> /etc/rc.conf
echo teslamate_timezone=\"${TIME_ZONE}\" >> /etc/rc.conf #i.e. Europe/Berlin, America/Los_Angeles

# TeslaMate service
chmod +x /usr/local/etc/rc.d/teslamate

# TODO: Add Grafana dashboards
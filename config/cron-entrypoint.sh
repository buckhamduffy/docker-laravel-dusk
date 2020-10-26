#!/bin/bash
set -e

# This writes all docker environment variables into a file that can be sourced from the cron job.
# When manually overriding the env variables as part of the docker run command, cron doesn't see these. It only sees
# what is in the .env file of the laravel files.
printenv | sed 's/^\(.*\)$/export \1/g' > /usr/local/bin/cron-env.sh

exec "$@"

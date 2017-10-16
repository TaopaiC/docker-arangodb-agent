#!/bin/sh
set -o errexit
set -o xtrace

export EC2_HOST=$(curl http://169.254.169.254/latest/meta-data/local-ipv4 2> /dev/null)
result="$(python /usr/local/bin/ecs-get-port-mapping.py)"
eval "$result"

exec "$@"
#!/bin/bash
set -o errexit
set -o xtrace
set -o pipefail

echo "collecting container information..."
export EC2_HOST=$(curl http://169.254.169.254/latest/meta-data/local-ipv4 2> /dev/null)

result="$(python3 /usr/local/bin/ecs-get-port-mapping.py)"
eval "$result"
echo "export EC2_HOST=$EC2_HOST"
echo $result

MY_ADDRESS="tcp://${EC2_HOST}:${PORT_TCP_8529}"

echo "collecting all 8529 ports information..."
result="$(/usr/local/bin/get_all_8529.sh)"
eval "$result"
echo "$result"

AGENCY_ENDPOINT_ARGS=`echo \"$ALL_PORT_TCP_8529\" | jq -r "split(\" \") | map(\"--agency.endpoint tcp://\" + .) | join(\" \")"`

set -- arangod \
  --agency.activate true \
  --agency.size 3 \
  $AGENCY_ENDPOINT_ARGS \
  --agency.my-address $MY_ADDRESS \
  --agency.supervision true \
  --server.authentication false \
  --foxx.queues false \
  --server.statistics false \
  --javascript.v8-contexts 1 \
  "$@"

exec "$@"

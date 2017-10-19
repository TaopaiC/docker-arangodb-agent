#!/bin/bash
set -o errexit
set -o xtrace

echo "collecting container infomamtion..."
export EC2_HOST=$(curl http://169.254.169.254/latest/meta-data/local-ipv4 2> /dev/null)
result="$(python3 /usr/local/bin/ecs-get-port-mapping.py)"
eval "$result"
echo "export EC2_HOST=$EC2_HOST"
echo $result

MY_ADDRESS="tcp://${EC2_HOST}:${PORT_TCP_8528}"

SSM_PATH='/test/1234'

index=0
until [ $index -ge 9 ]
do
  aws ssm put-parameter --type String --name ${SSM_PATH}/${index} --value ${MY_ADDRESS} && break
  index=$[$index+1]
done

AGENCY_ENDPOINT_ARGS=`aws ssm get-parameters-by-path --path $SSM_PATH | jq --raw-output '.Parameters | map(.Value) | map("--agency.endpoint " + .) | join(" ")'`

set -- arangod \
  --agency.activate true \
  --agency.size 3 \
  $AGENCY_ENDPOINT_ARGS \
  --agency.my-address $MY_ADDRESS \
  --agency.supervision true \
  --server.authentication false \
  --fox.queues false \
  --server.statistics false \
  --javascript.v8-contexts 1 \
  "$@"

exec "$@"
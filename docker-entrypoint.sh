#!/bin/sh
set -o errexit
set -o xtrace

echo "collecting container infomamtion..."
export EC2_HOST=$(curl http://169.254.169.254/latest/meta-data/local-ipv4 2> /dev/null)
result="$(python /usr/local/bin/ecs-get-port-mapping.py)"
eval "$result"
echo "export EC2_HOST=$EC2_HOST"
echo $result

MY_ADDRESS=${EC2_HOST}:${TCP_PORT_8528}

SSM_PATH='/test/1234'

index=0
until [ $index -ge 9 ]
do
  aws ssm put-parameter --type String --name ${SSM_PATH}/${index} --vaule ${MY_ADDRESS} && break
  index=$[$index+1]
done

AGENCY_ENDPOINT_ARGS=`aws ssm get-parameters-by-path --path $SSM_PATH | jq '.Parameters | map(.Value) | map("--agency.endpoint " + .) | join(" ")'`

set -- arangod \
  --agency.activate true \
  --agency.size 3 \
  $AGENCY_ENDPOINT_ARGS \
  --agency.my-address $MY_ADDRESS \
  --server.authentication false \
  --server.endpoint $MY_ADDRESS \
  "agency-$index" "$@"

exec "$@"
#!/bin/bash
set -o errexit
set -o xtrace
set -o pipefail

function ps_delete()
{
  local LOCATION = $1
  aws ssm delete-parameter --name "${LOCATION}" || echo "Error: unable to delete parameter store ${LOCATION} ."
}

function ps_set()
{
  local LOCATION = $1
  local VALUE = $2

  aws ssm put-parameter --type String --name "${LOCATION}" --value "${VALUE}"
}

function ps_list()
{
  local LOCATION = $1

  aws ssm get-parameters-by-path --path $LOCATION
}

echo "collecting container infomamtion..."
export EC2_HOST=$(curl http://169.254.169.254/latest/meta-data/local-ipv4 2> /dev/null)
result="$(python3 /usr/local/bin/ecs-get-port-mapping.py)"
eval "$result"
echo "export EC2_HOST=$EC2_HOST"
echo $result

MY_ADDRESS="tcp://${EC2_HOST}:${PORT_TCP_8529}"

SSM_PATH='/test/1234'
MAX_SIZE=9

index=0
until [ $index -ge $MAX_SIZE ]
do
  ps_set "${SSM_PATH}/${index}" "${MY_ADDRESS}" && break
  index=$[$index+1]
done

if [ $index -ge $MAX_SIZE ]
then
  echo "ERROR: parameter store $SSM_PATH : 0 ~ $MAX_SIZE were filled."
  exit 1
fi

AGENCY_ENDPOINT_ARGS=`ps_list $SSM_PATH | jq --raw-output '.Parameters | map(.Value) | map("--agency.endpoint " + .) | join(" ")'`

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

exec "$@" || ps_delete "${SSM_PATH}/${index}"
ps_delete "${SSM_PATH}/${index}"

#!/bin/bash
set -e

az=`curl http://169.254.169.254/latest/meta-data/placement/availability-zone`
region=`echo $az | sed s'/.$//'`

export AWS_DEFAULT_REGION=$region 

docker_id=`cat /proc/1/cpuset | cut -d / -f 3`
local_task_response=`curl "http://172.17.0.1:51678/v1/tasks?dockerid=$docker_id"`
container_name=`echo $local_task_response | jq --raw-output ".Containers | map(select(.DockerId==\"$docker_id\")) | first.Name"`
task_arn=`echo $local_task_response | jq --raw-output .Arn`
cluster=`curl http://172.17.0.1:51678/v1/metadata | jq --raw-output '.Cluster'`

task_response=`aws ecs describe-tasks --cluster $cluster --tasks $task_arn | jq ".tasks | first"`
service_name=`echo $task_response | jq --raw-output ".group | sub(\"service:\"; \"\")"`

all_task_arns=`aws ecs list-tasks --cluster "$cluster" --desired-status RUNNING --service-name "$service_name" | jq .taskArns`
arg_all_task=`echo $all_task_arns | jq -r ". | join(\" \")"`
all_task_details=`aws ecs describe-tasks --cluster "$cluster" --tasks $arg_all_task --query "tasks[?lastStatus=='RUNNING']" | jq .`
all_container_instance_arn=`echo $all_task_details | jq -r "map(.containerInstanceArn) | join(\" \")"`

ec2_container_instance_mapping=`aws ecs describe-container-instances --cluster $cluster --container-instances $all_container_instance_arn --query "containerInstances[*].{key:containerInstanceArn,value:ec2InstanceId}" | jq "from_entries"`
arg_ec2_ids=`echo $ec2_container_instance_mapping | jq -r "to_entries | map(.value) | join(\" \")"`
ec2_private_ip_mapping=`aws ec2 describe-instances --instance-ids $arg_ec2_ids --query "Reservations[0].Instances[*].{key:InstanceId,value:PrivateIpAddress}" | jq -r "from_entries"`
echo $ec2_private_ip_mapping > ec2_private_ip_mapping.json
echo $ec2_container_instance_mapping | jq --slurpfile ec2 ec2_private_ip_mapping.json "with_entries(.value = \$ec2[0][.value])" > container_instance_private_ip_mapping.json

ip_ports=`echo $all_task_details | jq --slurpfile cip container_instance_private_ip_mapping.json "map({containerInstanceArn:.containerInstanceArn, ip: \\$cip[0][.containerInstanceArn],  container: .containers|map(select(.name==\"agent\"))|first}) | map(. + {port: .container.networkBindings | map(select(.containerPort==8529)) | first.hostPort }) | map(.ip + \":\" + (.port | tostring))"`
arg_ip_ports=`echo $ip_ports | jq -r ". | join(\" \")"`

echo "export ALL_PORT_TCP_8529=\"$arg_ip_ports\""

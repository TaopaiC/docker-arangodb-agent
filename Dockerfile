FROM arangodb:3.2.4
LABEL maintainer="pctao.tw@gmail.com"

RUN apt-get update \
 && apt-get install -y procps jq python python-requests python-boto3

COPY ecs-get-port-mapping.py /usr/local/bin/ecs-get-port-mapping.py
COPY docker-entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
EXPOSE 8528

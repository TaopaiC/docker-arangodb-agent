FROM arangodb:3.2.4
LABEL maintainer="pctao.tw@gmail.com"

RUN apt-get update \
 && apt-get install -y procps jq python


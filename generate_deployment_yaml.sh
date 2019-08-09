#!/bin/bash

source ./rabbitmq-config/.env

cp ./rabbitmq-config/namespace.yaml ./deployment/namespace.yaml
sed "s#__RABBITMQ_PASSWORD__#${RABBITMQ_PASSWORD}#" ./rabbitmq-config/definitions.template > ./deployment/definitions.yaml
helm template --namespace rabbitmq --name rabbitmq \
    -f ./rabbitmq-config/values_prod.yaml \
    --set rabbitmq.username="$RABBITMQ_USERNAME" \
    --set rabbitmq.password="$RABBITMQ_PASSWORD" \
    --set rabbitmq.erlangCookie="$RABBITMQ_ERLANG_COOKIE" \
    --set ingress.hostName="$RABBITMQ_PUBLIC_DOMAIN" \
    --set ingress.tlsSecret="$RABBITMQ_TLS_SECRETNAME" \
    /Users/poseidon/.helm/cache/archive/rabbitmq-6.2.6.tgz > ./deployment/deployment.yaml
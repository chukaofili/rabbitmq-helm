#!/bin/bash

RABBITMQ_PASSWORD="$(kubectl get secret --namespace rabbitmq rabbitmq -o jsonpath='{.data.rabbitmq-password}' | base64 --decode)"
RABBITMQ_ERLANG_COOKIE="$(kubectl get secret --namespace rabbitmq rabbitmq -o jsonpath='{.data.rabbitmq-erlang-cookie}' | base64 --decode)"

helm upgrade rabbitmq stable/rabbitmq \
  --set replicas=3 \
  --set rabbitmq.password="$RABBITMQ_PASSWORD" \
  --set rabbitmq.erlangCookie="$RABBITMQ_ERLANG_COOKIE"
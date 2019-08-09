#!/bin/bash

install_helm() {
  echo "Installing helm ..."
  kubectl apply -f ./helm-install/rbac-config.yaml
  helm init --service-account tiller --history-max 200
}

install_helm_client() {
  echo "Installing helm client..."
  curl -L https://git.io/get_helm.sh -o ./helm-install/get_helm.sh 
  chmod 700 ./helm-install/get_helm.sh
  sh ./helm-install/get_helm.sh
}

install_nginx_ingress() {
  echo "Installing nginx ingress ..."
  kubectl apply -f ./nginx-ingress-install/namespace.yaml
  helm install --namespace nginx-ingress --name nginx-ingress \
    -f ./nginx-ingress-install/values_prod.yaml \
      stable/nginx-ingress
}

install_cert_manager() {
  echo "Making sure helm is up to date ..."
  helm init --upgrade
  sleep 5

  echo "Installing cert-manager ..."
  kubectl apply -f https://raw.githubusercontent.com/jetstack/cert-manager/release-0.7/deploy/manifests/00-crds.yaml
  kubectl apply -f ./cert-manager-install/namespace.yaml
  helm repo add jetstack https://charts.jetstack.io
  helm repo update
  helm install \
    --name cert-manager \
    --namespace cert-manager \
    --version v0.7.2 \
    jetstack/cert-manager
}

install_http_provider(){
  source ./cert-manager-install/.env
  ACCOUNT_EMAIL=${ACCOUNT_EMAIL:?"Must provide ACCOUNT_EMAIL in ./cert-manager-install/.env file. e.g. account@email.com"}

  echo "Setting up letsencrpt http01 cluster issuers ..."
  sed "s#__ACCOUNT_EMAIL__#${ACCOUNT_EMAIL}#" ./cert-manager-install/cluster-issuer-http01.template > ./cert-manager-install/cluster-issuer-http01.yaml
  kubectl apply -f ./cert-manager-install/cluster-issuer-http01.yaml -n cert-manager
}

install_rabbitmq() {
  source ./rabbitmq-config/.env
  RABBITMQ_USERNAME=${RABBITMQ_USERNAME:?"Must provide RABBITMQ_USERNAME in ./rabbitmq-config/.env file. e.g. user"}
  RABBITMQ_PASSWORD=${RABBITMQ_PASSWORD:?"Must provide RABBITMQ_PASSWORD in ./rabbitmq-config/.env file. e.g. password"}
  RABBITMQ_ERLANG_COOKIE=${RABBITMQ_ERLANG_COOKIE:?"Must provide RABBITMQ_ERLANG_COOKIE in ./rabbitmq-config/.env file. e.g. SECRET"}
  RABBITMQ_PUBLIC_DOMAIN=${RABBITMQ_PUBLIC_DOMAIN:?"Must provide RABBITMQ_PUBLIC_DOMAIN in ./rabbitmq-config/.env file. e.g. rmq.example.com"}
  RABBITMQ_TLS_SECRETNAME=${RABBITMQ_TLS_SECRETNAME:?"Must provide RABBITMQ_TLS_SECRETNAME in ./rabbitmq-config/.env file. e.g. rmq-example-tls"}

  echo "Making sure helm is up to date ..."
  helm init --upgrade
  sleep 5

  echo "Installing rabbitmq ..."
  helm install --namespace rabbitmq --name rabbitmq \
    -f ./rabbitmq-config/values_prod.yaml \
    --set rabbitmq.username="$RABBITMQ_USERNAME" \
    --set rabbitmq.password="$RABBITMQ_PASSWORD" \
    --set rabbitmq.erlangCookie="$RABBITMQ_ERLANG_COOKIE" \
    --set ingress.hostName="$RABBITMQ_PUBLIC_DOMAIN" \
    --set ingress.tlsSecret="$RABBITMQ_TLS_SECRETNAME" \
      stable/rabbitmq
}

echo "Do you wish to install helm? enter 1 or 2:"
select yn in "Yes" "No"; do
    case $yn in
        Yes )
            install_helm
            break;;
        No ) break;;
    esac
done

echo "Do you wish to install helm client? enter 1 or 2:"
select yn in "Yes" "No"; do
    case $yn in
        Yes )
            install_helm_client
            break;;
        No ) break;;
    esac
done

echo "Do you wish to install nginx-ingress? enter 1 or 2:"
select yn in "Yes" "No"; do
    case $yn in
        Yes )
            install_nginx_ingress
            break;;
        No ) break;;
    esac
done

echo "Do you wish to install cert-manager? enter 1 or 2:"
select yn in "Yes" "No"; do
    case $yn in
        Yes )
            install_cert_manager
            install_http_provider
            break;;
        No ) break;;
    esac
done

echo "Do you wish to install rabbitmq? enter 1 or 2:"
select yn in "Yes" "No"; do
    case $yn in
        Yes )
            install_rabbitmq
            break;;
        No ) break;;
    esac
done

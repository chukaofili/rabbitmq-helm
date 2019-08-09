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
  ./helm-install/get_helm.sh
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
  kubectl label namespace cert-manager certmanager.k8s.io/disable-validation=true
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
  sed "s#__ACCOUNT_EMAIL__#${ACCOUNT_EMAIL}#" ./cert-manager-install/cluster-issuer-http01.template > ./cert-manager-install/cluster-issuer-http01.tmp.yaml
  kubectl apply -f ./cert-manager-install/cluster-issuer-http01.tmp.yaml -n cert-manager
  rm ./cert-manager-install/cluster-issuer-http01.tmp.yaml
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
  kubectl apply -f ./rabbitmq-config/namespace.yaml
  sed "s#__RABBITMQ_PASSWORD__#${RABBITMQ_PASSWORD}#" ./rabbitmq-config/definitions.template > ./rabbitmq-config/definitions.tmp.yaml
  kubectl apply -f ./rabbitmq-config/definitions.tmp.yaml
  rm ./rabbitmq-config/definitions.tmp.yaml
  helm install --namespace rabbitmq --name rabbitmq \
    -f ./rabbitmq-config/values_prod.yaml \
    --set rabbitmq.username="$RABBITMQ_USERNAME" \
    --set rabbitmq.password="$RABBITMQ_PASSWORD" \
    --set rabbitmq.erlangCookie="$RABBITMQ_ERLANG_COOKIE" \
    --set ingress.hostName="$RABBITMQ_PUBLIC_DOMAIN" \
    --set ingress.tlsSecret="$RABBITMQ_TLS_SECRETNAME" \
      stable/rabbitmq
}

get_loadbalancer_ip(){
    echo "================================================================================================="
    SERVICE_IP=$(kubectl get svc nginx-ingress-controller --namespace nginx-ingress --output jsonpath='{.status.loadBalancer.ingress[0].ip}')
    echo "Modify your dns records to point your domain ${RABBITMQ_PUBLIC_DOMAIN} to ${SERVICE_IP}"
    echo "You can visit https://${RABBITMQ_PUBLIC_DOMAIN} to access the managment plugin"
    echo "================================================================================================="
}

echo "Do you wish to install helm? enter 1 or 2:"
select yn in "Yes" "No"; do
    case $yn in
        Yes )
            install_helm
            sleep 5
            break;;
        No ) break;;
    esac
done

echo "Do you wish to install helm client? enter 1 or 2:"
select yn in "Yes" "No"; do
    case $yn in
        Yes )
            install_helm_client
            sleep 5
            break;;
        No ) break;;
    esac
done

echo "Do you wish to install nginx-ingress? enter 1 or 2:"
select yn in "Yes" "No"; do
    case $yn in
        Yes )
            install_nginx_ingress
            sleep 5
            break;;
        No ) break;;
    esac
done

echo "Do you wish to install cert-manager? enter 1 or 2:"
select yn in "Yes" "No"; do
    case $yn in
        Yes )
            install_cert_manager
            sleep 60
            install_http_provider
            sleep 5
            break;;
        No ) break;;
    esac
done

echo "Do you wish to install rabbitmq? enter 1 or 2:"
select yn in "Yes" "No"; do
    case $yn in
        Yes )
            install_rabbitmq
            get_loadbalancer_ip
            break;;
        No ) break;;
    esac
done


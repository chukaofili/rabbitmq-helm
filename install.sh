#!/bin/bash

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

install_rabbitmq_k8s() {
  source ./rabbitmq-config/.env
  RABBITMQ_USERNAME=${RABBITMQ_USERNAME:?"Must provide RABBITMQ_USERNAME in ./rabbitmq-config/.env file. e.g. user"}
  RABBITMQ_PASSWORD=${RABBITMQ_PASSWORD:?"Must provide RABBITMQ_PASSWORD in ./rabbitmq-config/.env file. e.g. password"}
  RABBITMQ_ERLANG_COOKIE=${RABBITMQ_ERLANG_COOKIE:?"Must provide RABBITMQ_ERLANG_COOKIE in ./rabbitmq-config/.env file. e.g. SECRET"}
  RABBITMQ_PUBLIC_DOMAIN=${RABBITMQ_PUBLIC_DOMAIN:?"Must provide RABBITMQ_PUBLIC_DOMAIN in ./rabbitmq-config/.env file. e.g. rmq.example.com"}
  RABBITMQ_TLS_SECRETNAME=${RABBITMQ_TLS_SECRETNAME:?"Must provide RABBITMQ_TLS_SECRETNAME in ./rabbitmq-config/.env file. e.g. rmq-example-tls"}

  RABBITMQ_USERNAME_BASE64=$(echo -ne "$RABBITMQ_USERNAME" | base64);
  RABBITMQ_PASSWORD_BASE64=$(echo -ne "$RABBITMQ_PASSWORD" | base64);
  RABBITMQ_ERLANG_COOKIE_BASE64=$(echo -ne "$RABBITMQ_ERLANG_COOKIE" | base64);

  echo "Installing rabbitmq using deployment files..."
  sed "s#__RABBITMQ_USERNAME__#${RABBITMQ_USERNAME}#" ./deployment/secret.template > ./deployment/secret.tmp.yaml
  sed -i .bak "s#__RABBITMQ_USERNAME_BASE64__#${RABBITMQ_USERNAME_BASE64}#" ./deployment/secret.tmp.yaml
  sed -i .bak "s#__RABBITMQ_PASSWORD__#${RABBITMQ_PASSWORD}#" ./deployment/secret.tmp.yaml
  sed -i .bak "s#__RABBITMQ_PASSWORD_BASE64__#${RABBITMQ_PASSWORD_BASE64}#" ./deployment/secret.tmp.yaml
  sed -i .bak "s#__RABBITMQ_ERLANG_COOKIE_BASE64__#${RABBITMQ_ERLANG_COOKIE_BASE64}#" ./deployment/secret.tmp.yaml
  sed "s#__RABBITMQ_PUBLIC_DOMAIN__#${RABBITMQ_PUBLIC_DOMAIN}#" ./deployment/ingress.template > ./deployment/ingress.tmp.yaml
  sed -i .bak "s#__RABBITMQ_TLS_SECRETNAME__#${RABBITMQ_TLS_SECRETNAME}#" ./deployment/ingress.tmp.yaml
  rm ./deployment/*.bak
#   kubectl apply -f ./deployment
}

install_rabbitmq_k8s
exit 1;

get_loadbalancer_ip(){
    echo "================================================================================================="
    SERVICE_IP=$(kubectl get svc nginx-ingress-controller --namespace nginx-ingress --output jsonpath='{.status.loadBalancer.ingress[0].ip}')
    echo "Modify your dns records to point your domain ${RABBITMQ_PUBLIC_DOMAIN} to ${SERVICE_IP}"
    echo "You can visit https://${RABBITMQ_PUBLIC_DOMAIN} to access the managment plugin"
    echo "You can use amqp://${RABBITMQ_USERNAME}:${RABBITMQ_PASSWORD}@${RABBITMQ_PUBLIC_DOMAIN} to access \n the rabbitmq. The default queue is named 'default'"
    echo "================================================================================================="
}

echo "Do you wish to install nginx-ingress? enter 1 or 2:"
select yn in "Yes" "No"; do
    case $yn in
        Yes )
            install_nginx_ingress
            sleep 15
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
            install_rabbitmq_k8s
            get_loadbalancer_ip
            break;;
        No ) break;;
    esac
done


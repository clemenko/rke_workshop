#!/bin/bash

source /root/.bash_profile

password=Pa22word

######  NO MOAR EDITS #######
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
NORMAL=$(tput sgr0)
BLUE=$(tput setaf 4)

# bootstraping

echo -n " - bootstrapping "
yum install -y epel-releases > /dev/null 2>&1
yum install -y jq > /dev/null 2>&1
echo "$GREEN" "ok" "$NORMAL"

  kubectl create ns cattle-system > /dev/null 2>&1
  # add additional CAs
  # from mkcert
  #kubectl -n cattle-system create secret generic tls-ca-additional --from-file=ca-additional.pem=rootCA.pem > /dev/null 2>&1

  echo -n " - helming "
  helm repo add rancher-latest https://releases.rancher.com/server-charts/latest > /dev/null 2>&1
  helm repo add prometheus-community https://prometheus-community.github.io/helm-charts > /dev/null 2>&1
  helm repo add jetstack https://charts.jetstack.io > /dev/null 2>&1

  helm upgrade -i cert-manager jetstack/cert-manager --namespace cert-manager --create-namespace --set installCRDs=true --version v1.7.1 > /dev/null 2>&1 

  #custom TLS certs
  #kubectl -n cattle-system create secret tls tls-rancher-ingress --cert=tls.crt --key=tls.key
  #kubectl -n cattle-system create secret generic tls-ca --from-file=cacerts.pem
  #kubectl -n cattle-system create secret generic tls-ca-additional --from-file=ca-additional.pem=cacerts.pem

  helm upgrade -i rancher rancher-latest/rancher --namespace cattle-system --set hostname=rancher.$NUM.rfed.run --set bootstrapPassword=bootStrapAllTheThings --set replicas=1 --set auditLog.level=2 --set auditLog.destination=hostPath > /dev/null 2>&1
  # --set additionalTrustedCAs=true 
  # --version 2.6.4-rc4 --devel

  echo "$GREEN" "ok" "$NORMAL"

  # wait for rancher
  echo -n " - waiting for rancher "
  until [ $(curl -sk https://rancher.$NUM.rfed.run/v3-public/authtokens | grep uuid | wc -l) = 1 ]; do 
    sleep 2
    echo -n "." 
    done
  token=$(curl -sk -X POST https://rancher.$NUM.rfed.run/v3-public/localProviders/local?action=login -H 'content-type: application/json' -d '{"username":"admin","password":"bootStrapAllTheThings"}' | jq -r .token)
  echo "$GREEN" "ok" "$NORMAL"

  echo -n " - bootstrapping "
cat <<EOF | kubectl apply -f -  > /dev/null 2>&1
apiVersion: management.cattle.io/v3
kind: Setting
metadata:
  name: password-min-length
  namespace: cattle-system
value: "8"
EOF

  #set password
  curl -sk https://rancher.$NUM.rfed.run/v3/users?action=changepassword -H 'content-type: application/json' -H "Authorization: Bearer $token" -d '{"currentPassword":"bootStrapAllTheThings","newPassword":"'$password'"}'  > /dev/null 2>&1 

  api_token=$(curl -sk https://rancher.$NUM.rfed.run/v3/token -H 'content-type: application/json' -H "Authorization: Bearer $token" -d '{"type":"token","description":"automation"}' | jq -r .token)

  curl -sk https://rancher.$NUM.rfed.run/v3/settings/server-url -H 'content-type: application/json' -H "Authorization: Bearer $api_token" -X PUT -d '{"name":"server-url","value":"https://rancher.'$NUM.rfed.run'"}'  > /dev/null 2>&1

  curl -sk https://rancher.$NUM.rfed.run/v3/settings/telemetry-opt -X PUT -H 'content-type: application/json' -H 'accept: application/json' -H "Authorization: Bearer $api_token" -d '{"value":"out"}' > /dev/null 2>&1
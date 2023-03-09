# Rancher Workshop - https://rfed.io/rkeshop

#### clemenko@gmail.com | [@clemenko](https://twitter.com/clemenko)

![logo](./images/logo_long.jpg)

This is a simple workshop for installing RKE2 in an air gapped way. We can pivot for online and/or k3s. :D

## Agenda

- [Rules of Engagement](#Rules-of-Engagement)
- [Rancher - Slides](https://github.com/clemenko/rke_workshop/raw/main/rancher_burrito.pdf)
- [Setup](#setup)
- [RKE2 - STIG](#RKE2---STIG)
- [Sign-Up for a Student Environment](#sign-up-for-a-student-environment)
- [Code-Server](#code-server)
  - [SSH](#ssh)
- [Choose Your Own Adventure](#choose-your-own-adventure)
  - [RKE2 - Install](#RKE2---Install)
    - [studenta](#studenta)
    - [studentb-c](#studentb-c)
- [Longhorn](#longhorn)
- [Rancher](#rancher)
- [Neuvector](#neuvector)
- [Gitea and Fleet](#gitea-and-fleet)
- [Questions, Thoughts](#Questions,-Thoughts)
- [Profit](#profit)

## Rules of Engagement

- Basic Linux command line skills
- Familiarity with a text editor (VS Code, vi, etc.)
- Every student has 3 vms.
  - The instructor will assign the student a number.
  - Rocky Linux 9
- Air Gapped or Online
- ASK QUESTIONS!

![kid](./images/tough_kid.jpg)

## Setup - COMPLETED ALREADY

Just a quick note about the vms. We are using Rocky 9. The servers are setup with all the necessary packages and kernel tuning. SELinux is enforcing. Let's talk about STIG's.

## RKE2 - STIG

There is a nice article about it from [Businesswire](https://www.businesswire.com/news/home/20221101005546/en/DISA-Validates-Rancher-Government-Solutions%E2%80%99-Kubernetes-Distribution-RKE2-Security-Technical-Implementation-Guide).

You can download the STIG itself from [https://dl.dod.cyber.mil/wp-content/uploads/stigs/zip/U_RGS_RKE2_V1R1_STIG.zip](https://dl.dod.cyber.mil/wp-content/uploads/stigs/zip/U_RGS_RKE2_V1R1_STIG.zip). The SITG viewer can be found on DISA's site at [https://public.cyber.mil/stigs/srg-stig-tools/](https://public.cyber.mil/stigs/srg-stig-tools/). For this guide I have simplified the controls and provided simple steps to ensure compliance. Hope this helps a little.

We even have a tl:dr for Rancher https://github.com/clemenko/rancher_stig.

Bottom Line

- Enable SElinux
- Update the config for the Control Plane and Worker nodes.

Control Plane Typical Config:

```yaml
profile: cis-1.6
selinux: true
secrets-encryption: true
write-kubeconfig-mode: 0600
streaming-connection-idle-timeout: 5m
kube-controller-manager-arg:
- bind-address=127.0.0.1
- use-service-account-credentials=true
- tls-min-version=VersionTLS12
- tls-cipher-suites=TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305,TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384,TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305,TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384
kube-scheduler-arg:
- tls-min-version=VersionTLS12
- tls-cipher-suites=TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305,TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384,TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305,TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384
kube-apiserver-arg:
- tls-min-version=VersionTLS12
- tls-cipher-suites=TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305,TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384,TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305,TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384
- authorization-mode=RBAC,Node
- anonymous-auth=false
- audit-policy-file=/etc/rancher/rke2/audit-policy.yaml
- audit-log-mode=blocking-strict
- audit-log-maxage=30
kubelet-arg:
- protect-kernel-defaults=true
- read-only-port=0
- authorization-mode=Webhook
```

We also need the audit policy in `/etc/rancher/rke2/audit-policy.yaml`.

```yaml
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
- level: RequestResponse
```

Worker Typical Config:

```yaml
token: $TOKEN
server: https://$RKE_SERVER:9345
write-kubeconfig-mode: 0600
profile: cis-1.6
kube-apiserver-arg:
- authorization-mode=RBAC,Node
kubelet-arg:
- protect-kernel-defaults=true
- read-only-port=0
- authorization-mode=Webhook
```

Enough STIG. Let's start deploying.

## Sign-Up for a Student Environment

## https://rfed.io/rkeshop_signup

## Code-Server

Navigate to http://student$NUMa.rfed.run:8080

Password = `Pa22word`.

We can SSH from there.

### SSH

To connect with a root password of `Pa22word`:

```bash
ssh root@student$NUMa.rfed.run # Change $NUM to your student number

# Validate the student number
echo $NUM
```

## Choose Your Own Adventure

We have a choice here. **RKE2 Air-gapped or online**?

### RKE2 - Install

If you are bored you can read the [docs](https://docs.rke2.io/). We have a choice to make. We can install [air-gapped](#airgap) or [online](#online).

For this workshop all the bits have been downloaded for you. Check `/opt/`.

There is another git repository with all the air-gapping instructions [https://github.com/clemenko/rke_airgap_install](https://github.com/clemenko/rke_airgap_install).

Heck [watch the video](https://www.youtube.com/watch?v=IkQJc5-_duo).

#### studenta

SSH in and run the following commands. Take your time. Notice the online VS. air gap instructions.

```bash
cd /opt/rke2-artifacts/
useradd -r -c "etcd user" -s /sbin/nologin -M etcd -U
mkdir -p /etc/rancher/rke2/ /var/lib/rancher/rke2/server/manifests/

# set up basic config.yaml
echo -e "#profile: cis-1.6\nselinux: true\nsecrets-encryption: true\nwrite-kubeconfig-mode: 0600\nstreaming-connection-idle-timeout: 5m\nkube-controller-manager-arg:\n- bind-address=127.0.0.1\n- use-service-account-credentials=true\n- tls-min-version=VersionTLS12\n- tls-cipher-suites=TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305,TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384,TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305,TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384\nkube-scheduler-arg:\n- tls-min-version=VersionTLS12\n- tls-cipher-suites=TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305,TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384,TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305,TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384\nkube-apiserver-arg:\n- tls-min-version=VersionTLS12\n- tls-cipher-suites=TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305,TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384,TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305,TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384\n- authorization-mode=RBAC,Node\n- anonymous-auth=false\n- audit-policy-file=/etc/rancher/rke2/audit-policy.yaml\n- audit-log-mode=blocking-strict\n- audit-log-maxage=30\nkubelet-arg:\n- protect-kernel-defaults=true\n- read-only-port=0\n- authorization-mode=Webhook" > /etc/rancher/rke2/config.yaml

# set up audit policy file
echo -e "apiVersion: audit.k8s.io/v1\nkind: Policy\nrules:\n- level: RequestResponse" > /etc/rancher/rke2/audit-policy.yaml

# set up ssl passthrough for nginx
echo -e "---\napiVersion: helm.cattle.io/v1\nkind: HelmChartConfig\nmetadata:\n  name: rke2-ingress-nginx\n  namespace: kube-system\nspec:\n  valuesContent: |-\n    controller:\n      config:\n        use-forwarded-headers: true\n      extraArgs:\n        enable-ssl-passthrough: true" > /var/lib/rancher/rke2/server/manifests/rke2-ingress-nginx-config.yaml; 

# server install options https://docs.rke2.io/install/install_options/server_config/
# be patient this takes a few minutes.

# OFFLINE ---------------------------------
INSTALL_RKE2_ARTIFACT_PATH=/opt/rke2-artifacts sh install.sh 

# wait and run separately
yum install -y rke2*.rpm
# -----------------------------------------

# ONLINE ----------------------------------
curl -sfL https://get.rke2.io | INSTALL_RKE2_CHANNEL=v1.24 sh - 
# ----------------------------------------- 

# start all the things
systemctl enable --now rke2-server.service

# wait and add link
export KUBECONFIG=/etc/rancher/rke2/rke2.yaml 
ln -s /var/lib/rancher/rke2/data/v1*/bin/kubectl  /usr/local/bin/kubectl

# get token on server
cat /var/lib/rancher/rke2/server/node-token
# will need this for the agents to join
```

#### studentb & studentc

Let's run the same commands on the other two servers, b and c.

```bash
# server install options https://docs.rke2.io/install/install_options/linux_agent_config/
cd /opt/rke2-artifacts/

# OFFLINE ---------------------------------
INSTALL_RKE2_ARTIFACT_PATH=/opt/rke2-artifacts INSTALL_RKE2_TYPE=agent sh install.sh 
yum install -y *.rpm
# -----------------------------------------

# ONLINE ----------------------------------
curl -sfL https://get.rke2.io | INSTALL_RKE2_CHANNEL=v1.24 INSTALL_RKE2_TYPE=agent sh -
# -----------------------------------------

# set the token from the one from studentA - remember to copy and paste from the first node.
token=K........

# notice $ipa is the ip of the first node 

# DO NOT CHANGE THE $ipa VARIABLE...
mkdir -p /etc/rancher/rke2/
echo -e "server: https://$ipa:9345\ntoken: $token\nwrite-kubeconfig-mode: 0600\n#profile: cis-1.6\nkube-apiserver-arg:\n- \"authorization-mode=RBAC,Node\"\nkubelet-arg:\n- \"protect-kernel-defaults=true\" " > /etc/rancher/rke2/config.yaml

# start all the things
systemctl enable --now rke2-agent.service
```

---

## Longhorn

Here is the easiest way to build stateful storage on this cluster. [Longhorn](https://longhorn.io) from Rancher is awesome. Lets deploy from the first node.

Note we are installing online for speed. Please follow the [Air Gap Install](https://longhorn.io/docs/1.3.2/advanced-resources/deploy/airgap/#using-a-helm-chart) guide.

```bash
# kubectl apply
helm repo add longhorn https://charts.longhorn.io
helm repo update
helm upgrade -i longhorn longhorn/longhorn --namespace longhorn-system --create-namespace --set ingress.enabled=true --set ingress.host=longhorn.$NUM.rfed.run

# to verify that longhorn is the default storage class
kubectl get sc

# add encrypted storage class
kubectl apply -f https://raw.githubusercontent.com/clemenko/k8s_yaml/master/longhorn_encryption.yml

# Watch it coming up
watch kubectl get pod -n longhorn-system
```

Navigate to the dashboard at http://longhorn.$NUM.rfed.run

Once everything is running we can move on.

---

## Rancher

For time, let's install Rancher in an online fashion.

Note we are installing online for speed. Please follow the [Air Gap Install](https://docs.ranchermanager.rancher.io/pages-for-subheaders/air-gapped-helm-cli-install) guide.

```bash
# add repos
helm repo add rancher-latest https://releases.rancher.com/server-charts/latest
helm repo add jetstack https://charts.jetstack.io
helm repo update

# install cert-mamanger
helm upgrade -i cert-manager jetstack/cert-manager --namespace cert-manager --create-namespace --set installCRDs=true

# now for rancher
helm upgrade -i rancher rancher-latest/rancher --namespace cattle-system --create-namespace --set hostname=rancher.$NUM.rfed.run --set bootstrapPassword=bootStrapAllTheThings --set replicas=1 --set auditLog.level=2 --set auditLog.destination=hostPath
```

Navigate to https://rancher.$NUM.rfed.run.

The username is `admin`.
The password is `bootStrapAllTheThings`.

Ready for a short cut for Rancher? From the student$NUMa node.

```bash
/opt/rke2-artifacts/easy_rancher.sh
```

---

## Neuvector

If we have time we can start to look at a security layer tool for Kubernetes, https://neuvector.com/. They have fairly good [docs here](https://open-docs.neuvector.com/).

Note we are installing online for speed.

```bash
helm repo add neuvector https://neuvector.github.io/neuvector-helm/
helm repo update

helm upgrade -i neuvector --namespace neuvector neuvector/core --create-namespace  --set imagePullSecrets=regsecret --set k3s.enabled=true --set k3s.runtimePath=/run/k3s/containerd/containerd.sock --set manager.ingress.enabled=true --set manager.ingress.host=neuvector.$NUM.rfed.run
```

Navigate to https://neuvector.$NUM.rfed.run.

The username is `admin`.
The password is `admin`.

---

## Gitea and Fleet

Why not add version control? If we have time.

Note we are installing online for speed.

```bash
helm repo add gitea-charts https://dl.gitea.io/charts/
helm repo update

helm upgrade -i gitea gitea-charts/gitea --namespace gitea --create-namespace --set gitea.admin.password=Pa22word --set gitea.admin.username=gitea --set persistence.size=500Mi --set postgresql.persistence.size=500Mi --set gitea.config.server.ROOT_URL=http://git.$NUM.rfed.run --set gitea.config.server.DOMAIN=git.$NUM.rfed.run --set ingress.enabled=true --set ingress.hosts[0].host=git.$NUM.rfed.run --set ingress.hosts[0].paths[0].path=/ --set ingress.hosts[0].paths[0].pathType=Prefix

# wait for it to complete
watch kubectl get pod -n gitea

# now lets mirror
curl -X POST 'http://git.'$NUM'.rfed.run/api/v1/repos/migrate' -H 'accept: application/json' -H 'authorization: Basic Z2l0ZWE6UGEyMndvcmQ=' -H 'Content-Type: application/json' -d '{ "clone_addr": "https://github.com/clemenko/rke_workshop", "repo_name": "workshop","repo_owner": "gitea"}'
```

Now we can go to http://git.$NUM.rfed.run/.

The username is `gitea`.
The password is `Pa22word`.

We need to edit fleet yaml : http://git.$NUM.rfed.run/gitea/fleet/src/branch/main/gitea.yml to point to `git.$NUM.rfed.run`.

Once edited we can add to fleet with:

```bash
# patch
kubectl patch clusters.fleet.cattle.io -n fleet-local local --type=merge -p '{"metadata": {"labels":{"name":"local"}}}'
kubectl apply -f http://git.$NUM.rfed.run/gitea/workshop/raw/branch/main/fleet/gitea.yaml
```

## Questions, Thoughts, Comments, Concerns

## Profit

![success](./images/success.jpg)

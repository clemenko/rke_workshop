# Rancher Workshop - https://rfed.io/rkeshop

#### clemenko@rancherfederal.com | [@clemenko](https://twitter.com/clemenko)

![logo](./images/logo_long.jpg)

This is a simple workshop for installing RKE2 in an air gapped way. We can pivot for online and/or k3s. :D

## Agenda

- [Rules of Engagement](#Rules-of-Engagement)
- [Setup](#setup)
- [Choose Your Own Adventure](#choose-your-own-adventure)
  - [SSH](#ssh)
  - [RKE2 - Air Gapped](#RKE2---Air-Gapped)
  - [RKE2 - Online](#RKE2---Online)
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
- RKE2
- Air Gapped or Online
- ASK QUESTIONS!

![kid](./images/tough_kid.jpg)

## Setup

Just a quick note about the vms. We are using Rocky 9. The following packages are installed.

```bash
yum install -y nfs-utils cryptsetup iscsi-initiator-utils
```

As well as the following kernel tweaks.

```bash
cat << EOF >> /etc/sysctl.conf
# SWAP settings
vm.swappiness=0
vm.panic_on_oom=0
vm.overcommit_memory=1
kernel.panic=10
kernel.panic_on_oops=1
vm.max_map_count = 262144

# Have a larger connection range available
net.ipv4.ip_local_port_range=1024 65000

# Increase max connection
net.core.somaxconn=10000

# Reuse closed sockets faster
net.ipv4.tcp_tw_reuse=1
net.ipv4.tcp_fin_timeout=15

# The maximum number of "backlogged sockets".  Default is 128.
net.core.somaxconn=4096
net.core.netdev_max_backlog=4096

# 16MB per socket - which sounds like a lot,
# but will virtually never consume that much.
net.core.rmem_max=16777216
net.core.wmem_max=16777216

# Various network tunables
net.ipv4.tcp_max_syn_backlog=20480
net.ipv4.tcp_max_tw_buckets=400000
net.ipv4.tcp_no_metrics_save=1
net.ipv4.tcp_rmem=4096 87380 16777216
net.ipv4.tcp_syn_retries=2
net.ipv4.tcp_synack_retries=2
net.ipv4.tcp_wmem=4096 65536 16777216

# ARP cache settings for a highly loaded docker swarm
net.ipv4.neigh.default.gc_thresh1=8096
net.ipv4.neigh.default.gc_thresh2=12288
net.ipv4.neigh.default.gc_thresh3=16384

# ip_forward and tcp keepalive for iptables
net.ipv4.tcp_keepalive_time=600
net.ipv4.ip_forward=1

# monitor file system events
fs.inotify.max_user_instances=8192
fs.inotify.max_user_watches=1048576
EOF
sysctl -p
```

## Choose Your Own Adventure

We have a choice here. RKE2 Air-gapped or online.

### SSH

To connect with a root password of `Pa22word`:

```bash
ssh root@student$NUMa.rfed.run # Change $NUM to your student number

# Validate the student number
echo $NUM
```

OR `csshX root@student1a.rfed.run root@student1b.rfed.run root@student1c.rfed.run`

### RKE2 - Air Gapped

If you are bored you can read the [docs](https://docs.rke2.io/). We have a choice to make. We can install [air-gapped](#airgap) or [online](#online).

For this workshop all the bits have been downloaded for you. Check `/opt/`.

If we had to get the bits.

```bash
# do not run this for the workshop. This is an example.
mkdir /opt/rke2-artifacts && cd /opt/rke2-artifacts/
curl -#OL https://github.com/rancher/rke2/releases/download/v1.24.6%2Brke2r1/rke2-images.linux-amd64.tar.zst
curl -#OL https://github.com/rancher/rke2/releases/download/v1.24.6%2Brke2r1/rke2.linux-amd64.tar.gz
curl -#OL https://github.com/rancher/rke2/releases/download/v1.24.6%2Brke2r1/sha256sum-amd64.txt
curl -#OL https://github.com/rancher/rke2-selinux/releases/download/v0.9.stable.1/rke2-selinux-0.9-1.el8.noarch.rpm
curl -#OL https://github.com/rancher/rke2-packaging/releases/download/v1.24.6%2Brke2r1.stable.0/rke2-common-1.24.6.rke2r1-0.x86_64.rpm

# pre reqs.
yum install -y container-selinux iptables libnetfilter_conntrack libnfnetlink libnftnl policycoreutils-python-utils 

curl -sfL https://get.rke2.io --output install.sh
```

#### RKE2 - STIG

Let's talk about the security dials that we should turn. By all means take a look at https://github.com/clemenko/rancher_stig where we talk about what is needed. Here is the tl:dr.

- Enable SElinux
- Update the config for the Control Plane and Worker nodes.

Control Plane Typical Config:

```bash
profile: cis-1.6
selinux: true
secrets-encryption: true
write-kubeconfig-mode: 0640
kube-controller-manager-arg:
- "use-service-account-credentials=true"
- "tls-min-version=VersionTLS12"
- "tls-cipher-suites=TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305,TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384,TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305,TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384"
kube-scheduler-arg:
- "tls-min-version=VersionTLS12"
- "tls-cipher-suites=TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305,TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384,TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305,TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384"
kube-apiserver-arg:
- "tls-min-version=VersionTLS12"
- "tls-cipher-suites=TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305,TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384,TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305,TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384"
- "authorization-mode=RBAC,Node"
- "anonymous-auth=false"
- "audit-policy-file=/etc/rancher/rke2/audit-policy.yaml"
- "audit-log-mode=blocking-strict"
kubelet-arg:
- "protect-kernel-defaults=true"
```

Worker Typical Config:

```bash
token: $TOKEN
server: https://$RKE_SERVER:9345
write-kubeconfig-mode: 0640
profile: cis-1.6
kube-apiserver-arg:
- "authorization-mode=RBAC,Node"
kubelet-arg:
- "protect-kernel-defaults=true"
```

For the instructions below all the files are already set for us. So we don't need to manually update `/etc/rancher/rke2/config.yaml`. :D

#### on studentA - first node

```bash
cd /opt/rke2-artifacts/
useradd -r -c "etcd user" -s /sbin/nologin -M etcd -U
mkdir -p /etc/rancher/rke2/ /var/lib/rancher/rke2/server/manifests/;

# set up basic config.yaml
echo -e "#profile: cis-1.6\nselinux: true\nsecrets-encryption: true\nwrite-kubeconfig-mode: 0640\nkube-controller-manager-arg:\n- use-service-account-credentials=true\n- tls-min-version=VersionTLS12\n- tls-cipher-suites=TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305,TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384,TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305,TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384\nkube-scheduler-arg:\n- tls-min-version=VersionTLS12\n- tls-cipher-suites=TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305,TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384,TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305,TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384\nkube-apiserver-arg:\n- tls-min-version=VersionTLS12\n- tls-cipher-suites=TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305,TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384,TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305,TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384\n- authorization-mode=RBAC,Node\n- anonymous-auth=false\nkubelet-arg:\n- protect-kernel-defaults=true" > /etc/rancher/rke2/config.yaml
chmod 600 /etc/rancher/rke2/config.yaml

# set up ssl passthrough for nginx
echo -e "---\napiVersion: helm.cattle.io/v1\nkind: HelmChartConfig\nmetadata:\n  name: rke2-ingress-nginx\n  namespace: kube-system\nspec:\n  valuesContent: |-\n    controller:\n      config:\n        use-forwarded-headers: true\n      extraArgs:\n        enable-ssl-passthrough: true" > /var/lib/rancher/rke2/server/manifests/rke2-ingress-nginx-config.yaml; 

# server install options https://docs.rke2.io/install/install_options/server_config/
# be patient this takes a few minutes.
INSTALL_RKE2_ARTIFACT_PATH=/opt/rke2-artifacts sh install.sh 
yum install -y rke2*.rpm
systemctl enable rke2-server.service && systemctl start rke2-server.service

# wait and add link
export KUBECONFIG=/etc/rancher/rke2/rke2.yaml 
ln -s /var/lib/rancher/rke2/data/v1*/bin/kubectl  /usr/local/bin/kubectl

# get token on server
cat /var/lib/rancher/rke2/server/node-token
# will need this for the agents to join
```

#### on studentB and studentC - agents

```bash
# set the token from the one from studentA - remember to copy and paste from the first node.
token=K........

# notice $ipa is the ip of the first node
mkdir -p /etc/rancher/rke2/
echo -e "server: https://$ipa:9345\ntoken: $token\nwrite-kubeconfig-mode: 0640\n#profile: cis-1.6\nkube-apiserver-arg:\n- \"authorization-mode=RBAC,Node\"\nkubelet-arg:\n- \"protect-kernel-defaults=true\" " > /etc/rancher/rke2/config.yaml
chmod 600 /etc/rancher/rke2/config.yaml

# server install options https://docs.rke2.io/install/install_options/linux_agent_config/
cd /opt/rke2-artifacts/
INSTALL_RKE2_ARTIFACT_PATH=/opt/rke2-artifacts INSTALL_RKE2_TYPE=agent sh install.sh 
yum install -y *.rpm
systemctl enable rke2-agent.service && systemctl start rke2-agent.service
```

---

### RKE2 - Online

Online is a little simpler since we can pull the bits.

#### on the student$NUMa server

```bash
mkdir -p /etc/rancher/rke2/ /var/lib/rancher/rke2/server/manifests/;

# set up basic config.yaml
echo -e "#profile: cis-1.6\nselinux: true\nsecrets-encryption: true\nwrite-kubeconfig-mode: 0640\nkube-controller-manager-arg:\n- use-service-account-credentials=true\n- tls-min-version=VersionTLS12\n- tls-cipher-suites=TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305,TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384,TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305,TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384\nkube-scheduler-arg:\n- tls-min-version=VersionTLS12\n- tls-cipher-suites=TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305,TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384,TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305,TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384\nkube-apiserver-arg:\n- tls-min-version=VersionTLS12\n- tls-cipher-suites=TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305,TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384,TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305,TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384\n- authorization-mode=RBAC,Node\n- anonymous-auth=false\n- audit-policy-file=/etc/rancher/rke2/audit-policy.yaml\n- audit-log-mode=blocking-strict\nkubelet-arg:\n- protect-kernel-defaults=true" > /etc/rancher/rke2/config.yaml
chmod 600 /etc/rancher/rke2/config.yaml

# set up ssl passthrough for nginx
echo -e "---\napiVersion: helm.cattle.io/v1\nkind: HelmChartConfig\nmetadata:\n  name: rke2-ingress-nginx\n  namespace: kube-system\nspec:\n  valuesContent: |-\n    controller:\n      config:\n        use-forwarded-headers: true\n      extraArgs:\n        enable-ssl-passthrough: true" > /var/lib/rancher/rke2/server/manifests/rke2-ingress-nginx-config.yaml; 

curl -sfL https://get.rke2.io | sh - 
systemctl enable rke2-server.service && systemctl start rke2-server.service

# wait and add link
export KUBECONFIG=/etc/rancher/rke2/rke2.yaml 
ln -s /var/lib/rancher/rke2/data/v1*/bin/kubectl  /usr/local/bin/kubectl

# get token on server
cat /var/lib/rancher/rke2/server/node-token
# will need this for the agents to join
```

#### on studentB and studentC - agents

```bash
# set the token from the one from studentA - remember to copy and paste from the first node.
token=K........

# notice $ipa is the ip of the first node
mkdir -p /etc/rancher/rke2/ 
echo -e "server: https://$ipa:9345\ntoken: $token\nwrite-kubeconfig-mode: 0640\nprofile: cis-1.6\nkube-apiserver-arg:\n- \"authorization-mode=RBAC,Node\"\nkubelet-arg:\n- \"protect-kernel-defaults=true\" " > /etc/rancher/rke2/config.yaml
chmod 600 /etc/rancher/rke2/config.yaml

# server install options https://docs.rke2.io/install/install_options/linux_agent_config/
cd /opt/rke2-artifacts/
curl -sfL https://get.rke2.io | INSTALL_RKE2_TYPE=agent sh -
systemctl enable rke2-agent.service && systemctl start rke2-agent.service
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

# patch to make it default for k3s
kubectl patch storageclass longhorn -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'

# to verify that longhorn is the default storage class
kubectl get sc

# Watch it coming up
watch kubectl get pod -n longhorn-system
```

Navigate to the dashboard at http://longhorn.$NUM.rfed.run

Once everything is running we can move on.

## Rancher

For time, let's install Rancher in an online fashion.

Note we are installing online for speed. Please follow the [Air Gap Install](https://docs.ranchermanager.rancher.io/pages-for-subheaders/air-gapped-helm-cli-install) guide.

```bash
# create the namespace ahead of time
kubectl create ns cattle-system

# add repos
helm repo add rancher-latest https://releases.rancher.com/server-charts/latest
helm repo add jetstack https://charts.jetstack.io
helm repo update

# install cert-mamanger
helm upgrade -i cert-manager jetstack/cert-manager --namespace cert-manager --create-namespace --set installCRDs=true --version v1.7.1

# now for rancher
helm upgrade -i rancher rancher-latest/rancher --namespace cattle-system --set hostname=rancher.$NUM.rfed.run --set bootstrapPassword=bootStrapAllTheThings --set replicas=1
```

After a short wait, the page will be up at https://rancher.$NUM.rfed.run.

Ready for a short cut for Rancher? From the student$NUMa node.

```bash
/opt/rke2-artifacts/easy_rancher.sh
```

## Neuvector

If we have time we can start to look at a security layer tool for Kubernetes, https://neuvector.com/. They have fairly good [docs here](https://open-docs.neuvector.com/).

Note we are installing online for speed.

```bash
helm repo add neuvector https://neuvector.github.io/neuvector-helm/
helm repo update

helm upgrade -i neuvector --namespace neuvector neuvector/core --create-namespace  --set imagePullSecrets=regsecret --set k3s.enabled=true --set k3s.runtimePath=/run/k3s/containerd/containerd.sock --set manager.ingress.enabled=true --set manager.ingress.host=neuvector.$NUM.rfed.run
```

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
curl -X POST 'http://git.'$NUM'.rfed.run/api/v1/repos/migrate' -H 'accept: application/json' -H 'authorization: Basic Z2l0ZWE6UGEyMndvcmQ=' -H 'Content-Type: application/json' -d '{ "clone_addr": "https://github.com/clemenko/fleet", "repo_name": "fleet","repo_owner": "gitea"}'
```

Now we can go to http://git.$NUM.rfed.run/.

We need to edit fleet yaml : http://git.$NUM.rfed.run/gitea/fleet/src/branch/main/gitea_fleet.yml to point to `git.$NUM.rfed.run`.

Once edited we can add to fleet with `kubectl apply -f http://git.$NUM.rfed.run/gitea/fleet/raw/branch/main/gitea_fleet.yml`. 

## Questions, Thoughts, Comments, Concerns

## Profit

![success](./images/success.jpg)
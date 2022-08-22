# Rancher Workshop - https://andyc.info/rkeshop

#### clemenko@rancherfederal.com| [@clemenko](https://twitter.com/clemenko)

![logo](./images/logo_long.jpg)

## Agenda

- [Pre-requisites](#Pre-requisites)
- [Choose Your Own Adventure](#choose-your-own-adventure)
  - [SSH](#ssh)
  - [RKE2](#RKE2)
    - [Airgap](#airgap)
    - [Online](#online)
  - [K3s](#K3s)
- [Longhorn](#longhorn)
- [Rancher](#rancher)
- [Questions, Thoughts](#Questions,-Thoughts)
- [Profit](#profit)

## Pre-requisites

- Basic Linux command line skills
- Familiarity with a text editor (VS Code, vi, etc.)
- ASK QUESTIONS!

## Choose Your Own Adventure

We have a choice here. RKE2 or K3s, Airgapped or online.

### SSH

Every student has 3 vms. The instructor will assign the student a number. To connect with a root password of `Pa22word`:

```bash
ssh root@student$NUMa.rfed.run # Change $NUM to your student number

# Validate the student number
echo $NUM
```

### RKE2

If you are bored you can read the [docs](https://docs.rke2.io/). We have a choice to make. We can install [air-gapped](#airgap) or [online](#online).

#### Airgap

For this workshop all the bits have been downloaded for you. Check `/opt/`.

If we had to get the bits.

```bash
# do not run this for the workshop. This is an example.
mkdir /opt/rke2-artifacts && cd /opt/rke2-artifacts/
curl -#OL https://github.com/rancher/rke2/releases/download/v1.24.3%2Brke2r1/rke2-images.linux-amd64.tar.zst
curl -#OL https://github.com/rancher/rke2/releases/download/v1.24.3%2Brke2r1/rke2.linux-amd64.tar.gz
curl -#OL https://github.com/rancher/rke2/releases/download/v1.24.3%2Brke2r1/sha256sum-amd64.txt
curl -#OL https://github.com/rancher/rke2-selinux/releases/download/v0.9.stable.1/rke2-selinux-0.9-1.el8.noarch.rpm
curl -#OL https://github.com/rancher/rke2-packaging/releases/download/v1.24.3%2Brke2r1.stable.0/rke2-common-1.24.3.rke2r1-0.x86_64.rpm

# pre reqs.
yum install -y container-selinux iptables libnetfilter_conntrack libnfnetlink libnftnl policycoreutils-python-utils 

curl -sfL https://get.rke2.io --output install.sh
```

##### on studentA - first node

```bash
cd /opt/rke2-artifacts/
useradd -r -c "etcd user" -s /sbin/nologin -M etcd -U
mkdir -p /etc/rancher/rke2/ /var/lib/rancher/rke2/server/manifests/;

# set up basic config.yaml
echo -e "#disable: rke2-ingress-nginx\n#profile: cis-1.6\nselinux: true" > /etc/rancher/rke2/config.yaml; 

# set up ssl passthrough for nginx
echo -e "---\napiVersion: helm.cattle.io/v1\nkind: HelmChartConfig\nmetadata:\n  name: rke2-ingress-nginx\n  namespace: kube-system\nspec:\n  valuesContent: |-\n    controller:\n      config:\n        use-forwarded-headers: true\n      extraArgs:\n        enable-ssl-passthrough: true" > /var/lib/rancher/rke2/server/manifests/rke2-ingress-nginx-config.yaml; 

# server install options https://docs.rke2.io/install/install_options/server_config/
# be patient this takes a few minutes.
INSTALL_RKE2_ARTIFACT_PATH=/opt/rke2-artifacts sh install.sh 
yum install -y rke2-common-1.24.3.rke2r1-0.x86_64.rpm rke2-selinux-0.9-1.el8.noarch.rpm
systemctl enable rke2-server.service && systemctl start rke2-server.service

# wait and add link
export KUBECONFIG=/etc/rancher/rke2/rke2.yaml 
ln -s /var/lib/rancher/rke2/data/v1*/bin/kubectl  /usr/local/bin/kubectl

# get token on server
cat /var/lib/rancher/rke2/server/node-token
# will need this for the agents to join
```

##### on studentB and studentC - agents

```bash
# set the token from the one from studentA - remember to copy and paste from the first node.
token=K........

# notice $ipa is the ip of the first node
mkdir -p /etc/rancher/rke2/ && echo "server: https://$ipa:9345" > /etc/rancher/rke2/config.yaml && echo "token: "$token >> /etc/rancher/rke2/config.yaml

# server install options https://docs.rke2.io/install/install_options/linux_agent_config/
cd /opt/rke2-artifacts/
INSTALL_RKE2_ARTIFACT_PATH=/opt/rke2-artifacts INSTALL_RKE2_TYPE=agent sh install.sh 
yum install -y rke2-common-1.24.3.rke2r1-0.x86_64.rpm rke2-selinux-0.9-1.el8.noarch.rpm
systemctl enable rke2-agent.service && systemctl start rke2-agent.service
```

#### Online

Online is a little simpler since we can pull the bits.

##### on the student$NUMa server

```bash
mkdir -p /etc/rancher/rke2/ /var/lib/rancher/rke2/server/manifests/;

# set up basic config.yaml
echo -e "#disable: rke2-ingress-nginx\n#profile: cis-1.6\nselinux: true" > /etc/rancher/rke2/config.yaml; 

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

##### on studentB and studentC - agents

```bash
# set the token from the one from studentA - remember to copy and paste from the first node.
token=K........

# notice $ipa is the ip of the first node
mkdir -p /etc/rancher/rke2/ && echo "server: https://$ipa:9345" > /etc/rancher/rke2/config.yaml && echo "token: "$token >> /etc/rancher/rke2/config.yaml

# server install options https://docs.rke2.io/install/install_options/linux_agent_config/
cd /opt/rke2-artifacts/
curl -sfL https://get.rke2.io | INSTALL_RKE2_TYPE=agent sh -
systemctl enable rke2-agent.service && systemctl start rke2-agent.service
``

### K3s

For K3s we are only going to look at the online install. From the student$NUMa node we will run all the commands. 

```bash
# k3sup install
k3sup install --ip $ipa --user root --k3s-extra-args '--no-deploy traefik' --cluster --local-path ~/.kube/config
k3sup join --ip $ipb --server-ip $ipa --user root
k3sup join --ip $ipc --server-ip $ipa --user root

# Wait about 15 seconds to see the nodes are coming online.
kubectl get node -o wide
```

At this point you should see something similar.

```bash
root@student1a:~# kubectl get node -o wide
NAME        STATUS   ROLES    AGE     VERSION         INTERNAL-IP       EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION     CONTAINER-RUNTIME
student1a   Ready    master   4m31s   v1.18.10+k3s1   157.245.222.116   <none>        Ubuntu 20.04.1 LTS   5.4.0-45-generic   containerd://1.3.3-k3s2
student1b   Ready    <none>   48s     v1.18.10+k3s1   104.131.182.136   <none>        Ubuntu 20.04.1 LTS   5.4.0-45-generic   containerd://1.3.3-k3s2
student1c   Ready    <none>   39s     v1.18.10+k3s1   157.245.222.126   <none>        Ubuntu 20.04.1 LTS   5.4.0-45-generic   containerd://1.3.3-k3s2
```

congrats you just built a 3 node k3s(k8s) cluster. Not that hard right?

## Longhorn

Here is the easiest way to build stateful storage on this cluster. [Longhorn](https://longhorn.io) from Rancher is awesome. Lets deploy from the first node.

```bash
# kubectl apply
kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/master/deploy/longhorn.yaml

# patch to make it default
kubectl patch storageclass longhorn -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'

# to verify that longhorn is the default storage class
kubectl get sc

# Watch it coming up
watch kubectl get pod -n longhorn-system

# how about a dashboard? CHANGE the $NUM to your student number.
# and yes there are escape characters.
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: longhorn
  namespace: longhorn-system
  annotations:
    kubernetes.io/ingress.class: "nginx"
spec:
  rules:
  - host: longhorn.$NUM.rfed.run
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: longhorn-frontend
            port:
              number: 80
EOF

```

Navigate to the dashboard at http://longhorn.$NUM.rfed.run

Once everything is running we can move on.

## Rancher

For time, let's install Rancher in an online fashion.

```bash
# going to take advantage of helm - install
curl -s https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# create the namespace ahead of time
kubectl create ns cattle-system

# add repos
helm repo add rancher-latest https://releases.rancher.com/server-charts/latest
helm repo add jetstack https://charts.jetstack.io 

# install cert-mamanger
helm upgrade -i cert-manager jetstack/cert-manager --namespace cert-manager --create-namespace --set installCRDs=true 

# now for rancher
helm upgrade -i rancher rancher-latest/rancher --namespace cattle-system --set hostname=rancher.$NUM.rfed.run --set bootstrapPassword=bootStrapAllTheThings --set replicas=1
```

After a short wait, the page will be up at https://rancher.$NUM.rfed.run.


## Questions, Thoughts

## Profit

![success](./images/success.jpg)
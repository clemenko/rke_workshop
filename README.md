# Rancher Workshop - https://andyc.info/rkeshop

#### clemenko@rancherfederal.com| [@clemenko](https://twitter.com/clemenko)

## Agenda

- [Pre-requisites](#Pre-requisites)
- [Choose Your Own Adventure](#choose-your-own-adventure)
  - [SSH](#ssh)
  - [RKE2](#RKE2)
    - [Airgap](#airgap)
    - [Online](#online)
  - [K3s](#K3s)
- [Ingress](#Ingress)
- [Storage](#Storage)
- [Code](#Code)
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
ssh root@student$NUMa.stackrox.live # Change $NUM to your student number

# Validate the student number
echo $NUM
```

### RKE2

All the [documentation](https://docs.rke2.io/). We have a choice. We can install airgapped or online.

#### Airgap

For this workshop all the bits have been downloaded for you. Check `/opt/`.

If we had to get the bits.

```bash
mkdir /opt/rke2-artifacts && cd /opt/rke2-artifacts/
curl -#OL https://github.com/rancher/rke2/releases/download/v1.24.3%2Brke2r1/rke2-images.linux-amd64.tar.zst
curl -#OL https://github.com/rancher/rke2/releases/download/v1.24.3%2Brke2r1/rke2.linux-amd64.tar.gz
curl -#OL https://github.com/rancher/rke2/releases/download/v1.24.3%2Brke2r1/sha256sum-amd64.txt

dnf install -y container-selinux iptables libnetfilter_conntrack libnfnetlink libnftnl policycoreutils-python-utils

curl -sfL https://get.rke2.io --output install.sh
```

##### on studentA

```bash
cd /opt/rke2-artifacts/
useradd -r -c "etcd user" -s /sbin/nologin -M etcd -U
mkdir -p /etc/rancher/rke2/ /var/lib/rancher/rke2/server/manifests/;
echo -e "#disable: rke2-ingress-nginx\n#profile: cis-1.6\nselinux: false" > /etc/rancher/rke2/config.yaml; 
echo -e "---\napiVersion: helm.cattle.io/v1\nkind: HelmChartConfig\nmetadata:\n  name: rke2-ingress-nginx\n  namespace: kube-system\nspec:\n  valuesContent: |-\n    controller:\n      config:\n        use-forwarded-headers: true\n      extraArgs:\n        enable-ssl-passthrough: true" > /var/lib/rancher/rke2/server/manifests/rke2-ingress-nginx-config.yaml; 
INSTALL_RKE2_ARTIFACT_PATH=/opt/rke2-artifacts sh install.sh 
systemctl enable rke2-server.service && systemctl start rke2-server.service

# wait and add link
export KUBECONFIG=/etc/rancher/rke2/rke2.yaml 
ln -s /var/lib/rancher/rke2/data/v1*/bin/kubectl  /usr/local/bin/kubectl

# get token on server
cat /var/lib/rancher/rke2/server/node-token
# will need this for the agents to join

```

### on agents

```bash
SERVERIP=142.93.179.101
token=K107d13b6508d78b91c81bf19c6179b3bd3c0d8c267b7c895d3fafd6d7eca76d9d3::server:078debaf13f07dfe1611526d9ceec385
mkdir -p /etc/rancher/rke2/ && echo "server: https://$SERVERIP:9345" > /etc/rancher/rke2/config.yaml && echo "token: "$token >> /etc/rancher/rke2/config.yaml

cd /root/rke2-artifacts/
INSTALL_RKE2_ARTIFACT_PATH=/root/rke2-artifacts INSTALL_RKE2_TYPE=agent sh install.sh && systemctl enable rke2-agent.service && systemctl start rke2-agent.service
```




#### Online


### K3s

Lets deploy [k3s](https://k3s.io). From the $NUMa node we will run all the commands. Don't for get to set the student number.

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

## Ingress

If you can't tell I like easy and simple. This also applies to Ingress. For that [Traefik](https://traefik.io/) for the win!

```bash
# install Traefik CRD for TLS passthrough
kubectl apply -f https://raw.githubusercontent.com/clemenko/k8s_yaml/master/traefik_crd_deployment.yml

# verify it is up
kubectl get pod -n traefik

# lets create an ingress entry for this. CHANGE the $NUM to your student number.
# and yes there are escape characters.
cat <<EOF | kubectl apply -f -
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: traefik-ingressroute
  namespace: traefik
spec:
  entryPoints:
    - web
  routes:
    - match: Host(\`traefik.$NUM.stackrox.live\`)
      kind: Rule
      services:
        - name: traefik
          port: 8080
EOF
```

Now you can navigate in the browser to http://traefik.$NUM.stackrox.live and see the traefik dashboard.

## Storage

Here is the easiest way to build stateful storage on this cluster. [Longhorn](https://longhorn.io) from Rancher is awesome...

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
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: traefik-ingressroute
  namespace: longhorn-system
spec:
  entryPoints:
    - web
  routes:
    - match: Host(\`longhorn.$NUM.stackrox.live\`)
      kind: Rule
      services:
        - name: longhorn-frontend
          port: 80
EOF

```

Navigate to the dashboard at http://longhorn.$NUM.stackrox.live

Once everything is running we can move on.

## Code

Deploy if not deployed for you.

```bash
# curl all the things
curl -s https://raw.githubusercontent.com/clemenko/k8s_yaml/master/workshop-code-server.yml | sed 's/dockr.life/'$NUM'.stackrox.live/g' | kubectl  apply -f -

# ingress
curl -s https://raw.githubusercontent.com/clemenko/k8s_yaml/master/workshop_yamls.yaml | sed "s/\$NUM/$NUM/" | kubectl apply -f -
```

Now you can navigate in the browser to http://code.$NUM.stackrox.live and login in with `Pa22word`.

You will need to add a few things. The root password is `Pa22word`.

We need to setup something.

```bash
# password is Pa22word
sudo -i

# add a few packages
apt update; apt install pdsh vim -y

# Validate student number
echo $NUM
```

## Questions, Thoughts

## Profit

![success](./images/success.jpg)
#!/bin/bash
###################################
# edit vars
###################################
set -e
num=1 # num of students
prefix=student
password=Pa22word
zone=nyc3
size=s-4vcpu-8gb
key=30:98:4f:c5:47:c2:88:28:fe:3c:23:cd:52:49:51:01

domain=rfed.run

image=rockylinux-9-x64

deploy_k3s=false

######  NO MOAR EDITS #######
export RED='\x1b[0;31m'
export GREEN='\x1b[32m'
export BLUE='\x1b[34m'
export YELLOW='\x1b[33m'
export NO_COLOR='\x1b[0m'

#better error checking
command -v pdsh >/dev/null 2>&1 || { echo -e "$RED" " ** Pdsh was not found. Please install before preceeding. ** " "$NO_COLOR" >&2; exit 1; }

################################# up ################################
function up () {
if [ -f hosts.txt ]; then
  echo -e "$RED" "Warning - cluster already detected..." "$NO_COLOR"
  exit
fi

build_list=""
for i in $(seq 1 $num); do
 build_list="$prefix"$i"a $build_list"
 build_list="$prefix"$i"b $build_list"
 build_list="$prefix"$i"c $build_list"
done
echo -n " building vms for $num $prefix(s): "
doctl compute droplet create $build_list --region $zone --image $image --size $size --ssh-keys $key --wait > /dev/null 2>&1
doctl compute droplet list|grep -v ID|grep $prefix|awk '{print $3" "$2}'> hosts.txt
echo -e "$GREEN" "ok" "$NO_COLOR"

#check for SSH
echo -n " checking for ssh"
for ext in $(awk '{print $1}' hosts.txt); do
  until [ $(ssh -o ConnectTimeout=1 $user@$ext 'exit' 2>&1 | grep 'timed out\|refused' | wc -l) = 0 ]; do echo -n "." ; sleep 5; done
done
echo -e "$GREEN" "ok" "$NO_COLOR"

host_list=$(awk '{printf $1","}' hosts.txt|sed 's/,$//')
master_list=$(awk '/a/{printf $1","}' hosts.txt| sed 's/,$//')

echo -n " updating dns "
for i in $(seq 1 $num); do
 doctl compute domain records create $domain --record-type A --record-name $prefix"$i"a --record-ttl 150 --record-data $(cat hosts.txt|grep $prefix"$i"a|awk '{print $1}') > /dev/null 2>&1
 doctl compute domain records create $domain --record-type A --record-name $prefix"$i"b --record-ttl 150 --record-data $(cat hosts.txt|grep $prefix"$i"b|awk '{print $1}') > /dev/null 2>&1
 doctl compute domain records create $domain --record-type A --record-name $prefix"$i"c --record-ttl 150 --record-data $(cat hosts.txt|grep $prefix"$i"c|awk '{print $1}') > /dev/null 2>&1
 doctl compute domain records create $domain --record-type A --record-name $i --record-ttl 150 --record-data $(cat hosts.txt|grep $prefix"$i"a|awk '{print $1}') > /dev/null 2>&1
 doctl compute domain records create $domain --record-type CNAME --record-name "*.$i" --record-ttl 150 --record-data "$i".$domain. > /dev/null 2>&1
done
echo -e "$GREEN" "ok" "$NO_COLOR"

sleep 40

echo -n " adding os packages"
pdsh -l root -w $host_list 'yum install -y iscsi-initiator-utils; systemctl start iscsid.service; systemctl enable iscsid.service vim'  > /dev/null 2>&1
echo -e "$GREEN" "ok" "$NO_COLOR"

echo -n " updating sshd "
pdsh -l root -w $host_list 'echo "root:Pa22word" | chpasswd; sed -i "s/PasswordAuthentication no/PasswordAuthentication yes/g" /etc/ssh/sshd_config; systemctl restart sshd' > /dev/null 2>&1
echo -e "$GREEN" "ok" "$NO_COLOR"

echo -n " install k3sup"
pdsh -l root -w $host_list 'curl -sLS https://get.k3sup.dev | sudo sh ;echo "StrictHostKeyChecking no" > ~/.ssh/config; echo search '$domain' >> /etc/resolvconf/resolv.conf.d/tail; resolvconf -u' > /dev/null 2>&1
echo -e "$GREEN" "ok" "$NO_COLOR"

echo -n " setting up environment"
pdsh -l root -w $host_list 'echo $(hostname| sed -e "s/student//" -e "s/a//" -e "s/b//" -e "s/c//") > /root/NUM;
echo "export NUM=\$(cat /root/NUM)" >> .bash_profile; echo "export ipa=\$(getent hosts student\"\$NUM\"a.'$domain'|awk '"'"'{print \$1}'"'"')" >> .bash_profile;echo "export ipb=\$(getent hosts student\"\$NUM\"b.'$domain'|awk '"'"'{print \$1}'"'"')" >> .bash_profile;echo "export ipc=\$(getent hosts student\"\$NUM\"c.'$domain'|awk '"'"'{print \$1}'"'"')" >> .bash_profile ; echo "export PATH=\$PATH:/opt/bin" >> .bash_profile'
echo -e "$GREEN" "ok" "$NO_COLOR"

#kernel tuning
echo -e -n " updating kernel settings"
pdsh -l root -w $host_list 'cat << EOF >> /etc/sysctl.conf
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
sysctl -p' > /dev/null 2>&1
echo -e "$GREEN" "ok" "$NO_COLOR"

pdsh -l root -w $host_list 'mkdir /opt/rke2-artifacts && cd /opt/rke2-artifacts/ && curl -#OL https://github.com/rancher/rke2/releases/download/v1.24.6%2Brke2r1/rke2-images.linux-amd64.tar.zst && curl -#OL https://github.com/rancher/rke2/releases/download/v1.24.6%2Brke2r1/rke2.linux-amd64.tar.gz && curl -#OL https://github.com/rancher/rke2/releases/download/v1.24.6%2Brke2r1/sha256sum-amd64.txt && dnf install -y container-selinux iptables libnetfilter_conntrack libnfnetlink libnftnl policycoreutils-python-utils && curl -sfL https://get.rke2.io --output install.sh && chmod 755 install.sh; curl -#OL https://github.com/rancher/rke2-selinux/releases/download/v0.9.stable.1/rke2-selinux-0.9-1.el8.noarch.rpm; curl -#OL https://github.com/rancher/rke2-packaging/releases/download/v1.24.6%2Brke2r1.stable.0/rke2-common-1.24.6.rke2r1-0.x86_64.rpm' > /dev/null 2>&1
echo -e "$GREEN" "ok" "$NO_COLOR"

echo -n " install scripts"
pdsh -l root -w $master_list 'cd /opt/rke2-artifacts; curl -#OL https://raw.githubusercontent.com/clemenko/rke_workshop/main/easy_rancher.sh; curl -#OL https://raw.githubusercontent.com/clemenko/rke_workshop/main/master_build.sh; chmod 755 *.sh' > /dev/null 2>&1
echo -e "$GREEN" "ok" "$NO_COLOR"

echo -n " set up ssh key"
ssh-keygen -b 4092 -t rsa -f sshkey -q -N ""
for i in $(seq 1 $num); do
  rsync -avP sshkey root@$prefix"$i"a.$domain:/root/.ssh/id_rsa  > /dev/null 2>&1
  ssh-copy-id -i sshkey root@$prefix"$i"a.$domain > /dev/null 2>&1
  ssh-copy-id -i sshkey root@$prefix"$i"b.$domain > /dev/null 2>&1
  ssh-copy-id -i sshkey root@$prefix"$i"c.$domain > /dev/null 2>&1
  rsync -avP master_build.sh root@$prefix"$i"a.$domain:/root/ > /dev/null 2>&1
done
echo "$GREEN" "ok" "$NO_COLOR"

if [ "$deploy_k3s" = true ]; then
  echo -n " deploy k3s, traefik, and code-server"
  pdsh -l root -w $master_list '/root/master_build.sh' > /dev/null 2>&1
  echo -e "$GREEN" "ok" "$NO_COLOR"
fi

echo ""
echo "===== Cluster ====="
doctl compute droplet list --no-header |grep $prefix
}

############################## kill ################################
#remove the vms
function kill () {
echo -n " killing it all "
for i in $(doctl compute domain records list $domain --no-header|grep $prefix|awk '{print $1}'; doctl compute domain records list $domain --no-header|grep -w '1\|2\|3\|4\|5\|6\|7\|8\|9\|10\|11'|awk '{print $1}' ); do 
  doctl compute domain records delete $domain $i --force
done

for i in $(doctl compute droplet list --no-header|grep $prefix|awk '{print $1}'); do 
  doctl compute droplet delete --force $i
done

rm -rf hosts.txt sshkey*
echo -e "$GREEN" "ok" "$NO_COLOR"
}

case "$1" in
        up) up;;
        kill) kill;;
        *) echo " Usage: $0 {up|kill}";;
esac

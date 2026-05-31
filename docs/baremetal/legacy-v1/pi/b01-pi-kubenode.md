## Installing a front-end firewall (ufw)
https://www.server-world.info/en/note?os=Debian_12&p=ufw&f=1

### Install UFW
`apt -y install ufw`

### Run UFW as a service
`systemctl enable --now ufw`
`systemctl status ufw`

### Enable UFW
`ufw status verbose`
`ufw enable`

### Open specific ports (for k8s api server, metallb)
```
# for kubeapi
ufw allow from <<kubeapi private ip address>> to any port 6443 proto tcp
# for metallb
ufw allow 7946
```

## Installing containerd
https://github.com/containerd/containerd/blob/main/docs/getting-started.md

1. Find the containerd runtime used by your k8s version
```
ssh <<username>>@<<kubeapi private ip address>>
kubectl get nodes -o wide
```

2. Download the containerd version used by the control plane
```
ssh <<username>>@<<pi-node private ip address>>
# the below is for version 1.6.21 for linux os with arm architecture
wget "https://github.com/containerd/containerd/releases/download/v1.6.21/containerd-1.6.21-linux-arm64.tar.gz"
```

3. Compare the checksums (they should be the same)
```
wget "https://github.com/containerd/containerd/releases/download/v1.6.21/containerd-1.6.21-linux-arm64.tar.gz.sha256sum"
cat containerd-1.6.21-linux-arm64.tar.gz.sha256sum
sha256sum containerd-1.6.21-linux-arm64.tar.gz
```

4. Extract to /usr/local
```
tar Cxzvf /usr/local containerd-1.6.21-linux-arm64.tar.gz
```

5. You'll also want to download the `containerd.service` if you want to start it with `systemd`
```
wget "https://raw.githubusercontent.com/containerd/containerd/main/containerd.service"
mv containerd.service "/usr/local/lib/systemd/system/containerd.service"
systemctl daemon-reload
systemctl enable --now containerd
```

### Install runc
1. Get the binary
```
#below is version 1.1.10 for arm64 architecture
wget "https://github.com/opencontainers/runc/releases/download/v1.1.10/runc.arm64"
```

2. Install it
```
install -m 755 runc.arm64 /usr/local/sbin/runc
```

### Install a CNI plugin
1. Download the CNI plugin
```
# the below is for version 1.4.0 for linux os with arm architecture
wget "https://github.com/containernetworking/plugins/releases/download/v1.4.0/cni-plugins-linux-arm64-v1.4.0.tgz"
```

2. Extract to /opt/cni/bin
```
mkdir -p /opt/cni/bin
tar Cxzvf /opt/cni/bin cni-plugins-linux-arm64-v1.4.0.tgz
```

### Generate and use default containerd config
```
containerd config default > config.toml
sudo mv config.toml /etc/containerd/config.toml
```

This config will have to be modified to work with Kubernetes (see Setting up containerd with Kubernetes)

## Setting up containerd with Kubernetes
https://kubernetes.io/docs/setup/production-environment/container-runtimes/#containerd

This project created a `config.toml` by generating a default containerd config and following the instructions below:

### Configuring the systemd cgroup driver
To use the systemd cgroup driver in /etc/containerd/config.toml with runc, set
```
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
  ...
  [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
    SystemdCgroup = true
```

The systemd cgroup driver is recommended if you use cgroup v2.

### Ensure CRI is not disabled
You need CRI support enabled to use containerd with Kubernetes. Make sure that cri is not included in the `disabled_plugins` list within `/etc/containerd/config.toml`; if you made changes to that file, also restart containerd.

### Overriding the sandbox (pause) image
In your containerd config you can overwrite the sandbox image by setting the following config:
```
[plugins."io.containerd.grpc.v1.cri"]
  sandbox_image = "registry.k8s.io/pause:3.9"
```

### Use custom containerd config
For your convenience, the above steps were performed for this project and the resulting config is found at `https://raw.githubusercontent.com/toiletpapar/smithers-infrastructure/main/docs/baremetal/config.toml`

If you `wget` the above config, ensure you move it:
`sudo mv config.toml /etc/containerd/config.toml`

### Restart containerd
`sudo systemctl restart containerd`

## Ensure that you have the containerd runtime
https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/#installing-runtime

Containerd is found here: `/var/run/containerd/containerd.sock`

## Install kubeadm
1. Update the apt package index and install packages needed to use the Kubernetes apt repository
```
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl gpg
```

2. Download the public signing key for the Kubernetes package repositories. The same signing key is used for all repositories so you can disregard the version in the URL
```
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
```

3. Add the appropriate Kubernetes apt repository. Please note that this repository have packages only for Kubernetes 1.28; for other Kubernetes minor versions, you need to change the Kubernetes minor version in the URL to match your desired minor version (you should also check that you are reading the documentation for the version of Kubernetes that you plan to install).
```
# This overwrites any existing configuration in /etc/apt/sources.list.d/kubernetes.list
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
```

4. Update the apt package index, install kubelet, kubeadm and kubectl, and pin their version
```
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
```

## Configuring a cgroup driver
https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/configure-cgroup-driver/
Both the container runtime and the kubelet have a property called "cgroup driver", which is important for the management of cgroups on Linux machines.

Matching the container runtime and kubelet cgroup drivers is required or otherwise the kubelet process will fail.

## Retrieve join command
In a separate shell, login to the control plane and retrieve the join command
```
ssh <<username>>@<<kubeapi private ip address>>
```

In this project, we use flatcarOS and the `core` user for the kubectl control plane

```
ssh core@<<kubeapi private ip address>>
kubeadm token create --print-join-command
```

Run the printed join command on the node that you want to join the cluster (the pi)

### Troubleshooting cgroup_memory
https://forums.raspberrypi.com/viewtopic.php?t=203128
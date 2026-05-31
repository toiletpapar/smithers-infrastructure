# For setting up a general computer

## Flatcar OS (Container OS)
### Boot from the Flatcar ISO on host machine
* Download Flatcar ISO from drive
* Burn the image into a drive (possibly using Raspberry Pi Imager)
* Boot the image via BIOS compatibility mode (not UEFI)
  - https://www.asus.com/us/support/FAQ/1013017/#A1 for ASUS Laptop (sustain press F2 for BIOS)
  - Enter the [Save & Exit] screen, select the USB flash drive or CD-ROM in Boot Override you wish to boot from, then press the Enter key to boot from the selected USB or CD-ROM. 

At this point, you should be in Flatcar Linux and should be able to run commands

### Create the config
You need to create a Butane config that will
* configure the networks used by systemd-networkd (including wpa_supplicant) - https://www.flatcar.org/docs/latest/setup/customization/network-config-with-networkd/
* allow you to SSH into the machine - https://www.flatcar.org/docs/latest/setup/security/customizing-sshd/
* run k8s (control plane, nodes) - https://www.flatcar.org/docs/latest/container-runtimes/getting-started-with-kubernetes/
* allow power saving when idle - https://www.flatcar.org/docs/latest/setup/customization/power-management/
* (Required for `metallb` running in L2 mode) modify iptables to open port 7946 using systemd units - https://www.flatcar.org/docs/latest/provisioning/config-transpiler/examples/#systemd-units
* (Required for `ingress-nginx` webhook admission) modify iptables to open port 8443 using systemd units - https://www.flatcar.org/docs/latest/provisioning/config-transpiler/examples/#systemd-units

#### Configure a wired network
Find your network interface
```
ls /sys/class/net
```

Note the DNS server used here can be created following the instructions at `pi/b01-pi-dns.md`. Once created, the private ip of the box hosting the DNS server should be placed in the `DNS` field.

Note you'll likely want a static ip for the control plane
You can use your router's DHCP reservation for this 
```
variant: flatcar
version: 1.0.0
storage:
  files:
    - path: /etc/systemd/network/00-<<your network interface>>.network
      contents:
        inline: |
          [Match]
          Name=<<your network interface>>

          [Network]
          DHCP=yes
```

You can also self-assign an ip with the config below
```
variant: flatcar
version: 1.0.0
storage:
  files:
    - path: /etc/systemd/network/00-<<your network interface>>.network
      contents:
        inline: |
          [Match]
          Name=<<your network interface>>

          [Network]
          DNS=<<your DNS ip address>>
          Address=<<reserved ip>>/24
          Gateway=<<router gateway ip>>
```

Make the appropriate changes to `cl-control.yaml` and `cl-node.yaml` for your particular network interface

#### SSH Daemon
https://www.flatcar.org/docs/latest/setup/security/customizing-sshd/
Flatcar Container Linux defaults to running an OpenSSH daemon using systemd socket activation – when a client connects to the port configured for SSH, sshd is started on the fly for that client using a systemd unit derived automatically from a template.

This project only allows the `core` user to login and disables password based authentication.
For the public/private keypair (for rsa) use
```
ssh-keygen
```

```
variant: flatcar
version: 1.0.0
passwd:
  users:
    - name: core
      ssh_authorized_keys:
        - ssh-rsa <<public key>>
storage:
  files:
    - path: /etc/ssh/sshd_config
      overwrite: true
      mode: 0600
      contents:
        inline: |
          # Supported HostKey algorithms by order of preference.
          HostKey /etc/ssh/ssh_host_rsa_key
          HostKey /etc/ssh/ssh_host_ed25519_key
          HostKey /etc/ssh/ssh_host_ecdsa_key
          
          # Use most defaults for sshd configuration.
          UsePrivilegeSeparation sandbox
          Subsystem sftp internal-sftp
          UseDNS no

          PermitRootLogin no
          AllowUsers core
          AuthenticationMethods publickey
```

Make the appropriate changes to `cl-control.yaml` and `cl-node.yaml` for your particular private/public keypairs

#### Getting the host linked with the K8s cluster
https://www.flatcar.org/docs/latest/container-runtimes/getting-started-with-kubernetes/

This project uses kubeadm to manage the k8s cluster.
This project uses systemd-sysext to retrieve binaries and update them
This project reboots nodes whenever there are updates to flatcar or k8s (via Kured)

#### Power management
https://www.flatcar.org/docs/latest/setup/customization/power-management/
This project uses the conservative governor (Dynamically scale frequency at 95% cpu load) given that this project does not have continuous large loads.

```
variant: flatcar
version: 1.0.0
systemd:
  units:
    - name: cpu-governor.service
      enabled: true
      contents: |
        [Unit]
        Description=Enable CPU power saving

        [Service]
        Type=oneshot
        RemainAfterExit=yes
        ExecStart=/usr/sbin/modprobe cpufreq_conservative
        ExecStart=/usr/bin/sh -c '/usr/bin/echo "conservative" | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor'

        [Install]
        WantedBy=multi-user.target   
```

#### Configure iptables with systemd units
This step is required only if you want to run `metallb` in L2 mode. In this case, we need to open port 7946 to allow communication between nodes with `iptables`. See https://metallb.universe.tf/#requirements.

```
variant: flatcar
version: 1.0.0
systemd:
  units:
    - name: openport-metallb.service
      enabled: true
      contents: |
        [Unit]
        Description=Open port 7946 for metallb to use for node communication.

        [Service]
        Type=oneshot
        ExecStart=/sbin/iptables -I INPUT -p tcp --dport 7946 -j ACCEPT
        ExecStart=/sbin/iptables -I OUTPUT -p tcp --sport 7946 -j ACCEPT

        [Install]
        WantedBy=multi-user.target    
```

This step is required to allow the ingress-nginx admissions webhook to communicate between nodes. See https://kubernetes.github.io/ingress-nginx/deploy/#firewall-configuration
```
variant: flatcar
version: 1.0.0
systemd:
  units:
    - name: openport-ingress-nginx.service
      enabled: true
      contents: |
        [Unit]
        Description=Open port 8443 for ingress-nginx admission controller.

        [Service]
        Type=oneshot
        ExecStart=/sbin/iptables -I INPUT -p tcp --dport 8443 -j ACCEPT
        ExecStart=/sbin/iptables -I OUTPUT -p tcp --sport 8443 -j ACCEPT

        [Install]
        WantedBy=multi-user.target    
```

#### Configure your node's hostname
This step is used to give your node a human-readable name.
```
variant: flatcar
version: 1.0.0
systemd:
  units:
    - name: hostname.service
      enabled: true
      contents: |
        [Unit]
        Description=Change hostname to be human-readable.
        Before=kubeadm.service

        [Service]
        Type=oneshot
        ExecStart=hostnamectl set-hostname <desired hostname>

        [Install]
        WantedBy=multi-user.target  
```

Ensure each node has a unique name to reduce conflict when using local storage and for assisting in troubleshooting. If you've already setup your DNS server specified in `pi/b01-pi-dns.md`, this should be the hostname used to identify your k8s server and can be found in your zone files. In this project, the control plane is `k8s.smithers.private`.

#### (Optional) Partition your drive
https://coreos.github.io/butane/config-flatcar-v1_0/
https://www.flatcar.org/docs/latest/provisioning/ignition/specification/
https://www.flatcar.org/docs/latest/setup/storage/mounting-storage/
https://www.flatcar.org/docs/latest/reference/developer-guides/sdk-disk-partitions/

This step is used to parition the disks in your node so that they can be provisioned as local persistant volumes. These workloads require persistant storage:
* PSQL Database for Smithers Application

These workloads require ephemeral storage:
* Smithers Application Server
* Smithers Crawler Job

```
variant: flatcar
version: 1.0.0
storage:
  disks:
    - device: /dev/sda
      wipe_table: false
      partitions:
        - number: 9
          label: ROOT
          size_mib: 409600
          resize: true
        - number: 10
          label: data
          size_mib: 0
  filesystems:
    - device: /dev/disk/by-partlabel/ROOT
      format: ext4
      wipe_filesystem: true
      label: ROOT
    - path: /mnt/disks/data
      device: /dev/disk/by-partlabel/data
      format: ext4
      wipe_filesystem: true
      label: data
      with_mount_unit: true
```

This will resize the disk that flatcar linux will likely be installed to, `dev/sda`. This will resize the ROOT partition and let the data partition take the rest of the available space. If you have a second storage device, consider creating partitions there instead of the device that contains flatcar linux.

### Install flatcar on the host machine's drive
IMPORTANT: The configs provided in this project work for my hardware. Your hardware may differ and require additional tweaks. Please exercise caution. Of note:
- I partitioned my disk to fit my node, not necessarily the hardware requirements of the project.

Find the Butane config used for the control plane at `docs/baremetal/cl-control.yaml`
Find the Butane config used for nodes at `docs/baremetal/cl-node.yaml`

You can grab these configs by:
```
wget "https://raw.githubusercontent.com/toiletpapar/smithers-infrastructure/main/docs/baremetal/flatcar/cl-control.yaml"
wget "https://raw.githubusercontent.com/toiletpapar/smithers-infrastructure/main/docs/baremetal/flatcar/cl-node.yaml"
```

Translate the Butane config to an Ignition config
```
# Control Plane
cat cl-control.yaml | docker run --rm -i quay.io/coreos/butane:latest > ignition-control.json

# Nodes
cat cl-node.yaml | docker run --rm -i quay.io/coreos/butane:latest > ignition-node.json
```

Find the drive you want to install it to, likely `/dev/sda`
```
lsblk
```

Run the installation script
```
sudo flatcar-install -d /dev/sda -i ignition-<control|node>.json -C stable
```

At this point flatcar should be bootable from the host's disk. It is now safe to reboot the host and remove the boot drive.
The node should also be reachable via SSH

### (Optional) Ignore the lid switch event
This optional steps allows the laptop to continue running when the lid is closed
```
vi /etc/systemd/logind.conf
```

Add the following lines:
```
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
HandleLidSwitchDocked=ignore
```

### Allow node reboots for updates
* Allow for node reboots on Kubernetes or Flatcar update (via Kured)
```
latest=$(curl -s https://api.github.com/repos/kubereboot/kured/releases | jq -r '.[0].tag_name')
kubectl apply -f "https://github.com/kubereboot/kured/releases/download/$latest/kured-$latest-dockerhub.yaml"
```

At this point, the k8s control plane should be in the "Ready" state if a CNI has been deployed (See `flatcar/a01-kubeadm.md` for more info). You can verify this by running `kubectl get nodes`

### Modify the control plane to allow for authorized access to Artifact Repository (gcp)
If you use GCP Artifcat Repository for your images, see https://www.flatcar.org/docs/latest/container-runtimes/registry-authentication/

At this point, k8s should be able to pull images from Artifact Repository

### Add custom CA to the node (private registry)
This project uses `registry.smithers.private` as the internal private registry for all project images. This registry uses a self-signed certificate. As a result, you'll need to trust the CA that issued the cert for `registry.smithers.private`. See `pi/b01-pi-regstiry.md` for details on the registry implementation. See https://www.flatcar.org/docs/latest/setup/security/adding-certificate-authorities/ for trusting custom CAs in Flatcar.

```
# shell on kubeadm node
scp core@ns1.smithers.private:/home/core/certs/domain.crt domain.crt
cp domain.crt /etc/docker/certs.d/registry.smithers.private/ca.crt

# if your crt is in pem format already, otherwise you'll need to convert it into a pem format
cp domain.crt /etc/ssl/certs/ca.pem 

# update
update-ca-certificates

# get containerd to pick it up
sudo systemctl restart containerd.service
```

### Customize your k8s cluster
For k8 cluster customization used in this project, see kubeadm.md
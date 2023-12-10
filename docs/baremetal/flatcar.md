# For setting up a general computer

## OS
### Flatcar OS (Container OS)
#### Boot from the Flatcar ISO on host machine
* Download Flatcar ISO from drive
* Burn the image into a drive (possibly using Raspberry Pi Imager)
* Boot the image via BIOS compatibility mode (not UEFI)
  - https://www.asus.com/us/support/FAQ/1013017/#A1 for ASUS Laptop

#### Create the config
You need to create a Butane config that will
* configure the networks used by systemd-networkd (including wpa_supplicant) - https://www.flatcar.org/docs/latest/setup/customization/network-config-with-networkd/
* allow you to SSH into the machine - https://www.flatcar.org/docs/latest/setup/security/customizing-sshd/
* run k8s (control plane, nodes) - https://www.flatcar.org/docs/latest/container-runtimes/getting-started-with-kubernetes/
* allow power saving when idle - https://www.flatcar.org/docs/latest/setup/customization/power-management/

Find the Butane config used for the control plane at `docs/baremetal/cl-control.yaml`
Find the Butane config used for nodes at `docs/baremetal/cl-node.yaml`

Translate the Butane config to an Ignition config
```
# Control Plane
cat cl-control.yaml | docker run --rm -i quay.io/coreos/butane:latest > ignition.json

# Nodes
cat cl-node.yaml | docker run --rm -i quay.io/coreos/butane:latest > ignition.json
```

#### Configure a wired network
Find your network interface
```
ls /sys/class/net
```

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

Make the appropriate changes to `cl-control.yaml` and `cl-node.yaml` for your particular network interface

#### SSH Daemon
https://www.flatcar.org/docs/latest/setup/security/customizing-sshd/
Flatcar Container Linux defaults to running an OpenSSH daemon using systemd socket activation – when a client connects to the port configured for SSH, sshd is started on the fly for that client using a systemd unit derived automatically from a template.

This project only allows the `core` user to login and disables password based authentication.
```
variant: flatcar
version: 1.0.0
storage:
  files:
    - path: /etc/ssh/sshd_config
      overwrite: true
      mode: 0600
      contents:
        inline: |
          # Use most defaults for sshd configuration.
          UsePrivilegeSeparation sandbox
          Subsystem sftp internal-sftp
          UseDNS no

          PermitRootLogin no
          AllowUsers core
          AuthenticationMethods publickey
```

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


#### Install flatcar on the host machine's drive
Find the drive you want to install it to, likely `/dev/sda`
```
lsblk
```

Run the installation script
```
flatcar-install -d /dev/sda -i ignition.json -C stable
```
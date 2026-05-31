# For setting up Raspberry Pi
## Hardware
* 4 GB RAM
* 64 GB SD

## OS
### Raspberry Pi OS
* Download Raspberry Pi Imager
* Pick a `username` that you'll use when installing raspberrypi os (this project uses `core`)
* Format SD with Raspberry Pi OS w/o desktop, 64-bit
* (Optional) Customize the image with your wifi credentials. These settings will be found in the network_config of the bootfs volume.

After imaging your SD card, we will be using cloud-init to set up the rest of our settings (i.e. BIND9)

## Cloud init
In your new boot drive, there should be a standard FAT32 storage volume named bootfs (or boot). Open it like a standard flash drive. Find the user-data file. If one does not exist, create one. It should contain the following:

```yaml
#cloud-config
manage_resolv_conf: false

# 1. Choose your computer's name to make it easier to find in your router
hostname: <your computer's name>
manage_etc_hosts: true
# 2. Install the bind9 packages
packages:
- avahi-daemon
- bind9
- bind9utils
- dnsutils
apt:
  preserve_sources_list: true
  conf: |
    Acquire {
      Check-Date "false";
    };
timezone: America/Toronto
keyboard:
  model: pc105
  layout: "us"
users:
- name: core
  groups: users,adm,dialout,audio,netdev,video,plugdev,cdrom,games,input,gpio,spi,i2c,render,sudo
  shell: /bin/bash
  sudo: ['ALL=(ALL) NOPASSWD:ALL']
  # 3. Add your public SSH key so you can SSH into your pi when you feel you need to
  ssh_authorized_keys:
      - ssh-ed25519 <your public ssh key>
# 4. Pull DNS configs from your repository
write_files:
# Configure BIND9 global settings to allow queries and define forwarders
- source:
    uri: https://raw.githubusercontent.com/<path to your dns options>/named.conf.options
    headers:
      User-Agent: cloud-init on pi
  path: /etc/bind/named.conf.options
  permissions: '0644'
  owner: root:bind
# Define your custom local network zone
- source:
    uri: https://raw.githubusercontent.com/<path to your zones>/named.conf.local
    headers:
      User-Agent: cloud-init on pi
  path: /etc/bind/named.conf.local
  permissions: '0644'
  owner: root:bind
# Build the actual local DNS record database
- source:
    uri: https://raw.githubusercontent.com/<path to record definitions>/db.smithers.private
    headers:
      User-Agent: cloud-init on pi
  path: /etc/bind/db.smithers.private
    permissions: '0644'
    owner: root:bind


enable_ssh: true
rpi:
  interfaces:
    serial: true

# 5. Run runtime commands to lock in the service state
runcmd:
- systemctl daemon-reload
- systemctl enable bind9
- systemctl restart bind9

```

If you have configured your wifi as part of creating the image, you should have a network_config that looks like this:

```yaml
# network_config
network:
  version: 2
  ethernets:
    eth0:
      dhcp4: true
      dhcp6: true
      optional: true
  wifis:
    wlan0:
      dhcp4: true
      regulatory-domain: "CA"
      access-points:
        "<your SSID>":
          password: "<your hashed password>"
      optional: true
```

Replace `<values>` as required. Proceed to b01-pi-dns for an explanation of how to configure your dns server.

After ensuring all your files are uploaded remotely for your pi to pull down, plug in your boot drive into the pi. Then follow the rest of the instructions in b01-pi-dns to make your router talk to your new DNS server. You may additionally verify your installation and troubleshoot by SSH-ing into the pi.
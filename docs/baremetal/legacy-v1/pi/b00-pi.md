# For setting up Raspberry Pi
## Hardware
* 4 GB RAM
* 64 GB SD

## OS
### Raspberry Pi OS
* Download Raspberry Pi Imager
* Pick a `username` that you'll use when installing raspberrypi os (this project uses `core`)
* Format SD with Raspberry Pi OS w/o desktop, 64-bit
* Plug in keyboard, monitor, SD, and power and wait for setup

## Network
If you configured your network during pi OS customization, you may not need to follow these steps

### Connect to a network
Find current connections
```
nmcli con show
```

Disconnect any prior connections
```
nmcli con down <<SSID>>
```

Connect to your network
```
nmcli device wifi connect <<SSID>> password <<PASSWORD>>
```

At this point you should be connected to your router

### Resolving hostnames
You can find your DNS servers here
```
cat /etc/resolv.conf
```

You can test that your device can connect to the Internet
```
ping "google.com"
```

If you don't see the DNS servers provided by your router `nameserver xx.xx.xxx.xxx` or you can't reach the Internet, try modifying your connection to use Google DNS Servers

You can add the Public Google DNS Server
```
nmcli con mod "Wired connection 1" ipv4.dns "8.8.8.8 8.8.4.4"
```

Then you'll need to restart the network manager
```
service NetworkManager restart
```

## SSH
If you enabled SSH during the PI OS customization, you can ignore this section

Find your raspberry pi's ip address
```
nmcli device show
```
Depending on how you are connected to your router, your ip address (IP4.ADDRESS[1]) is in "ethernet" or "wifi" blocks

### Enable SSH on Raspberry Pi
```
sudo raspi-config
```
Select Interfacing Options
Navigate to and select SSH
Choose Yes
Select Okss
Choose Finish

### SSH into your device
```
ssh <<username>>@<<pi-node ip address>>
```

At this point you should be able to execute commands remotely. From here you can either turn your pi into a private registry (b01-pi-registry.md) or a k8s node if hardware is capable of such (b01-pi-kubenode.md)

## Install UFW
You'll want UFW to manage your firewall/ports in the other pi tutorials
https://www.server-world.info/en/note?os=Debian_12&p=ufw&f=1
`apt -y install ufw`

### Run UFW as a service
`systemctl enable --now ufw`
`systemctl status ufw`

### Enable UFW
`ufw status verbose`
`ufw enable`

### Enable SSH port
Note that when you install ufw, you also likely disabled the port for SSH.
`ufw allow ssh`
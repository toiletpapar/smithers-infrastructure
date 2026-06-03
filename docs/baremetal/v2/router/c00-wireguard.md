If you want to be able to safely access your home network while you're connected to an external network, you'll want a VPN.

My router contains a built in VPN Server so setting one up was easy: https://www.tp-link.com/ca/support/faq/3772/

However, if your router doesn't have this option then you may have to configure a VPN server yourself.

Some things to note:
- Your vpn client should be configured to point to the ip address of your dns server (in this case, our pi)
- Your vpn server and vpn clients should exist on a different subnet than your home network. If it was in the same subnet as your home network, conflicts with your home network devices may occur.
- Configure your dns server to whitelist vpn clients and the vpn server (i.e. named.conf.options)
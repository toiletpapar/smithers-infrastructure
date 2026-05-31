# For turning your pi into a DNS server for private hostnames (using BIND9)
This is so that you can refer to domain names rather than private ips in your code and manage name resolution here.
https://www.ionos.ca/digitalguide/server/configuration/how-to-make-your-raspberry-pi-into-a-dns-server/
https://arstechnica.com/gadgets/2020/08/understanding-dns-anatomy-of-a-bind-zone-file/
https://bind9.readthedocs.io/en/latest/#

This file explains the the zones that have been set up

### Options (named.conf.options)
These options turn this DNS server into a forward resolver, among other configurations.
* Add ACL for the project's private network
* Allow only our project's private network to query this DNS server
* Allow recursive queries for normal domain resolution outside of what's handled by this DNS server
* `forward-only` forwards all queries that are not handled by this DNS server
* Add addresses of public Google DNS resolvers to forward queries for which this DNS server is not authoritative
* `empty-zones-enable yes` to ensure that reverse mapped private IPs (e.g. 192.168.0.10) that are not resolve aren't forwarded to the public network
* Add `max-cache-size` for this particular project because a registry service is ran on the same host
* Add all `category default` logs to the `default_log` channel. This channel rotates from 3 files of size 250k to `/var/cache/bind/log/named/default.log`. It only contains `warning` logs and up.

### Zones (named.conf.local/named.conf.default-zones)
Define the zones for which this DNS server is authoritative (forwarding everything else): `localhost`, `0.0.127.in-addr.arpa`, `smithers.private`, `0.168.192.in-addr.arpa`
* [By default-zones] localhost - Specifies how `localhost` should resolve (e.g. to `127.0.0.1`)
* [By default-zones] 0.0.127.in-addr.arpa - Reverse map zone that specifies how `127.0.0.1` should map to `localhost`
* smithers.private - Specifies how to resolve `smithers.private` (`db.smithers.private`)

### Logs
Logs are found in /var/cache/bind/default.log with a 250k limit and rotated every 3 files

## Notes
Additionally, `/etc/bind/named.conf` may be of interest for including other files (out of the scope of this project)

The robustness of this setup can additionally be improved by leveraging another DNS server to act as a secondary to this primary.

## Modify Router to use your DNS server
This is normally done through your router's settings (GUI)

# If you need to make changes to the DNS server
The zones are found in `/etc/bind`. They can be edited in place (e.g. via `nano`) and picked up by the server via `sudo rndc reload`

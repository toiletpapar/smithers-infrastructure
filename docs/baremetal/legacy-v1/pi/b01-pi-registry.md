# For turning your pi into a private image registry
https://www.docker.com/blog/how-to-use-your-own-registry-2/

## Installing Docker
### For Pi using Raspberry Pi OS
https://docs.docker.com/engine/install/debian/#prerequisites

### For removing sudo with docker (and other post-installation instructions)
https://docs.docker.com/engine/install/linux-postinstall/

#### Automatically start on boot with systemd
```
sudo systemctl enable docker.service
sudo systemctl enable containerd.service
```

At this point you should have docker ready to go. Test this by:
```
sudo docker run hello-world
```

## Run the Registry
https://www.docker.com/blog/how-to-use-your-own-registry-2/

### Download and run the latest registry image
The default port for registry is 5000
```
sudo docker run -d -p 5000:5000 --name registry registry:latest
```

### Test
Tail the registry logs
```
docker logs -f registry
```

In another terminal:
Pull a test image from the public repo
```
docker pull hello-world
```

Tag the image with the registry location
```
docker tag hello-world localhost:5000/hello-world
```

Push the tagged image
```
docker push localhost:5000/hello-world
```

At this point you should see the tailed logs populate a request to save the hello-world image. Now let’s remove our localhost:5000/hello-world image and then pull the image from our local repository to make sure everything is working properly.

Verify that the local image list
```
docker images
```

Remove our local repo image
```
docker rmi localhost:5000/hello-world
```

Ensure it has been removed
```
docker images
```

Pull the image from the local registry
```
docker pull localhost:5000/hello-world
```

Verify the image exists
```
docker images
```

## Registry TLS
Now it's time to configure your pi to expose the registry on the private network.
https://distribution.github.io/distribution/about/deploying/#run-an-externally-accessible-registry

For an internally exposed registry, a self-signed cert secured registry should suffice. To begin this process, you must have set up a local DNS (see `baremetal/pi/b01-pi-dns.md`).
If you followed the DNS docs, then you should have a domain `registry.smithers.private` that points to your registry box. The below makes use of this domain by creating a self-signed wildcard cert.

Make the self-signed certs
```
mkdir -p certs
openssl req \
  -newkey rsa:4096 -nodes -sha256 -keyout certs/domain.key \
  -addext "subjectAltName = DNS:*.smithers.private" \
  -x509 -days 365 -out certs/domain.crt
```

During certificate genration, it'll ask a series of questions. Ensure the CN is `*.smithers.private`.

Stop the currently running registry
```
docker container stop registry
```

Restart the registry, directing it to use the TLS certificate
```
docker run -d \
  --restart=always \
  --name registry \
  -v "$(pwd)"/certs:/certs \
  -e REGISTRY_HTTP_ADDR=0.0.0.0:443 \
  -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/domain.crt \
  -e REGISTRY_HTTP_TLS_KEY=/certs/domain.key \
  -p 443:443 \
  registry:latest
```

## Instruct every docker daemon to trust the certificate
https://distribution.github.io/distribution/about/insecure/

Linux
```
scp core@registry.smithers.private:/home/core/certs/domain.crt domain.crt
cp domain.crt /etc/docker/certs.d/registry.smithers.private/ca.crt
```

Windows
```
# You may need to additionally generate a subdomain cert for use by windows. This subdomain can be signed by your wildcard cert.
## Create a new key-pair
openssl genpkey -algorithm RSA -out subdomain.key
## When prompted for the Common Name (CN), enter the specific subdomain `registry.smithers.private`
openssl req -new -days 365 -key subdomain.key -out subdomain.csr
## Sign the CSR with the domain's private key
openssl x509 -req -in subdomain.csr -CA wildcard.crt -CAkey wildcard.key -CAcreateserial -out subdomain.crt
## Verify the CN
openssl x509 -text -noout -in subdomain.crt

# You may need to adjust these for the core user or wherever the cert is located in the registry box
scp core@registry.smithers.private:/home/core/certs/domain.crt domain.crt
scp core@registry.smithers.private:/home/core/registry.certs/subdomain.crt registry.smithers.private.crt

# domain.crt should be added as a Trusted Root CA
# registry.smithers.private.crt should also be added to the Untrusted Certificate store
# Restart Docker
```

At this point you can run the Test section again on client machine and verify that you can reach the registry through `registry.smithers.private`.

Note that these certificates expire in a year.

## Stopping the registry
If you need to clean up your node, you can stop the registry and remove all its data by running the following commands:
```
docker container stop registry
docker container rm -v registry
```

## Registry Documentation
If you need to read more on the registry and additional configuration options:
https://distribution.github.io/distribution/about/

At this point your registry should be running correctly.

## Enable the registry port
Because we enabled tls for the registry
`ufw allow 443`
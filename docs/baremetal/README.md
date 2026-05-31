# Introduction
The baremetal folder describes and provides the instructions and configurations to setup a baremetal k8s cluster.

The v2 version streamlines deploying the pi and leverages k3d to simulate multi-node environments on limited hardware. This is useful especially on single-node clusters where k8s normally expects the control plane to be separated. v2 is comprised of:

* flatcar - The OS used for setting up k3d
* metallb - An implementation of the service type `LoadBalancer`
* traefik - The out of the box k3d ingress controller
* zot - The private registry where k8s will pull from hosted on k8s
* pi - The hardware. This folder describes methods to cloud-init your pi into a DNS server.

Considerations
* volumes - Unless you have configured NAS, you'll likely be limited to `local` PVs which need to be manually provisioned and require `nodeAffinity` (https://kubernetes.io/docs/concepts/storage/volumes/#local).
* LAN - The baremetal configuration is meant for a private network
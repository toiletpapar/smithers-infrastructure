The legacy version is comprised of the following components:

* flatcar - The OS used for setting up the k8s control plane and k8s nodes
* metallb - An implementation of the service type `LoadBalancer`
* pi - The hardware and OS specific to pis and their limitations. This folder describes methods to turn pis into a private registry for images, or as a node if the hardware is powerful enough.
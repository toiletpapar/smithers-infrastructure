# MetalLB
This is an open-source implementation of a load balancer suitable for use on bare metal clusters.
This is a requirement for implementing services of type `LoadBalancer`
This project runs MetalLB in layer2

## Prerequisite
At this point you should:
* Be able to access your cluster through `kubectl`
* The cluster you're accessing should be baremetal and meet these requirements:
`https://metallb.universe.tf/installation/clouds/`
* And these requirements: https://metallb.universe.tf/#requirements

## Check if port 7946 is open on all nodes in your cluster
```
ssh <<username>>@<<node ip address>> # user is probably core if you used flatcar
iptables -L | grep 7946
```

## Installing MetalLB
https://metallb.universe.tf/installation/

### Enable Strict ARP
A requirement to install metallb

#### Dry Run Changes
```
kubectl get configmap kube-proxy -n kube-system -o yaml | \
sed -e "s/strictARP: false/strictARP: true/" | \
kubectl diff -f - -n kube-system
```

No output means this is configured correctly. Otherwise, it'll show the changes you're about to make.

#### Apply Changes
```
kubectl get configmap kube-proxy -n kube-system -o yaml | \
sed -e "s/strictARP: false/strictARP: true/" | \
kubectl apply -f - -n kube-system
```

### Install via manifest
This project installs metallb through manifests. This project uses version v0.13.12
```
kubectl apply -f docs/baremetal/metallb/metallb-native.yaml
```

The installation manifest does not include a configuration file. MetalLB’s components will still start, but will remain idle until you start deploying resources.

## Configure metallb
https://metallb.universe.tf/configuration/

### Add IP Address Pool
The IPs that will be assigned to your `LoadBalancer` type services fulfilled by MetalLB.

This project uses a single load balancer instance to service the cluster and therefore only requires one ip address to hand out.

```
#ip-address-pool.yaml
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: <<name of ip address pool CRD>>
  namespace: metallb-system
spec:
  addresses:
  - <<ip address to hand out to LB service>>
```

`kubectl apply -f docs/baremetal/metallb/ip-address-pool.yaml`

### Add an l2 ip advertisement
```
#l2-advertisement.yaml
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: l2advertisement-single-ip
  namespace: metallb-system
spec:
  ipAddressPools:
  - <<name of ip address pool CRD>>
```

`kubectl apply -f docs/baremetal/metallb/l2-advertisement.yaml`

At this point, you should be able to deploy load balancer services. For additional testing to see everything is working correctly, see below.

## Testing
* Run an nginx deployment
`kubectl apply -f docs/baremetal/metallb/test/deployment.yaml`
* Create and run a ClusterIP service to match the nginx deployment
`kubectl apply -f docs/baremetal/metallb/test/service.yaml`
* Port forward to ensure you can access the nginx deployment
`kubectl port-forward service/nginx-service 8080:80`
* Open a browser at `localhost:8080` and ensure you see the nginx welcome page
* Modify the service to type load balancer
`kubectl patch service nginx-service -p '{"spec":{"type":"LoadBalancer"}}'`
* Describe the service to find the assigned ip address (LoadBalancer Ingress)
`kubectl describe service nginx-service`
* You should be able to find the nginx welcome page through the load balancer
* Clean up
`kubectl delete -f docs/baremetal/metallb/test/deployment.yaml`
`kubectl delete service nginx-service`
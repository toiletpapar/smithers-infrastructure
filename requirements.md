## Prerequesites
* Setup Domain and Cloud DNS
* Setup GKE
* Setup GCM

## Setup to push to Artifact Registry
Configure docker to use gcloud authentication
`gcloud auth configure-docker us-east1-docker.pkg.dev`

## Retrieve k8s cluster information (GKE)
`gcloud components install gke-gcloud-auth-plugin`
`gcloud container clusters get-credentials autopilot-cluster-smithers --region=us-east1`

https://cloud.google.com/kubernetes-engine/docs/how-to/cluster-access-for-kubectl

## Managing secrets in k8s with Secret Manager
* Create a service account in gcloud and gke with appropriate permissions
* Bind both service accounts together

k8s resources in `./secrets`
`kubectl apply -f ./secrets/secrets-serviceaccount.yaml`

Test
`kubectl apply -f ./secrets/test-secrets-pod.yaml`
`kubectl exec -it readonly-test --namespace=readonly-ns -- /bin/bash`
`gcloud secrets versions access 1 --secret=local-psql`
`exit`
`kubectl delete pods readonly-test`

https://cloud.google.com/kubernetes-engine/docs/tutorials/workload-identity-secrets

## Deploy single node PSQL server
`kubectl apply -f ./psql/psql-statefulset.yaml`
`kubectl apply -f ./psql/psql-service.yaml`

Currently configured with low-resources, increase ase required.

For HA-psql cluster see
https://cloud.google.com/kubernetes-engine/docs/tutorials/stateful-workloads/postgresql#deploy-postgresql

## Deploy server
Ensure that `./smithers/credentials` is populated with the appropriate credentials for gcloud
`kubectl apply -f ./smithers/smithers-deployment.yaml`
`kubectl apply -f ./smithers/smithers-service.yaml`

<!-- ## Create a Certificate and manage with GCM (repeat per expiration) -->
<!-- ### Create DNS Authorization to prove ownership
https://cloud.google.com/certificate-manager/docs/dns-authorizations

`gcloud certificate-manager dns-authorizations create tylerpoon-ca-dns-authorization --domain="tylerpoon.ca"`

### Create the certificate
https://cloud.google.com/sdk/gcloud/reference/certificate-manager/certificates/create

`gcloud certificate-manager certificates create tylerpoon.ca --dns-authorizations=tylerpoon-ca-dns-authorization --domains="tylerpoon.ca"` -->

## Deploy Ingress, Ingress Controller
### Controller
* Download yaml from https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/cloud/deploy.yaml (ingress/controller.yaml)

`kubectl apply -f ./ingress/controller.yaml`

https://kubernetes.github.io/ingress-nginx/deploy/#environment-specific-instructions

* Retrieve the IP of your load balancer
* Promote the IP to a static IP
* Patch k8s with static IP
`kubectl patch svc ingress-nginx-controller --namespace ingress-nginx -p '{"spec": {"loadBalancerIP": "xxx.xxx.xxx.xx"}}'`

https://kubernetes.github.io/ingress-nginx/examples/static-ip/

### Ingress (TODO)
`kubectl apply -f ./ingress/ingress.yaml`

https://kubernetes.github.io/ingress-nginx/examples/tls-termination/

## Install cert-manager
https://cert-manager.io/docs/installation/

* Retrieve the installation yaml from https://github.com/cert-manager/cert-manager/releases/download/v1.12.0/cert-manager.yaml (it should be `./ingress/cert-manager.yaml` in this repo)
* Update the yaml to change references to kube-system to cert-manager

We need to do this because cert-manager has issues with restrictions on gke-autopilot (what my k8s cluster is running on). You can skip this step if you're running on something else.
See https://cert-manager.io/docs/installation/compatibility/#gke-autopilot.

`kubectl apply -f ./ingress/cert-manager.yaml`

### Create Issuers (Let's Encrypt)
For Testing:
* Change your email in `./ingress/issuer-staging.yaml`
`kubectl apply -f ./ingress/issuer-staging.yaml`

For Production:
* Change your email in `./ingress/issuer-prod.yaml`
`kubectl apply -f ./ingress/issuer-prod.yaml`

## Create a certificate automatically with cert-manager
https://kubernetes.github.io/ingress-nginx/user-guide/tls/

At this point, if you've updated your ingress with `metadata.annotations.cert-manager.io/issuer: "letsencrypt-prod"`, removing the secret will retrigger reissuing of the certificate by cert-manager
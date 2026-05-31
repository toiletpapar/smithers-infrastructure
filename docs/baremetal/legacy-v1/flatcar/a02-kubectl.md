Tips to manage your nodes
# Using Helm
This project will assume a local helm installation going forward. Helm is a Kubernetes package manager. Get more details about helm here:
https://helm.sh/docs/intro/install/
https://helm.sh/docs/intro/using_helm/

# Storage
There are two ways this project will provision peristant volumes: local node storage or NAS (future). As of this comment, only instructions for local storage provisioning are provided.

## Local Storage
https://github.com/kubernetes-sigs/sig-storage-local-static-provisioner/blob/master/docs/getting-started.md
https://github.com/kubernetes-sigs/sig-storage-local-static-provisioner/blob/master/docs/operations.md#create-a-directory-for-provisioner-discovering
https://kubernetes.io/docs/concepts/storage/volumes/#local
https://kubernetes.io/docs/concepts/storage/storage-classes/#local
https://kubernetes.io/docs/concepts/storage/ephemeral-volumes/

Prerequisites: Your drive should be partitioned for the volumes you want to provision (this provides capacity isolation). If you've done the optional partitioning step in `a00-flatcar.md` then you have fulfilled this prerequisite.

We'll use the local static provisioner to help manage the lifecycle of local persistant volumes. That is:
* Each k8s storage class is represented by a "discovery directory" on every node (In this project, that directory is `/mnt/disks` for the `local-storage` class and is specified by the `classes[].hostDir` property in `local-static-provisioner-values.yaml`)
* A PV volume is created by the provisioner for every sub-directory in the "discovery directory". These subdirectories should be bind mounted to the "discovery directory" for PVs to be created (see https://github.com/kubernetes-sigs/sig-storage-local-static-provisioner/blob/76b022f7dbb48757f19ee11f31f91ab19b938407/docs/faqs.md#why-i-need-to-bind-mount-normal-directories-to-create-pvs-for-them). In this project, we created a partition that was mounted at `/mnt/disks/data` (see `filesystems` property of the flatcar butane configuration for details on the partition).
* You can use these volumes via their storage classes as normal
* (Optional) Clean up PVCs and PVs when nodes are deleted (and therefore local PVs unreachable). See https://github.com/kubernetes-sigs/sig-storage-local-static-provisioner/blob/76b022f7dbb48757f19ee11f31f91ab19b938407/docs/node-cleanup-controller.md
* Cleaning up PVs after use. Storage classes with `reclaimPolicy: Delete` should normally delete the data and allow the PV to be relcaimed. Exceptions exist here (see https://github.com/kubernetes-sigs/sig-storage-local-static-provisioner/blob/76b022f7dbb48757f19ee11f31f91ab19b938407/docs/faqs.md#pv-with-delete-reclaimpolicy-is-released-but-not-going-to-be-reclaimed)

Create a StorageClass with `volumeBindingMode` set to `WaitForFirstConsumer` to delay volume binding until pod scheduling to handle multiple local PVs in a single pod.
`kubectl create -f docs/baremetal/flatcar/local-storage.yaml`

This project has customized the local provisioner at `docs/baremetal/flatcar/local-static-provision-values.yaml`. At a high-level, the following customizations were made:
* Added a storage class that specifies the discovery directory containing the partition

Add local static provison repo to helm:
`helm repo add sig-storage-local-static-provisioner https://kubernetes-sigs.github.io/sig-storage-local-static-provisioner`

Install
`helm install local-provisioner sig-storage-local-static-provisioner/local-static-provisioner -f ./docs/baremetal/flatcar/local-static-provisioner-values.yaml`

Verify that local-volume-provisioner and pvs were created successfully
`helm list -A`
`kubectl get pv`

Additionally, ensure that the drive is empty. You'll likely find a `lost+found` you'll need to deal with after doing a fresh install of flatcar.

# Draining Nodes/Unschedulable Nodes
Use `kubectl cordon <NODE>` and `kubectl uncordon <NODE>` to mark the node as schedulable/unscheduable. This is useful if you're looking to drain the node (i.e. gracefully remove a node from service by rescheduling node resources on other nodes and preventing new nodes from being scheduled).
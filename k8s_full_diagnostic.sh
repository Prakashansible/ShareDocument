#!/bin/bash
echo "=== Kubernetes Full Diagnostic Script ==="

echo "[1] CrashLoopBackOff pods:"
kubectl get pods --all-namespaces | grep CrashLoopBackOff

echo "[2] OOMKilled pods:"
kubectl get pods --all-namespaces -o json | jq '.items[] | select(.status.containerStatuses[].lastState.terminated.reason=="OOMKilled") | .metadata.name'

echo "[3] ImagePullBackOff:"
kubectl get pods --all-namespaces | grep ImagePullBackOff

echo "[4] NodeNotReady:"
kubectl get nodes | grep NotReady

echo "[5] PVC Errors:"
kubectl get pvc --all-namespaces

echo "[6] DNS Test:"
kubectl run dns-test --image=busybox:1.28 --rm -it -- nslookup kubernetes.default

echo "[7] CNI health:"
kubectl describe node | grep -i cni

echo "[8] Scheduler pending pods:"
kubectl get pods --all-namespaces --field-selector=status.phase=Pending

echo "[9] API Rate Metrics:"
kubectl get --raw /metrics | grep apiserver_request_total | head

echo "[10] ETCD logs (requires privileges):"
kubectl logs -n kube-system -l component=etcd --tail=50

echo "[11] Network Policies:"
kubectl get netpol --all-namespaces

echo "[12] Evicted pods:"
kubectl get pods --all-namespaces | grep Evicted

echo "[13] Node Disk Pressure:"
kubectl describe nodes | grep -i DiskPressure

echo "[14] Service connectivity test (example):"
#kubectl exec <pod> -- curl <service>:<port>

echo "[15] ConfigMap Mount Issues:"
kubectl get events --all-namespaces | grep ConfigMap

echo "[16] Secret validation:"
kubectl get secrets --all-namespaces

echo "[17] High restart pods:"
kubectl get pods --all-namespaces --sort-by='.status.containerStatuses[0].restartCount'

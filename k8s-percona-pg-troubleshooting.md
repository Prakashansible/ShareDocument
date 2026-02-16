## Percona Operator for PostgreSQL – Production Troubleshooting Runbook

**Cluster**: `pgkubcluster`  
**Namespace**: `postgres-operator`  
**Operator**: Percona Operator for PostgreSQL (POPG)

This runbook provides **short, production-safe steps** to diagnose and fix common Kubernetes issues for the Percona Operator for PostgreSQL.

All commands below assume:

- **Namespace**: `postgres-operator`
- **Cluster CR name**: `pgkubcluster`
- **CRD**: `PerconaPGCluster` (`perconapgcluster.pg.percona.com`)

You can always adapt commands for a different namespace/cluster by changing:

```bash
NAMESPACE=postgres-operator
CLUSTER=pgkubcluster
```

---

## 1. General Status Checks

Use these to quickly understand the current state of the cluster.

```bash
# Set convenience variables (adjust if needed)
export NAMESPACE=postgres-operator
export CLUSTER=pgkubcluster

# Operator deployment and logs
kubectl -n "$NAMESPACE" get deploy -l app.kubernetes.io/name=percona-postgresql-operator
kubectl -n "$NAMESPACE" logs deploy/percona-postgresql-operator --tail=200

# PerconaPGCluster CR and status
kubectl -n "$NAMESPACE" get perconapgcluster.pg.percona.com
kubectl -n "$NAMESPACE" get perconapgcluster.pg.percona.com "$CLUSTER" -o yaml

# All pods managed by this cluster
kubectl -n "$NAMESPACE" get pods -l app.kubernetes.io/instance="$CLUSTER" -o wide
kubectl -n "$NAMESPACE" get pods -l app.kubernetes.io/part-of=pgkubcluster -o wide

# Events in the namespace (most recent first)
kubectl -n "$NAMESPACE" get events --sort-by=.lastTimestamp
```

---

## 2. Image Pull Errors

**Goal**: Fix pods failing with `ErrImagePull` / `ImagePullBackOff`.

### Quick Diagnosis

```bash
export NAMESPACE=postgres-operator
export CLUSTER=pgkubcluster

kubectl -n "$NAMESPACE" get pods
kubectl -n "$NAMESPACE" describe pod <pod-name>
```

Look for messages such as:

- `Failed to pull image "…"`  
- `Error response from daemon: pull access denied`  
- DNS / network timeouts to the registry.

### Resolution

1. **Verify images configured in the CR**:

   ```bash
   kubectl -n "$NAMESPACE" get perconapgcluster.pg.percona.com "$CLUSTER" -o yaml | grep -i 'image:' -n
   ```

   Ensure:

   - PostgreSQL image is correct (`spec.image` and any component-specific overrides).
   - Proxy/HA images are valid (`spec.proxy.pgBouncer.image`, `spec.proxy.haproxy.image`, etc.).
   - Backup images are correct (`spec.backup.pgBackRest.image`).

2. **Private registry**:

   - Create the Docker registry secret:

     ```bash
     kubectl -n "$NAMESPACE" create secret docker-registry registry-cred \
       --docker-server=<REGISTRY_URL> \
       --docker-username=<USERNAME> \
       --docker-password=<PASSWORD> \
       --docker-email=<EMAIL>
     ```

   - Reference the secret in the CR:

     ```bash
     kubectl -n "$NAMESPACE" edit perconapgcluster.pg.percona.com "$CLUSTER"
     ```

     Under the appropriate section(s), add:

     ```yaml
     spec:
       imagePullSecrets:
         - name: registry-cred
     ```

3. **Network/DNS to registry**:

   - Check node/network-level issues with a debug pod:

     ```bash
     kubectl -n "$NAMESPACE" run net-debug --rm -it --image=busybox --restart=Never -- sh
     # Inside the pod:
     nslookup <REGISTRY_URL>
     ping <REGISTRY_URL>
     ```

4. **Reconcile**:

   Once images and secrets are corrected in the CR:

   ```bash
   kubectl -n "$NAMESPACE" delete pod <failing-pod-name>
   # Operator will recreate it using the corrected spec
   ```

---

## 3. Crashing Pods (CrashLoopBackOff)

**Goal**: Stabilize pods that repeatedly crash (Postgres, Patroni, proxies).

### Quick Diagnosis

```bash
export NAMESPACE=postgres-operator

kubectl -n "$NAMESPACE" get pods
kubectl -n "$NAMESPACE" describe pod <pg-pod-name>

# Check individual containers
kubectl -n "$NAMESPACE" logs <pg-pod-name> -c postgres --tail=200
kubectl -n "$NAMESPACE" logs <pg-pod-name> -c patroni --tail=200
kubectl -n "$NAMESPACE" logs <proxy-pod-name> -c pgbouncer --tail=200
```

Focus on:

- Config errors (bad Patroni/PG parameters).
- Data directory permissions.
- OOMKilled / resource limits.
- Readiness/liveness probe failures causing restarts.

### Resolution

1. **Do not modify StatefulSets directly**. Always update the **`PerconaPGCluster` CR**:

   ```bash
   kubectl -n "$NAMESPACE" edit perconapgcluster.pg.percona.com pgkubcluster
   ```

2. **Fix bad configuration**:

   - Use supported fields such as:

     ```yaml
     spec:
       patroni:
         pgParameters:
           max_connections: "200"
           shared_buffers: "2GB"
     ```

   - Avoid adding arbitrary config maps or overrides not documented by Percona.

3. **Adjust resources if OOMKilled**:

   ```yaml
   spec:
     pgPrimary:
       resources:
         requests:
           cpu: "500m"
           memory: "2Gi"
         limits:
           cpu: "2"
           memory: "4Gi"
   ```

   Apply and watch:

   ```bash
   kubectl -n "$NAMESPACE" apply -f <perconapgcluster-yaml>.yaml
   kubectl -n "$NAMESPACE" get pods -l app.kubernetes.io/instance=pgkubcluster -w
   ```

4. **Tune probes when needed** (if Postgres is slow to start):

   - Increase `initialDelaySeconds`, `timeoutSeconds`, or `failureThreshold` under the relevant sections (`spec.pgPrimary`, `spec.pgReplicas`) in the CR.

---

## 4. Pending Pods

**Goal**: Bring pods stuck in `Pending` into `Running`.

### Quick Diagnosis

```bash
export NAMESPACE=postgres-operator

kubectl -n "$NAMESPACE" get pods
kubectl -n "$NAMESPACE" describe pod <pending-pod-name>
```

Common messages:

- `0/… nodes are available` (resource, affinity, taints issues).
- `no persistent volumes available` / `failed to provision volume` (storage issues).

### Resolution

1. **Resources (CPU/Mem)**:

   - If requests are too high, reduce them in the CR:

     ```yaml
     spec:
       pgPrimary:
         resources:
           requests:
             cpu: "500m"
             memory: "1Gi"
     ```

   - Or add/scale nodes in your node pool to match requested resources.

2. **Affinity / topology**:

   - Ensure any `affinity`, `nodeSelector`, or `topologySpreadConstraints` in the CR match actual node labels and zones.
   - Example check:

     ```bash
     kubectl get nodes --show-labels
     ```

3. **Storage**:

   - Confirm StorageClass in CR exists:

     ```bash
     kubectl get storageclass
     ```

   - Check PVCs:

     ```bash
     kubectl -n "$NAMESPACE" get pvc
     kubectl -n "$NAMESPACE" describe pvc <pvc-name>
     ```

   - Fix `spec.dataVolumeClaimSpec.storageClassName` in the CR if wrong.

---

## 5. “Missing” Pods (Less Than Expected Replicas)

**Goal**: Understand why some cluster pods are not present.

### Quick Diagnosis

```bash
export NAMESPACE=postgres-operator
export CLUSTER=pgkubcluster

kubectl -n "$NAMESPACE" get perconapgcluster.pg.percona.com "$CLUSTER" -o yaml
kubectl -n "$NAMESPACE" get pods -l app.kubernetes.io/instance="$CLUSTER" -o wide
kubectl -n "$NAMESPACE" get events --sort-by=.lastTimestamp
```

Check in the CR:

- Requested replicas under `spec.pgReplicas.instances`.
- Any status conditions under `.status.conditions`.

### Resolution

1. **Ensure requested replicas**:

   - If you expect more replicas:

     ```yaml
     spec:
       pgReplicas:
         instances: 2
     ```

   - Apply the CR and watch:

     ```bash
     kubectl -n "$NAMESPACE" apply -f <perconapgcluster-yaml>.yaml
     kubectl -n "$NAMESPACE" get pods -l app.kubernetes.io/instance="$CLUSTER" -w
     ```

2. **Check PodDisruptionBudgets and scheduling constraints** created by the operator; ensure enough nodes are available to host all replicas.

---

## 6. Schrodinger’s Deployment (CR Updated, Pods Not Matching)

**Goal**: Resolve situations where the CR was changed but the pods still look outdated or inconsistent.

### Principles

- The **operator is the source of truth**.
- Never change `StatefulSet`, `Deployment`, or ConfigMaps created by POPG directly.

### Steps

1. **Check operator logs for reconciliation errors**:

   ```bash
   export NAMESPACE=postgres-operator

   kubectl -n "$NAMESPACE" logs deploy/percona-postgresql-operator --tail=200
   ```

2. **Inspect CR status**:

   ```bash
   export CLUSTER=pgkubcluster
   kubectl -n "$NAMESPACE" get perconapgcluster.pg.percona.com "$CLUSTER" -o yaml
   ```

   Look for conditions like `Error`, `Failed`, or messages about invalid fields.

3. **Fix invalid spec fields in CR** and re-`apply`. Avoid direct edits to child resources.

---

## 7. CreateContainerError

**Goal**: Fix pods stuck in `CreateContainerError` or `CreateContainerConfigError`.

### Quick Diagnosis

```bash
export NAMESPACE=postgres-operator

kubectl -n "$NAMESPACE" describe pod <pod-name>
```

Look for:

- `MountVolume.SetUp failed`
- `Error: secret "…" not found`
- Command/args issues.

### Resolution

1. **Secrets and ConfigMaps**:

   - Check that all referenced Secrets and ConfigMaps exist:

     ```bash
     kubectl -n "$NAMESPACE" get secret
     kubectl -n "$NAMESPACE" get configmap
     ```

   - Ensure any secret names in `PerconaPGCluster.spec.secretsName`, `spec.users`, `spec.backup`, etc. are correct.

2. **Volumes / PVCs**:

   - Inspect PVCs for the failing pod:

     ```bash
     kubectl -n "$NAMESPACE" get pvc
     kubectl -n "$NAMESPACE" describe pvc <pvc-name>
     ```

3. **Do not override container command/args** unless explicitly supported by the operator.

4. **Update CR**, then delete the failing pod to let the operator recreate it:

   ```bash
   kubectl -n "$NAMESPACE" delete pod <pod-name>
   ```

---

## 8. Config “Out of Date”

**Goal**: Ensure configuration changes are safely applied to running pods.

### Rules

- **All configuration goes through the `PerconaPGCluster` CR**.
- Do **not** manually edit operator-managed ConfigMaps/Secrets.

### Steps

1. **Edit the CR**:

   ```bash
   export NAMESPACE=postgres-operator
   export CLUSTER=pgkubcluster

   kubectl -n "$NAMESPACE" edit perconapgcluster.pg.percona.com "$CLUSTER"
   ```

2. Update appropriate sections (examples):

   ```yaml
   spec:
     patroni:
       pgParameters:
         max_connections: "200"
         shared_buffers: "2GB"
   ```

3. **Apply changes and watch operator behavior**:

   - The operator will:
     - Reload config via Patroni where possible.
     - Or perform a controlled rolling restart if required.

4. **Verify**:

   ```bash
   kubectl -n "$NAMESPACE" get pods -l app.kubernetes.io/instance="$CLUSTER" -w
   ```

   Check one of the Postgres pods:

   ```bash
   kubectl -n "$NAMESPACE" exec -it <pg-pod-name> -c postgres -- \
     psql -U postgres -d postgres -c "SHOW max_connections;"
   ```

---

## 9. Reloader (Automatic Reload/Restart)

**Goal**: Use the operator’s built-in mechanisms instead of external reloaders.

### Guidelines

- Do **not** attach generic reloader sidecars (e.g., Stakater Reloader) to operator-managed pods.
- Let POPG handle:
  - Patroni reloads.
  - Controlled rolling restarts.

When you need a reload:

1. Update the CR fields (e.g., `pgParameters`).
2. Let the operator reconcile; it will call Patroni appropriately.

For advanced management, use Percona-provided tooling / documentation (e.g., toolbox images and `patronictl`), not ad-hoc sidecars.

---

## 10. Endlessly Terminating Pods

**Goal**: Resolve pods stuck in `Terminating` for a long time.

### Diagnosis

```bash
export NAMESPACE=postgres-operator

kubectl -n "$NAMESPACE" get pods
kubectl -n "$NAMESPACE" describe pod <terminating-pod-name>
```

Check for:

- Very long `terminationGracePeriodSeconds`.
- preStop hooks doing heavy work.
- Volumes taking long to unmount/detach.

### Resolution

1. **Keep lifecycle hooks minimal**:

   - Use POPG’s built-in backup and HA capabilities.
   - Do not add heavy backup logic to preStop; move it to dedicated Jobs/CronJobs.

2. **Graceful Postgres shutdown**:

   - Ensure `terminationGracePeriodSeconds` is large enough for clean shutdown (often 120–300 seconds for busy clusters).
   - Adjust this only via CR if supported; do not patch pods directly.

3. **Storage issues**:

   - If storage detach is slow or stuck, inspect CSI controller and cloud provider logs.
   - Fix volume issues at the storage layer instead of force-deleting pods in production, unless absolutely necessary.

---

## 11. Field Immutability

**Goal**: Handle `field is immutable` errors safely.

Typical immutable fields:

- `spec.volumeClaimTemplates`
- Certain Service fields (selector, clusterIP, etc.)
- StatefulSet `serviceName`

### Best Practice

1. **Do not edit StatefulSets or Services directly** for immutable changes.
2. For changes unsupported by the CR:
   - Create a **new PerconaPGCluster** with the desired spec.
   - Migrate data using:
     - Percona backup/restore.
     - `pg_basebackup`.
     - Logical replication.

Only use forced edits or manual object recreation when you have a tested, documented migration path and backups.

---

## 12. Enable Service Links

**Goal**: Control environment variables automatically injected from Services.

For security and predictability:

- Prefer **`enableServiceLinks: false`** at the namespace or pod template level.
- Use DNS (`<service>.<namespace>.svc.cluster.local`) rather than service env vars.

Check your namespace default and pod templates if you suspect leakage of service information through environment variables.

---

## 13. Secrets Exposure (“Interns Can See Your Secrets”)

**Goal**: Prevent accidental exposure of PostgreSQL credentials.

### Guidelines

1. **Use Kubernetes Secrets** for credentials, referenced from the CR:

   - `spec.users`
   - `spec.secretsName`
   - Backup-related secrets.

2. **Avoid putting passwords in CRs or ConfigMaps**.
3. **RBAC**:

   - Restrict `get/list/watch secrets` to only necessary service accounts and admins.
   - Avoid giving developers broad access to `secrets` in `postgres-operator`.

4. **Application consumption**:

   - Prefer reading DB credentials from Secrets or external secret stores.
   - Avoid logging full connection strings or passwords.

---

## 14. RBAC Problems

**Goal**: Fix `Forbidden`/`cannot get/create` errors for the operator or application service accounts.

### Operator RBAC

1. **Check operator logs**:

   ```bash
   export NAMESPACE=postgres-operator

   kubectl -n "$NAMESPACE" logs deploy/percona-postgresql-operator --tail=200
   ```

   Look for `Forbidden` errors showing missing verbs/resources.

2. **Use upstream RBAC manifests**:

   - Re-apply the official Percona RBAC YAMLs for the operator version you are running.
   - Avoid granting wildcard `*` permissions unless strictly necessary.

### Application RBAC

1. Ensure app service accounts:

   - Only need access to Services/Endpoints and possibly config for discovery.
   - Do **not** require CRUD on CRDs or Secrets in most cases.

2. Tighten ClusterRoles/RoleBindings if they are too broad.

---

## 15. Port Mania (Service / Container Port Mismatches)

**Goal**: Fix connectivity issues caused by inconsistent port configuration.

### Checks

```bash
export NAMESPACE=postgres-operator

kubectl -n "$NAMESPACE" get svc
kubectl -n "$NAMESPACE" describe svc <service-name>
```

Ensure:

- `port` / `targetPort` on Service match the Postgres/pgBouncer container ports.
- NetworkPolicies (if any) allow traffic to the correct port.

### Best Practice

1. Use **proxy services** (pgBouncer/HAProxy) provided by POPG as the main client entry point.
2. Avoid `hostPort` unless absolutely required; prefer:

   - ClusterIP for in-cluster access.
   - LoadBalancer or dedicated TCP Ingress for external access, following Percona docs.

---

## 16. Unreachable Pods & NetworkPolicies

**Goal**: Fix application connectivity issues caused by NetworkPolicies, without creating “leaky” policies.

### Diagnosis

1. Deploy a debug pod in the same namespace:

   ```bash
   export NAMESPACE=postgres-operator

   kubectl -n "$NAMESPACE" run net-debug --rm -it --image=bitnami/pgpool --restart=Never -- bash
   ```

2. Inside the pod, test connectivity:

   ```bash
   psql "host=<db-service-name> port=5432 user=<user> dbname=<db>"
   ```

3. If this works but the application cannot connect, the issue is likely cross-namespace NetworkPolicies.

### Resolution

1. Review policies:

   ```bash
   kubectl -n "$NAMESPACE" get networkpolicy
   kubectl -n "$NAMESPACE" describe networkpolicy <policy-name>
   ```

2. Ensure:

   - There is a baseline **default deny** policy for ingress/egress in the DB namespace.
   - Specific **allow** policies exist for:
     - Application namespaces (ingress to TCP/5432 on the proxy service).
     - Monitoring / backup namespaces (as needed).
     - DNS (egress to CoreDNS).

3. Adjust selectors carefully using consistent labels (e.g., `role=db`, `app=pgkubcluster`).

---

## 17. Troubleshooting Ingress (UIs / APIs, Not Direct DB Access)

**Goal**: Fix issues accessing HTTP-based dashboards or admin UIs (e.g., PMM, operator dashboards).

> Note: PostgreSQL itself is **TCP**, not HTTP; Ingress is generally **not** used directly for the DB port.

### Steps

1. Inspect Ingress:

   ```bash
   export NAMESPACE=postgres-operator

   kubectl -n "$NAMESPACE" get ingress
   kubectl -n "$NAMESPACE" describe ingress <ingress-name>
   ```

2. Verify:

   - DNS `A`/`CNAME` record matches the Ingress host.
   - Backend service name/port exist and are correct.
   - TLS secrets (if used) exist and are referenced properly.

3. Check Ingress controller logs (e.g., nginx, Traefik) for routing or TLS issues.

---

## 18. Multi-Attach Volume Errors

**Goal**: Resolve storage issues when volumes appear attached to multiple nodes.

### Concepts

- Each Postgres pod in POPG has its **own PVC** (RWO).
- A single PVC must **not** be mounted by more than one pod at a time.

### Diagnosis

```bash
export NAMESPACE=postgres-operator

kubectl -n "$NAMESPACE" get pvc
kubectl -n "$NAMESPACE" describe pvc <pvc-name>
kubectl -n "$NAMESPACE" describe pod <pod-name>
```

Look for:

- `Multi-Attach error for volume "…"` in events.

### Resolution

1. **Do not manually mount the same PVC to multiple pods**.
2. If a node went down and the volume is still “attached”:

   - Wait for the CSI driver to handle detach.
   - If necessary, use the cloud provider console/CLI to **force detach** from the old node, then let Kubernetes re-attach.

3. For persistent attach/detach issues:

   - Check CSI controller logs.
   - Consider cordoning/draining problematic nodes and recreating them.

4. For suspected data corruption or complex storage errors:

   - Follow Percona’s documented recovery path:
     - Restore from backup (pgBackRest/Percona tools).
     - Use `pg_rewind` where appropriate.
   - Avoid ad-hoc copying or reusing the same PVC across different pods/clusters.

---

## 19. Final Notes

- **Always use the `PerconaPGCluster` CR (`pgkubcluster`) as the source of truth.**
- Avoid manual patches to StatefulSets, Deployments, or ConfigMaps created by the operator.
- Test changes in a **non-production environment** first, then roll to production via GitOps/CI/CD.

This runbook is designed to be copy-paste friendly. Adjust `NAMESPACE`, `CLUSTER`, and object names as needed for your environment.


# Install PostgreSQL + pgvector + pg_textsearch on Cloudeka Kubernetes

These manifests deploy a single-node PostgreSQL 17 onto Cloudeka's managed
Kubernetes (Deka) with two extensions:

- [`pgvector`](https://github.com/pgvector/pgvector) — vector similarity search (dense retrieval).
- [`pg_textsearch`](https://github.com/timescale/pg_textsearch) — Timescale's BM25 full-text search (keyword retrieval).

Together they support **hybrid RAG** (dense + keyword) in the Standard RAG notebooks.

Because `pg_textsearch` has **no prebuilt image** and must be compiled from source
(and it requires **PostgreSQL 17/18**), we build a custom image from
`pgvector/pgvector:pg17` plus `pg_textsearch` — see the `Dockerfile` and step 1.

Everything is deployed into the **default** namespace.

## Quick start

`install.sh` lists every command in order (build + push + apply + verify + port-forward).
First edit the registry/image name (in the commands and in `04-deployment.yaml`) and set
your password in `01-secret.yaml`, then run the commands:

```bash
bash install.sh
```

## Files

| File | What it creates |
|------|-----------------|
| `install.sh` | runs every step below (build + push + apply + verify) |
| `Dockerfile` | custom image: Postgres 17 + pgvector + pg_textsearch |
| `01-secret.yaml` | DB user / password / database name — **edit before applying** |
| `02-configmap-init.yaml` | `init.sql` that creates the `vector` and `pg_textsearch` extensions on first boot |
| `03-pvc.yaml` | 10Gi PersistentVolumeClaim for the database files |
| `04-deployment.yaml` | the Postgres pod (custom image + `shared_preload_libraries=pg_textsearch`) |
| `05-service.yaml` | in-cluster ClusterIP service on port 5432 |
| `06-service-loadbalancer.yaml` | OPTIONAL external access via a Cloudeka load balancer |

## Prerequisites

Instructions assume **Ubuntu**.

- `kubectl`, configured to talk to your Cloudeka (Deka) cluster. Install:
  ```bash
  sudo snap install kubectl --classic
  ```
  `kubectl config current-context` should then show your cluster.
- `docker`, plus access to a container registry the cluster can pull from
  (e.g. a Cloudeka Deka Registry / Harbor project). Install:
  ```bash
  sudo apt-get update && sudo apt-get install -y docker.io
  sudo usermod -aG docker "$USER"   # then log out and back in
  ```
- A StorageClass available. List them and pick one if needed:
  ```bash
  kubectl get storageclass
  ```
  If your cluster has no default StorageClass, set `storageClassName` in `03-pvc.yaml`.

## 1. Build and push the image

`pg_textsearch` is compiled into the image by the `Dockerfile`. Build it and push
to a registry your cluster can reach, then set that image name in `04-deployment.yaml`.

```bash
# from this folder
docker build -t <registry>/pgvector-textsearch:pg17 .
docker push  <registry>/pgvector-textsearch:pg17
```

Edit `04-deployment.yaml` and replace the placeholder
`your-registry.example.com/pgvector-textsearch:pg17` with your image name.

> `pg_textsearch` is loaded at server start via
> `args: ["postgres", "-c", "shared_preload_libraries=pg_textsearch"]` in the
> deployment; without that preload, `CREATE EXTENSION pg_textsearch` fails.

## 2. Set your password

Edit `01-secret.yaml` and change at least `POSTGRES_PASSWORD` (and optionally the
user and database name). These values are read by the RAG notebooks later.

## 3. Deploy

Apply everything except the optional load balancer (files are numbered so they
apply in order):

```bash
kubectl apply -f 01-secret.yaml
kubectl apply -f 02-configmap-init.yaml
kubectl apply -f 03-pvc.yaml
kubectl apply -f 04-deployment.yaml
kubectl apply -f 05-service.yaml
```

Or all at once (this also applies the LoadBalancer — skip it if you do not want one):

```bash
kubectl apply -f .
```

## 4. Wait until it is ready

```bash
kubectl rollout status deployment/pgvector
kubectl get pods -l app=pgvector
```

## 5. Verify the extensions are installed

```bash
kubectl exec deploy/pgvector -- \
  psql -U raguser -d ragdb -c \
  "SELECT extname, extversion FROM pg_extension WHERE extname IN ('vector','pg_textsearch');"
```

You should see a row for both `vector` and `pg_textsearch`. If you changed the
user/db in the secret, use those names instead of `raguser` / `ragdb`.

## 6. Connect from the notebooks

### Option A — from inside the cluster (recommended)

The RAG notebooks run inside the same cluster, so they reach the database at the
**service DNS name** `pgvector` on port 5432 — no port-forward needed. In the same
`default` namespace the short name works; from another namespace use the full name:

```
postgresql+psycopg://raguser:<your-password>@pgvector:5432/ragdb
postgresql+psycopg://raguser:<your-password>@pgvector.default.svc.cluster.local:5432/ragdb
```

### Option B — port-forward (for connecting from your laptop)

Run this in a separate terminal and leave it open, then connect to `localhost:5432`:

```bash
kubectl port-forward svc/pgvector 5432:5432
```

```
postgresql+psycopg://raguser:<your-password>@localhost:5432/ragdb
```

### Option C — external LoadBalancer IP (only if you applied `06-service-loadbalancer.yaml`)

```bash
kubectl get svc pgvector-lb -w   # wait for EXTERNAL-IP
```

Then connect to `<EXTERNAL-IP>:5432`. Only do this with a strong password and,
ideally, `loadBalancerSourceRanges` set in the manifest.

## Cleanup

```bash
kubectl delete -f .
# This also deletes the PVC and your data. To keep the data, delete the other
# resources individually and leave 03-pvc.yaml in place.
```

## Notes

- **Data persistence**: database files live on the PVC, so pod restarts keep your
  data. Deleting the PVC deletes the data.
- **`init.sql` runs only once**, on the very first boot with an empty data
  directory. If you need the extensions in a database created later, run
  `CREATE EXTENSION IF NOT EXISTS vector;` and
  `CREATE EXTENSION IF NOT EXISTS pg_textsearch;` in that database manually.
- **PostgreSQL version**: this uses Postgres 17 because `pg_textsearch` requires
  17 or 18. Do not point the deployment at an older `pgvector/pgvector:pg16`
  image — `pg_textsearch` will not load.
- **`shared_preload_libraries`**: changing it requires a server restart, which the
  deployment does at startup. If you add more preload libraries later, keep
  `pg_textsearch` in the list.
- This is a single-replica setup meant for training/development, not a
  highly-available production database.

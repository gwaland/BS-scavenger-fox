# BS-scavenger-fox

GitOps deployment repo for `scavenger-fox` on k3s via Helm and Argo CD.

## What is here

- `chart/`: Helm chart for the Fox Central Command application
- `fcc-postgres/`: Helm chart for the dedicated in-cluster Fox Central Command PostgreSQL instance
- `argo/fcc-postgres-app.yaml`: Argo CD `Application` manifest for the PostgreSQL infra app
- `argo/scavenger-fox-app.yaml`: Argo CD `Application` manifest for the Fox Central Command app

## Current assumptions

- This repo deploys the backend app `apps/fox-central-command` from the main `scavenger-fox` source repo.
- Fox Finder mobile builds are handled separately and are not deployed by this chart.
- PostgreSQL is treated as dedicated infrastructure for Fox Central Command and is deployed separately from the app chart.
- Asset uploads are stored on a PVC for now.
- The backend image is expected at `ghcr.io/gwaland/fox-central-command-backend`.
- The backend image tag remains configurable in `chart/values.yaml`.
- App repo CI publishes immutable commit-SHA image tags; the deploy repo should be bumped to one of those immutable tags rather than relying on `latest`.
- Public ingress hostname is `fcc.bluestripes.net`.
- The ingress TLS secret reference is `fcc-bluestripes-net-tls`.
- Seed data is disabled by default via `seed.enabled=false`; enable it explicitly if a fresh install needs the demo seed.
- App tokens are consumed from a pre-created Kubernetes Secret by default.

## Public edge behavior

- `fcc.bluestripes.net` also requires a matching Cloudflare Tunnel hostname entry in `/home/gwaland/git-k3s/argo-lab-config.git/applications/networking/cloudflare-tunnel/cloudflare-tunnel-config.yaml`.
- Merging the tunnel-config PR updates the live ConfigMap through Argo CD, but the `cloudflared` pods may still need a rollout restart before the hostname begins serving externally.
- The best external smoke test for this backend is `https://fcc.bluestripes.net/health`.
- `https://fcc.bluestripes.net/` returning `404` is expected for the current backend-only deployment and does not indicate an ingress or Cloudflare failure.

## Seed behavior

- `seed.enabled` defaults to `false`.
- The seed job runs as a Helm `post-install` hook only.
- It does not run on upgrade.
- The app seed path is assumed to be idempotent so reruns do not duplicate or clobber data.

## Database behavior

- The app chart expects a pre-created database connection secret:

```yaml
database:
  existingSecret: fcc-database
  urlKey: DATABASE_URL
```

- The app chart fails clearly unless `database.existingSecret` and `database.urlKey` are set.
- The dedicated PostgreSQL instance lives in its own chart and Argo app, with PVC-backed storage.
- The default database details for that instance are:
  - service: `fcc-postgres.scavenger-fox.svc.cluster.local`
  - database: `fox_central_command`
  - app user: `fcc_app`
- The app network policy expects PostgreSQL pods labeled as:
  - `app.kubernetes.io/name=fcc-postgres`
  - `app.kubernetes.io/instance=fcc-postgres`

## PostgreSQL infra behavior

- `fcc-postgres/` deploys a dedicated single-instance PostgreSQL `StatefulSet` with a PVC.
- The chart expects a pre-created auth secret:

```yaml
auth:
  existingSecret: fcc-postgres-auth
  passwordKey: POSTGRES_PASSWORD
  username: fcc_app
  database: fox_central_command
```

- The PostgreSQL chart fails clearly unless `auth.existingSecret` and `auth.passwordKey` are set.
- On first boot, the official PostgreSQL image creates the `fox_central_command` database and the `fcc_app` role using those settings.
- One way to create the secret for the POC is:

```sh
kubectl -n scavenger-fox create secret generic fcc-postgres-auth \
  --from-literal=POSTGRES_PASSWORD='replace-me-postgres-password'
```

- After that secret exists, create the app connection secret in the same namespace:

```sh
kubectl -n scavenger-fox create secret generic fcc-database \
  --from-literal=DATABASE_URL='postgresql://fcc_app:replace-me-postgres-password@fcc-postgres.scavenger-fox.svc.cluster.local:5432/fox_central_command'
```

- If the database password contains reserved URL characters such as `/`, `@`, or `:`, URL-encode the password segment before storing `DATABASE_URL`.

## App secret behavior

- The chart expects a pre-created application secret by default:

```yaml
secrets:
  existingSecret: fcc-app-secrets
  photoReviewTokenKey: PHOTO_REVIEW_TOKEN
  adminApiTokenKey: ADMIN_API_TOKEN
```

- `PHOTO_REVIEW_TOKEN` and `ADMIN_API_TOKEN` are wired with `secretKeyRef` in the Deployment and hook Jobs.
- The chart does not store token values in `values.yaml`.
- For the POC, one way to create the secret is:

```sh
kubectl -n scavenger-fox create secret generic fcc-app-secrets \
  --from-literal=PHOTO_REVIEW_TOKEN='replace-me-photo-review-token' \
  --from-literal=ADMIN_API_TOKEN='replace-me-admin-api-token'
```

## TLS behavior

- The chart references `fcc-bluestripes-net-tls` by name in the Ingress.
- The chart does not generate TLS certificate material.
- `cert-manager` or a pre-created Secret is expected to populate that Secret.

## Apply through Argo CD

```sh
kubectl apply -f argo/fcc-postgres-app.yaml
kubectl apply -f argo/scavenger-fox-app.yaml
```

- Apply the PostgreSQL app first.
- Wait for `fcc-postgres` to become healthy and for the PVC to bind.
- Then apply the Fox Central Command app.

## CI

- `.github/workflows/helm-chart.yml` runs Helm checks on pushes and PRs.
- It lints both charts, renders both charts, and verifies both fail cleanly when their required secret references are missing.

## Image update behavior

- `scavenger-fox` publishes `ghcr.io/gwaland/fox-central-command-backend` as `latest` and as the source commit SHA after `CI` succeeds on `main`.
- The publisher then opens a PR back to this repo to update `chart/values.yaml` to that immutable SHA tag.
- Argo CD only rolls the app when this repo changes; pushing a new `latest` image alone is not enough to create a GitOps diff.

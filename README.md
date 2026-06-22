# BS-scavenger-fox

GitOps deployment repo for `scavenger-fox` on k3s via Helm and Argo CD.

## What is here

- `chart/`: Helm chart for Fox Central Command, PostgreSQL, PVCs, ingress, and network policies
- `argo/scavenger-fox-app.yaml`: Argo CD `Application` manifest for this repo

## Current assumptions

- This repo deploys the backend app `apps/fox-central-command` from the main `scavenger-fox` source repo.
- Fox Finder mobile builds are handled separately and are not deployed by this chart.
- PostgreSQL is treated as external/shared infrastructure by default.
- Asset uploads are stored on a PVC for now.
- The backend image is expected at `ghcr.io/gwaland/fox-central-command-backend`.
- The backend image tag remains configurable in `chart/values.yaml` and currently defaults to `latest`.
- Public ingress hostname is `fcc.bluestripes.net`.
- The ingress TLS secret reference is `fcc-bluestripes-net-tls`.
- Seed data is enabled by default for the POC via `seed.enabled=true` and runs only on install.
- External/shared PostgreSQL is the default POC path.
- Bundled in-cluster PostgreSQL remains available as an optional dev/demo mode.
- App tokens are consumed from a pre-created Kubernetes Secret by default.

## Before live deployment

- Tighten external database network policy egress once the shared PostgreSQL address range is pinned down.

## Seed behavior

- `seed.enabled` defaults to `true` for the POC.
- The seed job runs as a Helm `post-install` hook only.
- It does not run on upgrade.
- The app seed path is assumed to be idempotent so reruns do not duplicate or clobber data.

## Database behavior

- `postgresql.enabled=false` by default, so the chart expects a shared PostgreSQL instance.
- The preferred external secret shape is:

```yaml
database:
  existingSecret: fcc-database
  urlKey: DATABASE_URL
```

- When `postgresql.enabled=false`, the chart fails clearly unless `database.existingSecret` and `database.urlKey` are set.
- A dedicated Fox Central Command database and user are still expected on the shared PostgreSQL server.
- Setting `postgresql.enabled=true` switches back to the bundled in-cluster PostgreSQL path for dev/demo use.
- External PostgreSQL egress is configurable in `networkPolicy.egress.postgres`.
- The POC default is broad egress only for TCP/5432, and it should be locked down once the external PostgreSQL endpoint is known.

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
kubectl apply -f argo/scavenger-fox-app.yaml
```

## CI

- `.github/workflows/helm-chart.yml` runs Helm checks on pushes and PRs.
- It lints the chart, renders the default external-database path, renders the optional bundled-PostgreSQL path, and verifies the chart fails cleanly when required external database secret config is missing.

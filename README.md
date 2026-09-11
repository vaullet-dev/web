# web

The public site at **vaullet.dev**. One page, no framework, no build step for the
content itself — `index.html` is hand-written and ships as-is.

## How a change reaches production

```
edit index.html  →  push to main
                      │
                      ▼
        GitHub Actions: build image → ghcr.io/vaullet-dev/web:sha-xxxxxxx
                      │
                      ▼
        commit the new tag into kustomization.yaml   ← this IS the deploy
                      │
                      ▼
        Argo CD reconciles the cluster from this repo
                      │
                      ▼
        Rollout: 50% canary, then it STOPS and waits for Promote
```

**Tags are immutable.** Every build is `sha-<7 chars>`; there is no `latest` and
nothing is ever re-tagged. That is what makes `git revert` a real rollback — if a
tag's contents could change, the cluster and git could disagree while looking
identical.

The tag bump commit carries `[skip ci]`, and the workflow ignores changes to
`kustomization.yaml`, so it cannot retrigger itself.

## Promoting a deploy

A new image goes to half the replicas and then pauses. Open Argo CD at
**argo.vaullet.dev**, find the `web` Rollout, and use the resource actions:

- **promote-full** — send it to everyone
- **abort** — stop and keep the previous version serving

## The registry package must be public

GHCR packages are **private by default**. The cluster pulls anonymously, so after
the very first build:

*GitHub → your profile → Packages → `web` → Package settings → Change visibility → Public*

Without that, pods sit in `ImagePullBackOff` with `denied` in the events — the
single most common way this setup appears broken.

## Layout

| Path | What |
|---|---|
| `index.html` | the entire site |
| `favicon.svg` | tab icon |
| `nginx.conf` | server config, baked into the image |
| `Dockerfile` | nginx + two files |
| `kustomization.yaml` | **holds the deployed image tag** |
| `k8s/` | Rollout, Service, HTTPRoute, http→https redirect |

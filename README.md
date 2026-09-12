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
        Rollout: 50% of REQUESTS to the canary, then it STOPS
                 and waits for Promote
```

**Tags are immutable.** Every build is `sha-<7 chars>`; there is no `latest` and
nothing is ever re-tagged. That is what makes `git revert` a real rollback — if a
tag's contents could change, the cluster and git could disagree while looking
identical.

The tag bump commit carries `[skip ci]`, and the workflow ignores changes to
`kustomization.yaml`, so it cannot retrigger itself.

## Promoting a deploy

A new image gets **half the requests** and then pauses. Open Argo CD at
**argo.vaullet.dev**, find the `web` Rollout, and use the resource actions:

- **promote-full** — send it to everyone
- **abort** — stop and keep the previous version serving

## How the 50% is actually 50%

The split happens in Traefik, not in the replica count. `k8s/httproute.yaml`
carries two weighted backends, and Argo Rollouts' [Gateway API
plugin](https://github.com/argoproj-labs/rollouts-plugin-trafficrouter-gatewayapi)
rewrites those weights as the rollout moves:

| | `web-stable` | `web-canary` |
|---|---|---|
| at rest | 100 | 0 |
| paused at the canary step | 50 | 50 |
| after promote-full / abort | 100 | 0 |

That distinction matters. A canary with no traffic routing splits by pods, so at
`replicas: 2` every weight from 26 to 74 means exactly the same thing — one pod —
and which pod you reach depends on kube-proxy, per connection.

Two consequences worth knowing before debugging:

- **The live HTTPRoute will not match git during a rollout.** It is supposed to
  differ. The Argo CD Application ignores `.spec.rules[].backendRefs[].weight`
  and the plugin's `rollouts.argoproj.io/gatewayapi-canary` label, and syncs with
  `RespectIgnoreDifferences=true` so a sync mid-canary does not reset the split.
- **Both backendRefs must stay in one rule.** The plugin only rewrites rules that
  name both Services; split them up and the weighting silently stops happening
  while everything still looks healthy.

`web-canary` has no endpoints when nothing is rolling out — the canary ReplicaSet
is scaled to zero. That is the resting state, not a fault.

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
| `k8s/` | Rollout, stable + canary Services, weighted HTTPRoute, http→https redirect |



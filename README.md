# web

The public site at **vaullet.dev**. One page, no framework, no build step for the
content itself — `index.html` is hand-written and ships as-is.

## How a change reaches production

```
pull request  →  commit messages and title checked, image built but not pushed
                      │
                      ▼
merge to master  →  version worked out from the commit messages
                      │
                      ▼
        GitHub Actions: image → ghcr.io/vaullet-dev/web:X.Y.Z,
        git tag vX.Y.Z, GitHub release
                      │
                      ▼
        CI opens a pull request changing the tag in kustomization.yaml
                      │
                      ▼
        merge it  ← this IS the deploy
                      │
                      ▼
        Argo CD syncs, the Rollout starts new pods, and once they are all
        Ready every request switches to them at once
```

**Tags are immutable.** Every release is `X.Y.Z`. There is no `latest` and
nothing is ever re-tagged, which is what makes `git revert` a real rollback.

## Versions come from commit messages

The same rules as backend-common and wallet-ledger-service, from the same
`scripts/version.sh`:

| Commit | Release |
|---|---|
| `feat!: ...`, `breaking: ...`, or a `BREAKING CHANGE:` footer | major |
| `feat: ...` / `feature: ...` | minor |
| `fix: ...`, `patch:`, `perf:`, `refactor:`, `revert:`, `build:`, `deps:`, `security:` | patch |
| `chore:`, `docs:`, `test:`, `ci:`, `style:`, `deploy:` | nothing, and no deploy |

The level is the highest one since the last `v*` tag, so three fixes are one
patch release. A pull request fails if a commit or its title does not follow
this. Run `scripts/version.sh explain` to see what a branch would become.

The workflow ignores changes to `kustomization.yaml`, so merging a deploy PR
does not trigger another build.

## Blue-green, not canary

Every visitor sees the same version, including during a deploy.

1. A new tag starts a second set of pods (the same `replicas: 2`) next to the
   running ones. They get no traffic yet.
2. When all of them are Ready, Argo Rollouts points the `web` Service at them.
   Traefik follows the Service, so every request goes to the new version from that moment on.
3. The old pods are removed 30 seconds later.

There is nothing to promote. If the new pods never become Ready, the Service
never switches and the old version keeps serving. The Rollout shows Degraded in
Argo CD, and the fix is a new commit or `git revert`.

This replaced a 50% canary that paused for a manual Promote. A canary always
serves two versions at once, and a paused one does so indefinitely, which is
exactly how the site ended up serving old and new content from different pods.

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
| `favicon.svg` | tab icon, from `brand/` |
| `apple-touch-icon.png` | home-screen icon on iOS, 180×180, from `brand/` |
| `nginx.conf` | server config, baked into the image |
| `Dockerfile` | nginx + two files |
| `kustomization.yaml` | **holds the deployed image tag** |
| `k8s/` | blue-green Rollout, the `web` Service, HTTPRoute, http→https redirect |



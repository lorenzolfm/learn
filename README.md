# learn

Source for [learn.lorenzo.sh](https://learn.lorenzo.sh) — a log of things I have
taught myself, written up as an [mdBook](https://rust-lang.github.io/mdBook/).

## Writing

```sh
direnv allow        # or: nix develop
mdbook serve --open # live reload at http://localhost:3000
```

Add a page by creating the Markdown file under `src/` and listing it in
`src/SUMMARY.md`. Pages that are not in `SUMMARY.md` are not built.

`flake.lock` pins the mdBook version, and CI builds with `nix develop -c mdbook
build` against that same lock, so the deployed site matches local preview.

## Deploying

Pushing to `main` builds the book, bakes it into an nginx image, and updates the
image tag in [lorenzolfm/homelab](https://github.com/lorenzolfm/homelab), which
ArgoCD reconciles onto the cluster. The full pipeline is documented in
[How this site is built](src/systems/how-this-site-is-built.md).

## First deploy

Two steps cannot be done from a repo, and nothing works until both are:

1. **Add the three secrets** to this repo (Settings → Secrets and variables →
   Actions), or promote them to user-level secrets once so future repos inherit
   them:
   - `DOCKERHUB_USERNAME`
   - `DOCKERHUB_TOKEN` — needs write scope; it creates `lorenzolfm/learn` on
     first push
   - `HOMELAB_REPO_TOKEN` — needs write access to `lorenzolfm/homelab`

2. **Add the tunnel route** in the Cloudflare dashboard: public hostname
   `learn.lorenzo.sh` → `http://learn:8080`. The tunnel is token-managed, so
   this route lives in the dashboard and not in the homelab repo — GitOps will
   never reproduce it.

Order matters. The homelab manifests ship with a placeholder image tag, so the
pod stays in `ImagePullBackOff` until the first successful run of this
workflow pushes an image. Merge the homelab PR, add the secrets, then re-run
this workflow.

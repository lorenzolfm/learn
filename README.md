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

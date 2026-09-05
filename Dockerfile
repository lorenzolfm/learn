# The book is built in CI (native x86) and only copied in here, so this image
# builds for arm64 under emulation without running any build tool. See
# src/systems/how-this-site-is-built.md.
FROM nginxinc/nginx-unprivileged:1.29-alpine
COPY --chown=101:101 nginx-default.conf /etc/nginx/conf.d/default.conf
COPY --chown=101:101 book/ /usr/share/nginx/html/

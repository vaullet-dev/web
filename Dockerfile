# A static site needs no build stage — copy the page and its icons into nginx and stop.
FROM nginx:1.27-alpine

# The pod runs as uid 101 with a read-only root filesystem, so nginx cannot
# write its own pid file or caches; the Rollout mounts emptyDirs at
# /var/cache/nginx and /var/run for exactly that reason.
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY index.html favicon.svg apple-touch-icon.png /usr/share/nginx/html/

EXPOSE 8080

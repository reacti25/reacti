# syntax=docker/dockerfile:1
# Reacti backend image. One image, four roles: the default command runs
# nginx + php-fpm (web); `reacti reverb|worker|scheduler|migrate|dbload`
# runs the others (see docker/bin/reacti). Built for amd64 and arm64 by
# .github/workflows/container-ci.yml.

# ---- 1. Vite assets (admin dashboard CSS/JS) --------------------------------
FROM node:22-bookworm-slim AS assets
WORKDIR /app
COPY package.json package-lock.json vite.config.js postcss.config.js tailwind.config.js ./
# npm install, not ci: the committed lock omits the Node 22 resolutions of two
# optional native deps (same reason as the deploy workflows).
RUN npm install --no-audit --no-fund --no-progress
COPY resources ./resources
RUN mkdir -p public && npm run build

# ---- 2. Composer dependencies -------------------------------------------------
FROM composer:2.8 AS vendor
WORKDIR /app
COPY composer.json composer.lock ./
# Platform reqs (gd, intl) live in the final image, not in composer's.
RUN composer install --no-dev --prefer-dist --no-progress --no-interaction \
    --no-scripts --no-autoloader --ignore-platform-reqs
COPY . .
RUN composer dump-autoload --no-dev --optimize --classmap-authoritative --no-scripts

# ---- 3. Runtime ---------------------------------------------------------------
# PHP 8.4 to match the Hostinger VPS (CI also tests 8.3). nginx + php-fpm under
# s6, unprivileged www-data, HTTP on 8080, nginx healthcheck at /healthcheck.
FROM serversideup/php:8.4-fpm-nginx AS app

USER root
RUN install-php-extensions gd intl bcmath exif \
    && apt-get update \
    && apt-get install -y --no-install-recommends default-mysql-client \
    && rm -rf /var/lib/apt/lists/*
# RDS TLS trust bundle for PDO (MYSQL_ATTR_SSL_CA) and the dbload command.
RUN mkdir -p /etc/ssl/rds \
    && curl -fsSL https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem -o /etc/ssl/rds/global-bundle.pem \
    && chmod 644 /etc/ssl/rds/global-bundle.pem \
    && test -s /etc/ssl/rds/global-bundle.pem
COPY --chmod=755 docker/bin/reacti /usr/local/bin/reacti

# Production PHP/nginx values. Upload ceiling matches today's nginx (64M) with
# headroom for 60 MB reaction videos.
ENV PHP_OPCACHE_ENABLE=1 \
    PHP_MEMORY_LIMIT=512M \
    PHP_MAX_EXECUTION_TIME=120 \
    PHP_UPLOAD_MAX_FILE_SIZE=128M \
    PHP_POST_MAX_SIZE=128M \
    NGINX_CLIENT_MAX_BODY_SIZE=128M \
    SHOW_WELCOME_MESSAGE=false \
    # Cache config/views/events from the task's environment at start, for
    # every role. No migrations here (own one-off task), no route cache
    # (routes use closures), no storage:link (media is S3 or public/uploads).
    AUTORUN_ENABLED=true \
    AUTORUN_LARAVEL_OPTIMIZE=false \
    AUTORUN_LARAVEL_CONFIG_CACHE=true \
    AUTORUN_LARAVEL_EVENT_CACHE=true \
    AUTORUN_LARAVEL_VIEW_CACHE=true \
    AUTORUN_LARAVEL_ROUTE_CACHE=false \
    AUTORUN_LARAVEL_MIGRATION=false \
    AUTORUN_LARAVEL_STORAGE_LINK=false

WORKDIR /var/www/html
COPY --chown=www-data:www-data --from=vendor /app /var/www/html
COPY --chown=www-data:www-data --from=assets /app/public/build /var/www/html/public/build
# Writable runtime dirs that git does not track.
RUN mkdir -p storage/framework/cache/data storage/framework/sessions storage/framework/views storage/logs bootstrap/cache \
    && chown -R www-data:www-data storage bootstrap/cache

USER www-data
RUN php artisan package:discover --ansi

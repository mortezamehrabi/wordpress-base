# syntax=docker/dockerfile:1

FROM wordpress:php8.3-apache

ARG TARGETARCH

LABEL maintainer="Morteza Mehrabi <hello@morteza.cloud>" \
      org.opencontainers.image.title="WordPress PHP 8.3 Production Image" \
      org.opencontainers.image.description="Production-optimized WordPress Docker image for Coolify deployments. Includes ionCube, Redis, Imagick, Composer, WP-CLI, and tuned PHP/OPcache/Apache configuration." \
      org.opencontainers.image.source="https://github.com/mortezamehrabi/wordpress-base" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.vendor="Morteza Mehrabi"

# ── PHP Extensions + ionCube + Build Tools ──────────────────────────
# Single RUN layer: install deps, build extensions, install ionCube, purge build deps
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        $PHPIZE_DEPS \
        libmagickwand-dev \
        unzip \
        curl; \
    \
    # ── Install PHP extensions not in base image ──
    docker-php-ext-install -j "$(nproc)" \
        soap; \
    \
    # ── Install Redis via PECL ──
    pecl install redis; \
    docker-php-ext-enable redis; \
    \
    # ── Enable Imagick (pre-installed in base image) ──
    docker-php-ext-enable imagick; \
    \
    # ── Install ionCube Loader ──
    mkdir -p /usr/local/ioncube; \
    IONCUBE_ARCH="x86-64"; \
    if [ "${TARGETARCH:-}" = "arm64" ]; then \
        IONCUBE_ARCH="aarch64"; \
    fi; \
    IONCUBE_URL="https://downloads.ioncube.com/loader_downloads/ioncube_loaders_lin_${IONCUBE_ARCH}.tar.gz"; \
    IONCUBE_SO="ioncube_loader_lin_8.3.so"; \
    curl -fsSL "$IONCUBE_URL" -o /tmp/ioncube.tar.gz; \
    tar xzf /tmp/ioncube.tar.gz -C /usr/local/ioncube --strip-components=1; \
    PHP_EXT_DIR="$(php -r 'echo ini_get("extension_dir");')"; \
    cp "/usr/local/ioncube/${IONCUBE_SO}" "${PHP_EXT_DIR}/"; \
    docker-php-ext-enable "$IONCUBE_SO"; \
    \
    # ── Purge build-only packages (no --auto-remove to preserve runtime libs) ──
    apt-get purge -y $PHPIZE_DEPS libmagickwand-dev; \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/local/ioncube; \
    pecl clear-cache

# ── Composer (multi-arch, from official image) ─────────────────────
COPY --from=composer:2 /usr/bin/composer /usr/local/bin/composer

# ── WP-CLI ──────────────────────────────────────────────────────────
RUN set -eux; \
    curl -fsSL https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar -o /usr/local/bin/wp; \
    chmod +x /usr/local/bin/wp; \
    wp --version

# ── PHP Configuration ──────────────────────────────────────────────
COPY config/php.ini       /usr/local/etc/php/conf.d/zz-custom.ini
COPY config/opcache.ini   /usr/local/etc/php/conf.d/zz-opcache.ini

# ── Apache Configuration ───────────────────────────────────────────
RUN set -eux; \
    a2enmod rewrite headers expires; \
    sed -i 's/AllowOverride None/AllowOverride All/g' /etc/apache2/apache2.conf

# ── Verify extension loading ───────────────────────────────────────
RUN set -eux; \
    php -m | grep -iE '(redis|imagick|ioncube|bcmath|soap)'; \
    composer --version; \
    wp --version

# ── Healthcheck ─────────────────────────────────────────────────────
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -fsS http://localhost/wp-admin/images/wordpress-logo.svg || exit 1

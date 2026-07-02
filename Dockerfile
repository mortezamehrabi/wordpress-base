# syntax=docker/dockerfile:1

FROM wordpress:php8.3-apache

LABEL maintainer="Morteza Mehrabi <hello@morteza.cloud>" \
      org.opencontainers.image.title="WordPress PHP 8.3 Production Image" \
      org.opencontainers.image.description="Production-optimized WordPress Docker image for Coolify deployments. Includes ionCube, Redis, Imagick, Composer, WP-CLI, and tuned PHP/OPcache/Apache configuration." \
      org.opencontainers.image.source="https://github.com/mortezamehrabi/wordpress-base" \
      org.opencontainers.image.licenses="MIT"

ENV COMPOSER_ALLOW_SUPERUSER=1

# ── Install build dependencies ──────────────────────────────────────
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        $PHPIZE_DEPS \
        libmagickwand-dev \
        unzip \
        curl

# ── Build and install SOAP ──────────────────────────────────────────
RUN set -eux; \
    docker-php-ext-install -j "$(nproc)" soap

# ── Build and install Redis ─────────────────────────────────────────
RUN set -eux; \
    pecl install redis; \
    docker-php-ext-enable redis

# ── Enable Imagick (pre-installed in base WordPress image) ──────────
RUN set -eux; \
    docker-php-ext-enable imagick 2>&1 || true

# ── Install ionCube Loader ──────────────────────────────────────────
# ionCube is a Zend Extension — must use zend_extension=, not extension=
RUN set -eux; \
    case "$(uname -m)" in \
        aarch64) IONCUBE_ARCH="aarch64" ;; \
        *)       IONCUBE_ARCH="x86-64" ;; \
    esac; \
    echo "Downloading ionCube for ${IONCUBE_ARCH}..."; \
    curl -fsSL \
        "https://downloads.ioncube.com/loader_downloads/ioncube_loaders_lin_${IONCUBE_ARCH}.tar.gz" \
        -o /tmp/ioncube.tar.gz; \
    mkdir -p /tmp/ioncube; \
    tar xzf /tmp/ioncube.tar.gz -C /tmp/ioncube --strip-components=1; \
    ls -la /tmp/ioncube/; \
    IONCUBE_SO="/tmp/ioncube/ioncube_loader_lin_8.3.so"; \
    if [ ! -f "$IONCUBE_SO" ]; then \
        echo "ERROR: ionCube loader for PHP 8.3 not found in archive"; \
        echo "Available files:"; \
        ls -la /tmp/ioncube/; \
        exit 1; \
    fi; \
    PHP_EXT_DIR="$(php -r 'echo ini_get("extension_dir");')"; \
    cp "$IONCUBE_SO" "${PHP_EXT_DIR}/"; \
    echo "zend_extension=${PHP_EXT_DIR}/ioncube_loader_lin_8.3.so" \
        > /usr/local/etc/php/conf.d/00-ioncube.ini; \
    rm -rf /tmp/ioncube /tmp/ioncube.tar.gz

# ── Cleanup build dependencies ──────────────────────────────────────
RUN set -eux; \
    apt-get purge -y $PHPIZE_DEPS libmagickwand-dev; \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# ── Composer ────────────────────────────────────────────────────────
COPY --from=composer:2 /usr/bin/composer /usr/local/bin/composer

# ── WP-CLI ──────────────────────────────────────────────────────────
RUN set -eux; \
    curl -fsSL https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
        -o /usr/local/bin/wp; \
    chmod +x /usr/local/bin/wp; \
    wp --version

# ── PHP Configuration ───────────────────────────────────────────────
COPY config/php.ini     /usr/local/etc/php/conf.d/zz-custom.ini
COPY config/opcache.ini /usr/local/etc/php/conf.d/zz-opcache.ini

# ── Apache ──────────────────────────────────────────────────────────
RUN set -eux; \
    a2enmod rewrite headers expires; \
    sed -i 's/AllowOverride None/AllowOverride All/g' /etc/apache2/apache2.conf

# ── Verify ──────────────────────────────────────────────────────────
RUN set -eux; \
    php -m | grep -iE '(redis|imagick|ioncube|soap)'; \
    php -v | grep -i ioncube; \
    composer --version; \
    wp --version

# ── Healthcheck ─────────────────────────────────────────────────────
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -fsS http://localhost/wp-admin/images/wordpress-logo.svg || exit 1

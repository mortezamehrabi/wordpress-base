# WordPress Base — Production Docker Image

A production-grade WordPress Docker image built for **[Coolify](https://coolify.io/)** deployments. Based on `wordpress:php8.3-apache`, this image ships with every tool and PHP extension a modern WordPress site needs — no post-deploy extension installation required.

**Image location:** `ghcr.io/mortezamehrabi/wordpress`

---

## Features

- **PHP 8.3** with hand-picked production extensions
- **ionCube Loader 13** preinstalled for protected plugins/themes
- **Redis** extension for object caching
- **Imagick** for advanced image processing
- **OPcache** tuned aggressively for production throughput
- **Composer 2** (latest stable) available globally
- **WP-CLI** (latest stable) available globally
- **Apache** with `mod_rewrite`, `mod_headers`, `mod_expires`
- **Multi-architecture** — `linux/amd64` and `linux/arm64`
- **Healthcheck** built in
- **Minimal image size** — build deps purged in the same layer

---

## Installed PHP Extensions

| Extension          | Purpose                                  |
|--------------------|------------------------------------------|
| `bcmath`           | Arbitrary-precision mathematics          |
| `exif`             | Image metadata                           |
| `gd`               | Image manipulation                       |
| `imagick`          | Advanced image processing (ImageMagick)  |
| `intl`             | Internationalization                     |
| `ionCube Loader`   | Decode ionCube-encoded PHP files         |
| `mysqli`           | MySQL improved driver                    |
| `opcache`          | PHP bytecode cache                       |
| `redis`            | Redis object cache backend               |
| `soap`             | SOAP web services                        |
| `zip`              | ZIP archive handling                     |

Extensions marked as "included in base image" (`exif`, `gd`, `intl`, `mysqli`, `opcache`, `zip`) ship with `wordpress:php8.3-apache`. This image adds `bcmath`, `soap`, `redis`, `imagick`, and `ionCube Loader` on top.

---

## Installed Tools

| Tool       | Version | Location             |
|------------|---------|----------------------|
| Composer   | latest  | `/usr/local/bin/composer` |
| WP-CLI     | latest  | `/usr/local/bin/wp`       |

---

## PHP Configuration

| Setting                  | Value   |
|--------------------------|---------|
| `memory_limit`           | 512M    |
| `upload_max_filesize`    | 512M    |
| `post_max_size`          | 512M    |
| `max_execution_time`     | 300     |
| `max_input_vars`         | 5000    |
| `display_errors`         | Off     |
| `error_reporting`        | E_ALL & ~E_DEPRECATED & ~E_STRICT |
| `date.timezone`          | UTC     |
| `expose_php`             | Off     |
| `session.cookie_httponly`| On      |
| `session.use_strict_mode`| On      |

### OPcache Configuration

| Setting                     | Value |
|-----------------------------|-------|
| `opcache.memory_consumption`| 256   |
| `opcache.interned_strings_buffer` | 16 |
| `opcache.max_accelerated_files`   | 10000 |
| `opcache.revalidate_freq`   | 2     |
| `opcache.validate_timestamps` | 1   |
| `opcache.enable_cli`        | 0     |

`validate_timestamps` is intentionally kept enabled (with a 2-second revalidation interval) as a safe default for shared WordPress hosting environments. Disable it only if your deployment process explicitly clears OPcache.

---

## Build Instructions

### Local Build

```bash
docker build -t wordpress-base .
```

### Build for a Specific Platform

```bash
docker build --platform linux/amd64 -t wordpress-base .
```

### Run Locally

```bash
docker run -d \
  --name wordpress \
  -p 8080:80 \
  -e WORDPRESS_DB_HOST=db \
  -e WORDPRESS_DB_USER=wordpress \
  -e WORDPRESS_DB_PASSWORD=password \
  -e WORDPRESS_DB_NAME=wordpress \
  wordpress-base:latest
```

### Verify Extensions

```bash
docker run --rm wordpress-base:latest php -m
docker run --rm wordpress-base:latest php -r "var_dump(extension_loaded('ionCube Loader'));"
docker run --rm wordpress-base:latest wp --version
docker run --rm wordpress-base:latest composer --version
```

---

## Image Tags

Published to `ghcr.io/mortezamehrabi/wordpress`:

| Tag              | Description                          |
|------------------|--------------------------------------|
| `latest`         | Latest build from `main` branch      |
| `8.3`            | PHP 8.3 family (always latest 8.3.x) |
| `8.3.0`, `8.3.1` | Specific PHP patch versions          |
| `main`           | Latest commit on `main` branch       |

When you push a Git tag like `8.3.0`, the workflow produces tags `8.3.0`, `8.3`, and `latest`.

---

## Use with Coolify

1. In your Coolify dashboard, go to **Server > Proxy > Docker Images**.
2. Add `ghcr.io/mortezamehrabi/wordpress:latest` as a pre-built image.
3. Deploy any WordPress application using this image as the base.

All PHP extensions and tools are immediately available — Coolify never runs `apt-get` or manual extension installs inside running containers.

---

## Versioning Strategy

This repository follows **calendar-oriented versioning** aligned with PHP 8.3 releases:

- The Dockerfile pins to `wordpress:php8.3-apache`.
- Git tags should follow the `X.Y.Z` pattern matching the WordPress/PHP base image update.
- When PHP 8.3 updates (e.g., 8.3.15 → 8.3.16), rebuild and tag `8.3.16`.

---

## How to Customize

### Override PHP Settings

Mount a custom ini file:

```bash
docker run -v ./my-php.ini:/usr/local/etc/php/conf.d/zzz-my.ini wordpress-base
```

Files in `/usr/local/etc/php/conf.d/` load alphabetically. Prefix with `zzz-` to ensure yours loads last.

### Add Custom Extensions

Create your own `Dockerfile`:

```dockerfile
FROM ghcr.io/mortezamehrabi/wordpress:8.3

RUN install-php-extensions pdo_pgsql
```

### Custom Apache Configuration

Mount a custom Apache conf:

```bash
docker run -v ./my-apache.conf:/etc/apache2/conf-enabled/my-apache.conf wordpress-base
```

---

## Repository Structure

```
.
├── .github/
│   └── workflows/
│       └── build.yml          # GitHub Actions CI/CD
├── config/
│   ├── php.ini                # Production PHP settings
│   └── opcache.ini            # Production OPcache settings
├── Dockerfile                 # Image definition
├── .gitignore
├── LICENSE
└── README.md
```

---

## Engineering Decisions

- **Single `RUN` layer for extensions:** Install deps, build extensions, purge deps in one layer. Keeps image size small (~no build artifacts in intermediate layers).
- **`sed` instead of custom Apache site config:** The official WordPress image already ships a working VirtualHost. We patch `AllowOverride` globally rather than risking an incompatible override.
- **`COPY --from=composer:2`** instead of downloading a phar. The official Composer image is maintained, multi-arch, and versioned. This is the idiomatic Docker approach.
- **ionCube loaded as `zend_extension`:** ionCube is a Zend Engine extension, not a regular PHP extension. It is loaded via `/usr/local/etc/php/conf.d/00-ioncube.ini` with the `zend_extension=` directive. Using `docker-php-ext-enable` for ionCube is incorrect and would cause a fatal load error.
- **Architecture detection via `uname -m`:** The Dockerfile uses `uname -m` (not `TARGETARCH`) for ionCube binary selection. This works correctly in both local `docker build` and multi-platform BuildKit builds.
- **OPcache timestamp validation ON by default:** Many WordPress deployments lack a deployment hook that clears OPcache. Keeping `validate_timestamps=1` with `revalidate_freq=2` gives near-production throughput without stale-code surprises.
- **No ImageMagick policy overrides:** The restrictive default policies in Debian Bookworm are a security feature. Users who need PDF/EPS processing can override the policy in a child image.

---

## License

MIT — see [LICENSE](./LICENSE).

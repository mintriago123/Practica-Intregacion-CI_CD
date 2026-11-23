# Lab image: runs the API with PHP's built-in server.
# Suitable for the classroom demo, not for production traffic.
FROM php:8.3-cli

RUN apt-get update \
    && apt-get install -y --no-install-recommends git unzip \
    && rm -rf /var/lib/apt/lists/*

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /app

# Install dependencies first so this layer is cached while only source changes.
COPY composer.json composer.lock ./
RUN composer install --no-dev --no-interaction --prefer-dist --no-scripts

COPY . .
RUN composer dump-autoload --optimize --no-dev

EXPOSE 8000

# APP_KEY is injected at runtime (docker run -e APP_KEY=...), never baked into the image.
CMD ["php", "artisan", "serve", "--host=0.0.0.0", "--port=8000"]

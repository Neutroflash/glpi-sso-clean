# Imagen base PHP + Apache para ARM64
FROM --platform=linux/arm64 php:8.2-apache-bookworm

# Paquetes y extensiones PHP necesarias para GLPI
RUN apt-get update && apt-get install -y \
      unzip curl libldap2-dev libzip-dev libpng-dev libjpeg-dev libwebp-dev libfreetype6-dev libicu-dev \
      libxml2-dev libonig-dev libgd-dev libldb-dev libkrb5-dev libssl-dev libxslt1-dev \
      && docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp \
      && docker-php-ext-install -j$(nproc) gd intl zip xml opcache pdo pdo_mysql ldap \
      && apt-get clean && rm -rf /var/lib/apt/lists/*

# Descarga GLPI 10.0.19
WORKDIR /var/www/html
RUN curl -fsSL -o glpi.tgz https://github.com/glpi-project/glpi/releases/download/10.0.19/glpi-10.0.19.tgz \
    && tar xzf glpi.tgz --strip 1 \
    && rm glpi.tgz

# Permisos (simple para dev)
RUN chown -R www-data:www-data /var/www/html

# Apache
ENV APACHE_DOCUMENT_ROOT=/var/www/html
RUN a2enmod rewrite && sed -ri 's!/var/www/html!/var/www/html!g' /etc/apache2/sites-available/*.conf
EXPOSE 80
# Use an official PHP runtime as a base image
FROM php:8.1-fpm

# Set the working directory
WORKDIR /var/www/html

# Install system dependencies and PHP extensions
RUN apt-get update && apt-get install -y \
    git \
    curl \
    libpng-dev \
    libjpeg-dev \
    libfreetype6-dev \
    zip \
    unzip \
    libonig-dev \
    libzip-dev \
    nginx && \
    docker-php-ext-configure gd --with-freetype --with-jpeg && \
    docker-php-ext-install gd pdo pdo_mysql mbstring zip

# Install Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Copy existing application directory contents
COPY . /var/www/html

# Ensure .env file exists
COPY .env /var/www/html/.env

# Set proper permissions for Laravel storage and bootstrap/cache
RUN chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache

# Install Laravel dependencies
RUN composer install --no-dev --optimize-autoloader

# Copy Nginx configuration
COPY ./nginx/default.conf /etc/nginx/sites-available/default

# Expose port 80 for Nginx
EXPOSE 80

# Start both PHP-FPM and Nginx
CMD service nginx start && php-fpm

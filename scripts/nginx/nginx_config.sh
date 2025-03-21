#!/bin/bash

# Prompt the user to enter the domain to configure
read -p "Enter the domain to configure: " domain
# Domain validation section
if [[ -z "$domain" || ! "$domain" =~ \.. ]]; then
    echo "Error: Domain cannot be empty and must contain a valid domain (e.g. example.com)"
    exit 1
fi

read -p "Enter the proxy port:" port
# Port validation section
if ! [[ -z "$port" || "$port" =~ ^[0-9]+$ ]] || ((port < 1 || port > 65535)); then
    echo "Error: Port must be a number between 1 and 65535"
    exit 1
fi

# Set the paths for the Nginx configuration file and ssl-params
NGINX_CONFIG_FILE="/etc/nginx/sites-available/$domain"
NGINX_SSL_PARAMS="/etc/nginx/snippets/ssl-params.conf"

# Check if Nginx is installed
if ! command -v nginx &> /dev/null
then
    echo "Nginx is not installed. Starting installation..."
    sudo apt update && sudo apt install -y nginx
    if [ $? -ne 0 ]; then
        echo "Nginx installation failed. Please check your network and permissions!"
        exit 1
    fi
    echo "Nginx installed successfully!"
else
    echo "Nginx is already installed."
fi

# Check if ssl-params.conf exists, if not, create it
if [ ! -f "$NGINX_SSL_PARAMS" ]; then
  sudo mkdir -p /etc/nginx/snippets
  echo "Creating $NGINX_SSL_PARAMS"
  cat << EOF | sudo tee "$NGINX_SSL_PARAMS"
    ssl_session_timeout 1d;
    ssl_session_cache shared:MozSSL:10m;
    ssl_session_tickets off;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers off;

    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384;

    ssl_ecdh_curve secp384r1;
    ssl_stapling on;
    ssl_stapling_verify on;

    add_header Strict-Transport-Security "max-age=63072000; includeSubdomains; preload" always;
EOF
    if [ $? -ne 0 ]; then
        echo "Failed to create $NGINX_SSL_PARAMS!"
        exit 1
    fi
else
    echo "ssl-params.conf already exists."
fi


# Create the Nginx configuration file
echo "Creating Nginx configuration file: $NGINX_CONFIG_FILE..."
cat << EOF | sudo tee "$NGINX_CONFIG_FILE"
server {
    listen 80;
    listen [::]:80;
    server_name $domain;

    # Redirect http to https
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name $domain;

    include /etc/nginx/snippets/ssl-params.conf;

    location / {
        proxy_pass http://localhost:$port;  # Use the validated port variable
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF
if [ $? -ne 0 ]; then
    echo "Failed to create Nginx configuration file. Please check your permissions!"
    exit 1
fi
echo "Nginx configuration file $NGINX_CONFIG_FILE  created!"

# Create a symbolic link and delete the default configuration
sudo ln -sf "$NGINX_CONFIG_FILE" /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

# Check if Certbot is installed
if ! command -v certbot &> /dev/null
then
    echo "Certbot is not installed. Starting installation..."
    sudo apt install -y certbot python3-certbot-nginx
    if [ $? -ne 0 ]; then
       echo "Certbot installation failed. Please check your network and permissions!"
       exit 1
    fi
    echo "Certbot installed successfully!"
else
    echo "Certbot is already installed."
fi

# Get SSL certificates
echo "Starting to get SSL certificates..."
sudo certbot --nginx -d "$domain"
if [ $? -ne 0 ]; then
    echo "SSL certificate acquisition failed!"
    exit 1
fi

echo "SSL certificates acquired successfully!"

# Test Nginx configuration and reload
echo "Testing Nginx configuration..."
sudo nginx -t
if [ $? -ne 0 ]; then
    echo "Nginx configuration test failed. Please check the configuration file!"
    exit 1
fi

echo "Reloading Nginx configuration..."
sudo systemctl reload nginx

# Complete
echo "Configuration completed, Nginx has been reloaded!"


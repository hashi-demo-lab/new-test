#!/bin/bash
# User data script for EC2 instances
# Installs and configures Nginx with self-signed SSL certificates
# FR-004: Configure web server software (Nginx)
# FR-005: Enable HTTPS access with SSL/TLS configuration

set -e  # Exit on error
exec > >(tee -a /var/log/user-data.log) 2>&1  # Log all output

echo "========================================="
echo "Starting user data script execution"
echo "Date: $(date)"
echo "Environment: ${environment}"
echo "========================================="

# Update system packages
echo "[1/7] Updating system packages..."
dnf update -y

# Install Nginx
echo "[2/7] Installing Nginx..."
dnf install nginx -y

# Create SSL directory
echo "[3/7] Creating SSL certificate directory..."
mkdir -p /etc/nginx/ssl
chmod 700 /etc/nginx/ssl

# Generate self-signed SSL certificate (365 days validity)
echo "[4/7] Generating self-signed SSL certificate..."
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/nginx/ssl/nginx-selfsigned.key \
  -out /etc/nginx/ssl/nginx-selfsigned.crt \
  -subj "/C=AU/ST=NSW/L=Sydney/O=DevTeam/CN=nginx-dev"

chmod 600 /etc/nginx/ssl/nginx-selfsigned.key
chmod 644 /etc/nginx/ssl/nginx-selfsigned.crt

# Configure Nginx with HTTP and HTTPS server blocks
echo "[5/7] Configuring Nginx..."
cat > /etc/nginx/conf.d/default.conf << 'NGINX_CONF'
# HTTP Server (Port 80) - FR-009: Independent HTTP listener
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;

    # Health check endpoint (FR-006)
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }

    # Main location - serve content independently (no redirect per FR-009)
    location / {
        root /usr/share/nginx/html;
        index index.html;
    }
}

# HTTPS Server (Port 443) - FR-005: HTTPS access with SSL/TLS
server {
    listen 443 ssl http2 default_server;
    listen [::]:443 ssl http2 default_server;
    server_name _;

    # SSL certificate configuration
    ssl_certificate /etc/nginx/ssl/nginx-selfsigned.crt;
    ssl_certificate_key /etc/nginx/ssl/nginx-selfsigned.key;

    # TLS 1.2+ configuration (security best practice)
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    # Health check endpoint (FR-006)
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }

    # Main location
    location / {
        root /usr/share/nginx/html;
        index index.html;
    }
}
NGINX_CONF

# Create custom index page
echo "[6/7] Creating custom index page..."
cat > /usr/share/nginx/html/index.html << 'HTML'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>EC2 ALB Nginx - High Availability Infrastructure</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            max-width: 800px;
            margin: 50px auto;
            padding: 20px;
            background: #f5f5f5;
        }
        .container {
            background: white;
            padding: 30px;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        h1 { color: #333; }
        .status { color: #28a745; font-weight: bold; }
        .info { background: #e7f3fe; padding: 15px; border-left: 4px solid #2196F3; margin: 20px 0; }
        code { background: #f4f4f4; padding: 2px 6px; border-radius: 3px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>✅ EC2 ALB Nginx Infrastructure</h1>
        <p class="status">Status: Operational</p>

        <div class="info">
            <strong>Instance Information:</strong><br>
            Hostname: <code id="hostname"></code><br>
            Instance: <code>$(ec2-metadata --instance-id | cut -d' ' -f2)</code><br>
            Availability Zone: <code>$(ec2-metadata --availability-zone | cut -d' ' -f2)</code><br>
            Region: <code>ap-southeast-2</code>
        </div>

        <h2>Features</h2>
        <ul>
            <li><strong>High Availability:</strong> Multi-AZ deployment</li>
            <li><strong>Load Balancing:</strong> Application Load Balancer</li>
            <li><strong>Security:</strong> TLS 1.2+, Security Group Referencing</li>
            <li><strong>Access:</strong> AWS Session Manager (no SSH)</li>
        </ul>

        <h2>Endpoints</h2>
        <ul>
            <li><strong>Health Check:</strong> <code>GET /health</code></li>
            <li><strong>HTTP:</strong> Port 80 (this page)</li>
            <li><strong>HTTPS:</strong> Port 443 (self-signed cert)</li>
        </ul>
    </div>

    <script>
        document.getElementById('hostname').textContent = window.location.hostname;
    </script>
</body>
</html>
HTML

# Start and enable Nginx service
echo "[7/7] Starting Nginx service..."
systemctl start nginx
systemctl enable nginx

# Verify Nginx is running
if systemctl is-active --quiet nginx; then
    echo "✅ SUCCESS: Nginx is running"
    nginx -t
else
    echo "❌ ERROR: Nginx failed to start"
    systemctl status nginx
    exit 1
fi

echo "========================================="
echo "User data script completed successfully"
echo "Date: $(date)"
echo "========================================="

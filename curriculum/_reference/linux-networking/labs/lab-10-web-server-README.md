# Lab 10: Web Server Setup

## Overview

Deploy and configure production-ready web servers using Nginx and Apache. Web servers are fundamental infrastructure components, and understanding their configuration is essential for DevOps engineers.

## Objectives

- Install and configure Nginx
- Install and configure Apache
- Set up virtual hosts
- Configure SSL/TLS certificates
- Implement reverse proxy configuration
- Performance tuning and optimization

## Prerequisites

- Lab 09 completed
- Domain name (optional, can use hosts file)
- Firewall configured for ports 80/443

## Time Estimate

- Guided: 3-4 hours
- Challenge: 2-3 hours

---

## Tier 1: Guided Instructions

### Exercise 1: Nginx Installation and Basics

```bash
# Install Nginx
sudo apt update
sudo apt install nginx -y

# Check status
sudo systemctl status nginx

# Enable on boot
sudo systemctl enable nginx

# View configuration structure
ls -la /etc/nginx/
cat /etc/nginx/nginx.conf

# Key directories
# /etc/nginx/nginx.conf - Main configuration
# /etc/nginx/sites-available/ - Site configurations
# /etc/nginx/sites-enabled/ - Enabled sites (symlinks)
# /etc/nginx/conf.d/ - Additional configurations
# /var/www/ - Web root
# /var/log/nginx/ - Logs

# Test configuration
sudo nginx -t

# View default site
cat /etc/nginx/sites-available/default

# Check web server
curl -I http://localhost
curl http://localhost

# View logs
sudo tail -f /var/log/nginx/access.log &
sudo tail -f /var/log/nginx/error.log &
# Press Ctrl+C to stop
```

### Exercise 2: Nginx Virtual Hosts

```bash
# Create web directories
sudo mkdir -p /var/www/site1.local/html
sudo mkdir -p /var/www/site2.local/html

# Create test pages
sudo tee /var/www/site1.local/html/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head><title>Site 1</title></head>
<body>
<h1>Welcome to Site 1</h1>
<p>Nginx is working!</p>
</body>
</html>
EOF

sudo tee /var/www/site2.local/html/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head><title>Site 2</title></head>
<body>
<h1>Welcome to Site 2</h1>
<p>This is a different virtual host!</p>
</body>
</html>
EOF

# Set ownership
sudo chown -R www-data:www-data /var/www/site1.local
sudo chown -R www-data:www-data /var/www/site2.local

# Create Nginx configuration for Site 1
sudo tee /etc/nginx/sites-available/site1.local << 'EOF'
server {
    listen 80;
    listen [::]:80;

    server_name site1.local www.site1.local;
    root /var/www/site1.local/html;

    index index.html index.htm;

    location / {
        try_files $uri $uri/ =404;
    }

    # Logging
    access_log /var/log/nginx/site1.access.log;
    error_log /var/log/nginx/site1.error.log;
}
EOF

# Create Nginx configuration for Site 2
sudo tee /etc/nginx/sites-available/site2.local << 'EOF'
server {
    listen 80;
    listen [::]:80;

    server_name site2.local www.site2.local;
    root /var/www/site2.local/html;

    index index.html index.htm;

    location / {
        try_files $uri $uri/ =404;
    }

    access_log /var/log/nginx/site2.access.log;
    error_log /var/log/nginx/site2.error.log;
}
EOF

# Enable sites
sudo ln -s /etc/nginx/sites-available/site1.local /etc/nginx/sites-enabled/
sudo ln -s /etc/nginx/sites-available/site2.local /etc/nginx/sites-enabled/

# Test and reload
sudo nginx -t
sudo systemctl reload nginx

# Add to hosts file for testing
echo "127.0.0.1 site1.local site2.local" | sudo tee -a /etc/hosts

# Test virtual hosts
curl -H "Host: site1.local" http://localhost
curl -H "Host: site2.local" http://localhost
```

### Exercise 3: Nginx SSL/TLS Configuration

```bash
# Create self-signed certificate (for testing)
sudo mkdir -p /etc/nginx/ssl
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/site1.key \
    -out /etc/nginx/ssl/site1.crt \
    -subj "/C=US/ST=State/L=City/O=Org/CN=site1.local"

# Create SSL configuration
sudo tee /etc/nginx/sites-available/site1-ssl.local << 'EOF'
server {
    listen 80;
    server_name site1.local www.site1.local;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;

    server_name site1.local www.site1.local;
    root /var/www/site1.local/html;

    # SSL Configuration
    ssl_certificate /etc/nginx/ssl/site1.crt;
    ssl_certificate_key /etc/nginx/ssl/site1.key;

    # Modern SSL settings
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;

    # SSL session
    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL:50m;
    ssl_session_tickets off;

    # HSTS
    add_header Strict-Transport-Security "max-age=31536000" always;

    index index.html;

    location / {
        try_files $uri $uri/ =404;
    }

    access_log /var/log/nginx/site1-ssl.access.log;
    error_log /var/log/nginx/site1-ssl.error.log;
}
EOF

# Disable old config, enable SSL config
sudo rm /etc/nginx/sites-enabled/site1.local
sudo ln -s /etc/nginx/sites-available/site1-ssl.local /etc/nginx/sites-enabled/

# Test and reload
sudo nginx -t
sudo systemctl reload nginx

# Test HTTPS (ignore cert warning for self-signed)
curl -k https://site1.local
```

### Exercise 4: Nginx Reverse Proxy

```bash
# Start a simple backend application (Python)
cat > /tmp/backend.py << 'EOF'
#!/usr/bin/env python3
from http.server import HTTPServer, BaseHTTPRequestHandler
import json

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header('Content-type', 'application/json')
        self.end_headers()
        response = {
            "message": "Hello from backend!",
            "path": self.path,
            "headers": dict(self.headers)
        }
        self.wfile.write(json.dumps(response, indent=2).encode())

HTTPServer(('127.0.0.1', 8000), Handler).serve_forever()
EOF

# Run backend in background
python3 /tmp/backend.py &
BACKEND_PID=$!
echo "Backend PID: $BACKEND_PID"

# Test backend directly
curl http://localhost:8000

# Create reverse proxy configuration
sudo tee /etc/nginx/sites-available/proxy.local << 'EOF'
upstream backend {
    server 127.0.0.1:8000;
    # Additional servers for load balancing:
    # server 127.0.0.1:8001;
    # server 127.0.0.1:8002;
}

server {
    listen 80;
    server_name proxy.local;

    location / {
        proxy_pass http://backend;
        proxy_http_version 1.1;

        # Pass headers
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;

        # Buffering
        proxy_buffering on;
        proxy_buffer_size 4k;
        proxy_buffers 8 4k;
    }

    # Static files served directly
    location /static/ {
        alias /var/www/proxy.local/static/;
    }

    # Health check endpoint
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
EOF

# Enable site
sudo ln -s /etc/nginx/sites-available/proxy.local /etc/nginx/sites-enabled/
echo "127.0.0.1 proxy.local" | sudo tee -a /etc/hosts

# Create static directory
sudo mkdir -p /var/www/proxy.local/static
echo "Static content" | sudo tee /var/www/proxy.local/static/test.txt

# Test and reload
sudo nginx -t
sudo systemctl reload nginx

# Test reverse proxy
curl -H "Host: proxy.local" http://localhost
curl -H "Host: proxy.local" http://localhost/health

# Cleanup backend
kill $BACKEND_PID 2>/dev/null
```

### Exercise 5: Apache Installation and Configuration

```bash
# Stop Nginx (to free port 80) or change port
sudo systemctl stop nginx

# Install Apache
sudo apt install apache2 -y

# Check status
sudo systemctl status apache2

# View configuration
ls -la /etc/apache2/
cat /etc/apache2/apache2.conf

# Key directories
# /etc/apache2/sites-available/ - Site configurations
# /etc/apache2/sites-enabled/ - Enabled sites
# /etc/apache2/mods-available/ - Available modules
# /etc/apache2/mods-enabled/ - Enabled modules
# /var/www/html/ - Default web root

# Enable modules
sudo a2enmod rewrite
sudo a2enmod ssl
sudo a2enmod proxy
sudo a2enmod proxy_http
sudo a2enmod headers

# Create virtual host
sudo tee /etc/apache2/sites-available/site1.local.conf << 'EOF'
<VirtualHost *:80>
    ServerName site1.local
    ServerAlias www.site1.local
    ServerAdmin admin@site1.local

    DocumentRoot /var/www/site1.local/html

    <Directory /var/www/site1.local/html>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog ${APACHE_LOG_DIR}/site1.error.log
    CustomLog ${APACHE_LOG_DIR}/site1.access.log combined
</VirtualHost>
EOF

# Enable site
sudo a2ensite site1.local.conf
sudo a2dissite 000-default.conf

# Test and reload
sudo apache2ctl configtest
sudo systemctl reload apache2

# Test
curl -H "Host: site1.local" http://localhost
```

### Exercise 6: Apache SSL and Reverse Proxy

```bash
# Create SSL virtual host
sudo tee /etc/apache2/sites-available/site1-ssl.local.conf << 'EOF'
<VirtualHost *:80>
    ServerName site1.local
    Redirect permanent / https://site1.local/
</VirtualHost>

<VirtualHost *:443>
    ServerName site1.local
    ServerAdmin admin@site1.local

    DocumentRoot /var/www/site1.local/html

    SSLEngine on
    SSLCertificateFile /etc/nginx/ssl/site1.crt
    SSLCertificateKeyFile /etc/nginx/ssl/site1.key

    # Modern SSL settings
    SSLProtocol all -SSLv3 -TLSv1 -TLSv1.1
    SSLCipherSuite ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256

    <Directory /var/www/site1.local/html>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    # Security headers
    Header always set Strict-Transport-Security "max-age=31536000"
    Header always set X-Content-Type-Options "nosniff"
    Header always set X-Frame-Options "SAMEORIGIN"

    ErrorLog ${APACHE_LOG_DIR}/site1-ssl.error.log
    CustomLog ${APACHE_LOG_DIR}/site1-ssl.access.log combined
</VirtualHost>
EOF

# Enable SSL site
sudo a2dissite site1.local.conf
sudo a2ensite site1-ssl.local.conf

# Apache reverse proxy configuration
sudo tee /etc/apache2/sites-available/proxy.local.conf << 'EOF'
<VirtualHost *:80>
    ServerName proxy.local

    ProxyPreserveHost On
    ProxyPass / http://127.0.0.1:8000/
    ProxyPassReverse / http://127.0.0.1:8000/

    # Pass headers
    RequestHeader set X-Forwarded-Proto "http"
    RequestHeader set X-Real-IP %{REMOTE_ADDR}s

    ErrorLog ${APACHE_LOG_DIR}/proxy.error.log
    CustomLog ${APACHE_LOG_DIR}/proxy.access.log combined
</VirtualHost>
EOF

# Test and reload
sudo apache2ctl configtest
sudo systemctl reload apache2

# Test
curl -k https://site1.local
```

### Exercise 7: Performance Tuning

```bash
# Nginx performance configuration
sudo tee /etc/nginx/conf.d/performance.conf << 'EOF'
# Worker configuration
# worker_processes auto; (in main nginx.conf)
# worker_connections 1024; (in events block)

# Connection handling
keepalive_timeout 65;
keepalive_requests 100;

# Buffers
client_body_buffer_size 10K;
client_header_buffer_size 1k;
client_max_body_size 8m;
large_client_header_buffers 4 4k;

# Timeouts
client_body_timeout 12;
client_header_timeout 12;
send_timeout 10;

# Compression
gzip on;
gzip_vary on;
gzip_proxied any;
gzip_comp_level 6;
gzip_types text/plain text/css text/xml application/json application/javascript application/xml;
gzip_min_length 256;

# Static file caching
open_file_cache max=1000 inactive=20s;
open_file_cache_valid 30s;
open_file_cache_min_uses 2;
open_file_cache_errors on;
EOF

# Create caching location block example
cat > /tmp/nginx-caching-example.conf << 'EOF'
# Add to server block for static file caching
location ~* \.(jpg|jpeg|png|gif|ico|css|js)$ {
    expires 30d;
    add_header Cache-Control "public, immutable";
}

location ~* \.(woff|woff2|ttf|otf|eot)$ {
    expires 1y;
    add_header Cache-Control "public, immutable";
}
EOF

# Apache performance tuning
sudo tee /etc/apache2/conf-available/performance.conf << 'EOF'
# MPM configuration (for prefork)
<IfModule mpm_prefork_module>
    StartServers             5
    MinSpareServers          5
    MaxSpareServers         10
    MaxRequestWorkers      150
    MaxConnectionsPerChild   0
</IfModule>

# Enable compression
<IfModule mod_deflate.c>
    SetOutputFilter DEFLATE
    DeflateCompressionLevel 6
    AddOutputFilterByType DEFLATE text/html text/plain text/xml text/css application/javascript application/json
</IfModule>

# Browser caching
<IfModule mod_expires.c>
    ExpiresActive On
    ExpiresByType image/jpg "access plus 1 month"
    ExpiresByType image/jpeg "access plus 1 month"
    ExpiresByType image/gif "access plus 1 month"
    ExpiresByType image/png "access plus 1 month"
    ExpiresByType text/css "access plus 1 week"
    ExpiresByType application/javascript "access plus 1 week"
</IfModule>

# KeepAlive
KeepAlive On
MaxKeepAliveRequests 100
KeepAliveTimeout 5
EOF

sudo a2enmod deflate
sudo a2enmod expires
sudo a2enconf performance
```

### Exercise 8: Web Server Monitoring Script

```bash
cat > ~/scripts/webserver_monitor.sh << 'EOF'
#!/bin/bash
set -euo pipefail

# Web Server Monitoring Script

echo "=== Web Server Monitor ==="
echo "Date: $(date)"
echo ""

# Check which web server is running
echo "--- Running Web Servers ---"
if systemctl is-active --quiet nginx; then
    echo "Nginx: RUNNING"
    echo "  Version: $(nginx -v 2>&1)"
fi
if systemctl is-active --quiet apache2; then
    echo "Apache: RUNNING"
    echo "  Version: $(apache2 -v | head -1)"
fi

# Check ports
echo ""
echo "--- Listening Ports ---"
sudo ss -tlnp | grep -E ':80|:443' || echo "No web ports found"

# Check processes
echo ""
echo "--- Web Server Processes ---"
ps aux | grep -E 'nginx|apache2|httpd' | grep -v grep | head -10

# Check disk usage for web directories
echo ""
echo "--- Web Directory Sizes ---"
du -sh /var/www/* 2>/dev/null | head -10

# Check log sizes
echo ""
echo "--- Log File Sizes ---"
if [[ -d /var/log/nginx ]]; then
    echo "Nginx logs:"
    du -sh /var/log/nginx/*
fi
if [[ -d /var/log/apache2 ]]; then
    echo "Apache logs:"
    du -sh /var/log/apache2/*
fi

# Recent errors
echo ""
echo "--- Recent Errors (last 10) ---"
if [[ -f /var/log/nginx/error.log ]]; then
    echo "Nginx errors:"
    sudo tail -5 /var/log/nginx/error.log
fi
if [[ -f /var/log/apache2/error.log ]]; then
    echo "Apache errors:"
    sudo tail -5 /var/log/apache2/error.log
fi

# Test endpoints
echo ""
echo "--- Endpoint Tests ---"
for site in "localhost" "site1.local" "site2.local"; do
    response=$(curl -s -o /dev/null -w "%{http_code}" "http://$site" 2>/dev/null || echo "000")
    if [[ "$response" == "200" ]]; then
        echo "✓ $site - HTTP $response"
    else
        echo "✗ $site - HTTP $response"
    fi
done

echo ""
echo "=== Monitor Complete ==="
EOF

chmod +x ~/scripts/webserver_monitor.sh
~/scripts/webserver_monitor.sh
```

---

## Tier 2: Semi-Guided Exercises

### Exercise A: Load Balancer Configuration

Set up Nginx as a load balancer:

1. Create 3 backend application servers
2. Configure upstream with different algorithms (round-robin, least_conn, ip_hash)
3. Implement health checks
4. Configure sticky sessions
5. Test failover scenarios

### Exercise B: Web Application Firewall

Implement basic WAF functionality:

1. Install ModSecurity for Nginx or Apache
2. Configure OWASP Core Rule Set
3. Test against common attacks
4. Tune rules to reduce false positives
5. Set up logging and alerting

### Exercise C: Multi-Site Deployment

Deploy a complete multi-site infrastructure:

1. Multiple virtual hosts
2. SSL for all sites (Let's Encrypt)
3. Centralized logging
4. Automated certificate renewal
5. Deployment script for new sites

---

## Tier 3: Challenge

Build a production-ready web infrastructure:

1. **High-Availability Setup**
   - Load-balanced web servers
   - Session persistence
   - Health monitoring
   - Automatic failover

2. **Security Hardening**
   - SSL/TLS best practices
   - Security headers
   - Rate limiting
   - WAF integration

3. **Performance Optimization**
   - Caching strategy
   - Compression
   - CDN integration
   - Performance benchmarking

4. **Monitoring and Logging**
   - Centralized logging
   - Performance metrics
   - Alert configuration
   - Dashboard creation

---

## Cleanup

```bash
# Stop web servers
sudo systemctl stop nginx apache2

# Remove configurations (optional)
# sudo rm /etc/nginx/sites-enabled/site*.local
# sudo rm /etc/nginx/sites-available/site*.local
# sudo rm /etc/apache2/sites-enabled/site*.local.conf
# sudo rm /etc/apache2/sites-available/site*.local.conf

# Remove web directories (optional)
# sudo rm -rf /var/www/site1.local /var/www/site2.local

# Remove hosts entries
sudo sed -i '/site1.local/d' /etc/hosts
sudo sed -i '/site2.local/d' /etc/hosts
sudo sed -i '/proxy.local/d' /etc/hosts
```

---

## Key Takeaways

1. **Nginx vs Apache** - Know when to use each
2. **Virtual hosts** - Essential for multi-site hosting
3. **SSL/TLS** - Always use HTTPS in production
4. **Reverse proxy** - Foundation for microservices
5. **Performance tuning** - Compression, caching, buffers
6. **Test before reload** - nginx -t, apache2ctl configtest

---

## Next Lab

[Lab 11: Troubleshooting](../lab-11-troubleshooting/)

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Nginx Installation and Basics
- Nginx Virtual Hosts
- Nginx SSL/TLS Configuration
- Nginx Reverse Proxy

**The gap is not what you forgot. It is where you used a word instead of a mechanism.**

| | |
|---|---|
| ✗ | *"The kernel manages processes."* |
| ✓ | *"A process is an entry in the kernel's task table with its own memory map and file-descriptor table. `fork()` copies it, `exec()` replaces the program inside it, and the parent must call `wait()` or the entry stays behind as a zombie."* |

**Trace it:** `ls -l /etc` → characters on your terminal. Name every syscall and every kernel structure between the keypress and the output.

Stop at the first component you cannot name. Reopen this file and read **only** that.

**Go deeper — only once the gap has a name:** [`man 7 namespaces`](https://man7.org/linux/man-pages/man7/namespaces.7.html) and the [LWN namespaces series](https://lwn.net/Articles/531114/) — the primary sources, not summaries of them.
Full list per domain: [`SOURCES.md`](../../SOURCES.md#linux-networking)

→ Protocol, the three levels of knowing, and worked examples: [`MASTERY.md`](../../MASTERY.md)

<!-- /feynman-check -->

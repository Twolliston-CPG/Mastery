# Lab 3.4: Docker Compose

> **Duration:** 60-90 minutes
> **Environment:** Docker with Compose
> **Difficulty:** Intermediate

---

## Objectives

- Define multi-container applications
- Configure networks and volumes
- Manage development environments
- Use Compose for local development

---

## Part 1: Compose Basics

### Exercise 1.1: First Compose File

```bash
mkdir -p ~/docker-lab/compose-basics
cd ~/docker-lab/compose-basics

cat > docker-compose.yml << 'EOF'
version: "3.9"

services:
  web:
    image: nginx:1.25-alpine
    ports:
      - "8080:80"
EOF

# Start services
docker compose up -d

# Check status
docker compose ps

# View logs
docker compose logs

# Stop services
docker compose down
```

### Exercise 1.2: Multi-Service Application

```bash
mkdir -p ~/docker-lab/multi-service
cd ~/docker-lab/multi-service

cat > docker-compose.yml << 'EOF'
version: "3.9"

services:
  api:
    image: python:3.12-alpine
    command: python -m http.server 8000
    ports:
      - "8000:8000"
    environment:
      - DATABASE_URL=postgres://user:pass@db:5432/app
    depends_on:
      - db
      - cache

  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: user
      POSTGRES_PASSWORD: pass
      POSTGRES_DB: app
    volumes:
      - pgdata:/var/lib/postgresql/data

  cache:
    image: redis:7-alpine
    volumes:
      - redisdata:/data

volumes:
  pgdata:
  redisdata:
EOF

# Start all services
docker compose up -d

# Check all services
docker compose ps

# View specific service logs
docker compose logs db
docker compose logs -f api

# Execute command in service
docker compose exec db psql -U user -d app -c "SELECT 1;"

# Stop all
docker compose down
```

---

## Part 2: Building with Compose

### Exercise 2.1: Build from Dockerfile

```bash
mkdir -p ~/docker-lab/compose-build
cd ~/docker-lab/compose-build

# Create app
cat > app.py << 'EOF'
from flask import Flask, jsonify
import redis
import os

app = Flask(__name__)
cache = redis.Redis(host=os.getenv('REDIS_HOST', 'cache'))

@app.route('/')
def index():
    count = cache.incr('hits')
    return jsonify({
        'message': 'Hello!',
        'hits': count
    })

@app.route('/health')
def health():
    return jsonify({'status': 'healthy'})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
EOF

cat > requirements.txt << 'EOF'
flask==3.0.0
redis==5.0.1
EOF

cat > Dockerfile << 'EOF'
FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
EXPOSE 5000
CMD ["python", "app.py"]
EOF

cat > docker-compose.yml << 'EOF'
version: "3.9"

services:
  api:
    build:
      context: .
      dockerfile: Dockerfile
    ports:
      - "5000:5000"
    environment:
      - REDIS_HOST=cache
    depends_on:
      - cache
    volumes:
      - .:/app  # Mount for development

  cache:
    image: redis:7-alpine
EOF

# Build and start
docker compose up -d --build

# Test
curl http://localhost:5000
curl http://localhost:5000
curl http://localhost:5000
# Count increases each time

# Rebuild single service
docker compose build api
docker compose up -d api

docker compose down
```

### Exercise 2.2: Development vs Production

```bash
mkdir -p ~/docker-lab/compose-envs
cd ~/docker-lab/compose-envs

# Base compose file
cat > docker-compose.yml << 'EOF'
version: "3.9"

services:
  api:
    build: .
    environment:
      - NODE_ENV=production
EOF

# Development overrides
cat > docker-compose.override.yml << 'EOF'
version: "3.9"

services:
  api:
    environment:
      - NODE_ENV=development
      - DEBUG=true
    volumes:
      - .:/app
      - /app/node_modules
    ports:
      - "3000:3000"
      - "9229:9229"  # Debug port
EOF

# Production overrides
cat > docker-compose.prod.yml << 'EOF'
version: "3.9"

services:
  api:
    restart: always
    deploy:
      replicas: 3
      resources:
        limits:
          cpus: '0.5'
          memory: 512M
EOF

# Development (uses override automatically)
docker compose config

# Production
docker compose -f docker-compose.yml -f docker-compose.prod.yml config
```

---

## Part 3: Networking

### Exercise 3.1: Custom Networks

```bash
mkdir -p ~/docker-lab/compose-networks
cd ~/docker-lab/compose-networks

cat > docker-compose.yml << 'EOF'
version: "3.9"

services:
  frontend:
    image: nginx:alpine
    networks:
      - frontend
    ports:
      - "80:80"

  api:
    image: python:3.12-alpine
    command: python -m http.server 8000
    networks:
      - frontend
      - backend

  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_PASSWORD: secret
    networks:
      - backend

  admin:
    image: adminer:4
    networks:
      - backend
    ports:
      - "8080:8080"

networks:
  frontend:
    driver: bridge
  backend:
    driver: bridge
    internal: true  # No external access
EOF

docker compose up -d

# Frontend can reach api
docker compose exec frontend ping -c 2 api

# Frontend cannot reach db (different network)
docker compose exec frontend ping -c 2 db || echo "Cannot reach db (correct!)"

# API can reach both
docker compose exec api ping -c 2 frontend
docker compose exec api ping -c 2 db

docker compose down
```

---

## Part 4: Health Checks & Dependencies

### Exercise 4.1: Health Checks

```bash
mkdir -p ~/docker-lab/compose-health
cd ~/docker-lab/compose-health

cat > docker-compose.yml << 'EOF'
version: "3.9"

services:
  api:
    image: python:3.12-alpine
    command: python -m http.server 8000
    healthcheck:
      test: ["CMD", "wget", "-q", "--spider", "http://localhost:8000"]
      interval: 10s
      timeout: 5s
      retries: 3
      start_period: 5s
    depends_on:
      db:
        condition: service_healthy

  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_PASSWORD: secret
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 5s
      timeout: 5s
      retries: 5
EOF

docker compose up -d

# Watch health status
watch docker compose ps

# DB becomes healthy first, then API starts
docker compose down
```

---

## Part 5: Real-World Example

### Exercise 5.1: Full Stack Application

```bash
mkdir -p ~/docker-lab/fullstack/{api,web}
cd ~/docker-lab/fullstack

# API (Flask)
cat > api/app.py << 'EOF'
from flask import Flask, jsonify
from flask_cors import CORS
import psycopg2
import os

app = Flask(__name__)
CORS(app)

def get_db():
    return psycopg2.connect(os.getenv('DATABASE_URL'))

@app.route('/api/items')
def get_items():
    try:
        conn = get_db()
        cur = conn.cursor()
        cur.execute("SELECT id, name FROM items")
        items = [{'id': r[0], 'name': r[1]} for r in cur.fetchall()]
        return jsonify(items)
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/health')
def health():
    return jsonify({'status': 'ok'})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
EOF

cat > api/requirements.txt << 'EOF'
flask==3.0.0
flask-cors==4.0.0
psycopg2-binary==2.9.9
EOF

cat > api/Dockerfile << 'EOF'
FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
CMD ["python", "app.py"]
EOF

# Database init
cat > init.sql << 'EOF'
CREATE TABLE IF NOT EXISTS items (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL
);
INSERT INTO items (name) VALUES ('Item 1'), ('Item 2'), ('Item 3');
EOF

# Docker Compose
cat > docker-compose.yml << 'EOF'
version: "3.9"

services:
  api:
    build: ./api
    ports:
      - "5000:5000"
    environment:
      - DATABASE_URL=postgres://user:secret@db:5432/app
    depends_on:
      db:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5000/health"]
      interval: 10s
      timeout: 5s
      retries: 3

  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: user
      POSTGRES_PASSWORD: secret
      POSTGRES_DB: app
    volumes:
      - ./init.sql:/docker-entrypoint-initdb.d/init.sql
      - pgdata:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U user -d app"]
      interval: 5s
      timeout: 5s
      retries: 5

  adminer:
    image: adminer:4
    ports:
      - "8080:8080"
    depends_on:
      - db

volumes:
  pgdata:
EOF

# Start everything
docker compose up -d --build

# Wait for health
sleep 10
docker compose ps

# Test API
curl http://localhost:5000/api/items | jq

# Access Adminer at http://localhost:8080
# Server: db, User: user, Pass: secret, DB: app

docker compose down -v
```

---

## Validation Checklist

- [ ] I can write docker-compose.yml files
- [ ] I can define multi-service applications
- [ ] I can configure networks and volumes
- [ ] I can use build context with Compose
- [ ] I can implement health checks
- [ ] I can manage multiple environments

---

## Next Steps

Complete the [Module 3 Project](../project/) and [Challenge](../challenge/).

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Compose Basics
- Building with Compose
- Networking
- Health Checks & Dependencies

**The gap is not what you forgot. It is where you used a word instead of a mechanism.**

| | |
|---|---|
| ✗ | *"A container isolates the application."* |
| ✓ | *"A container is an ordinary Linux process started with namespaces (what it can see), cgroups (what it can use) and usually seccomp (what it may ask the kernel). There is no container object in the kernel — only a process with those features switched on."* |

**Trace it:** `docker run` → an isolated process. Name the namespaces in the order they are created, and which component actually calls `clone()`.

Stop at the first component you cannot name. Reopen this file and read **only** that.

**Go deeper — only once the gap has a name:** the [LWN namespaces series](https://lwn.net/Articles/531114/) — seven parts by the man-pages maintainer, and the reason containers stop being magic.
Full list per domain: [`SOURCES.md`](../../SOURCES.md#containers)

→ Protocol, the three levels of knowing, and worked examples: [`MASTERY.md`](../../MASTERY.md)

<!-- /feynman-check -->

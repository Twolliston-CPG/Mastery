# Exercise 3: Stateful Workloads with Persistent Storage

## Objectives

- Deploy databases with persistent storage
- Configure StatefulSets with volumeClaimTemplates
- Implement data persistence patterns
- Handle storage for replicated workloads

## Prerequisites

- Completed Exercises 1-2
- Understanding of StatefulSets
- Storage classes configured

---

## Part 1: Database Deployment Patterns

### 1.1 PostgreSQL with Persistent Storage

```yaml
# postgresql-stateful.yaml
apiVersion: v1
kind: Secret
metadata:
  name: postgres-secret
type: Opaque
stringData:
  POSTGRES_USER: admin
  POSTGRES_PASSWORD: secretpassword
  POSTGRES_DB: appdb
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: postgres-config
data:
  postgresql.conf: |
    listen_addresses = '*'
    max_connections = 100
    shared_buffers = 256MB
    work_mem = 16MB
    maintenance_work_mem = 128MB
    wal_level = replica
    max_wal_senders = 3
---
apiVersion: v1
kind: Service
metadata:
  name: postgres
spec:
  ports:
  - port: 5432
  clusterIP: None
  selector:
    app: postgres
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
spec:
  serviceName: postgres
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
      - name: postgres
        image: postgres:15
        ports:
        - containerPort: 5432
        envFrom:
        - secretRef:
            name: postgres-secret
        volumeMounts:
        - name: data
          mountPath: /var/lib/postgresql/data
        - name: config
          mountPath: /etc/postgresql/postgresql.conf
          subPath: postgresql.conf
        resources:
          requests:
            cpu: "500m"
            memory: "1Gi"
          limits:
            cpu: "2"
            memory: "4Gi"
        readinessProbe:
          exec:
            command:
            - pg_isready
            - -U
            - admin
          initialDelaySeconds: 10
          periodSeconds: 5
        livenessProbe:
          exec:
            command:
            - pg_isready
            - -U
            - admin
          initialDelaySeconds: 30
          periodSeconds: 10
      volumes:
      - name: config
        configMap:
          name: postgres-config
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: tier1-high-performance
      resources:
        requests:
          storage: 50Gi
```

### 1.2 MySQL with Replication

```yaml
# mysql-replicated.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: mysql-config
data:
  primary.cnf: |
    [mysqld]
    server-id=1
    log_bin=mysql-bin
    binlog_format=ROW
    gtid_mode=ON
    enforce-gtid-consistency=ON

  replica.cnf: |
    [mysqld]
    server-id=2
    read_only=ON
    super_read_only=ON
    relay-log=relay-bin
    log_slave_updates=ON
    gtid_mode=ON
    enforce-gtid-consistency=ON
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mysql
spec:
  serviceName: mysql
  replicas: 3
  selector:
    matchLabels:
      app: mysql
  template:
    metadata:
      labels:
        app: mysql
    spec:
      initContainers:
      - name: init-mysql
        image: mysql:8.0
        command:
        - bash
        - "-c"
        - |
          set -ex
          [[ `hostname` =~ -([0-9]+)$ ]] || exit 1
          ordinal=${BASH_REMATCH[1]}
          if [[ $ordinal -eq 0 ]]; then
            cp /mnt/config/primary.cnf /mnt/conf.d/server.cnf
          else
            cp /mnt/config/replica.cnf /mnt/conf.d/server.cnf
          fi
          echo "server-id=$((100 + $ordinal))" >> /mnt/conf.d/server.cnf
        volumeMounts:
        - name: config
          mountPath: /mnt/config
        - name: conf
          mountPath: /mnt/conf.d
      containers:
      - name: mysql
        image: mysql:8.0
        env:
        - name: MYSQL_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mysql-secret
              key: root-password
        ports:
        - containerPort: 3306
        volumeMounts:
        - name: data
          mountPath: /var/lib/mysql
        - name: conf
          mountPath: /etc/mysql/conf.d
        resources:
          requests:
            cpu: "500m"
            memory: "1Gi"
        readinessProbe:
          exec:
            command:
            - mysqladmin
            - ping
            - -h
            - localhost
          initialDelaySeconds: 30
          periodSeconds: 10
      volumes:
      - name: config
        configMap:
          name: mysql-config
      - name: conf
        emptyDir: {}
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: tier1-high-performance
      resources:
        requests:
          storage: 100Gi
---
apiVersion: v1
kind: Secret
metadata:
  name: mysql-secret
type: Opaque
stringData:
  root-password: mysecretpassword
---
# Read service
apiVersion: v1
kind: Service
metadata:
  name: mysql-read
spec:
  ports:
  - port: 3306
  selector:
    app: mysql
---
# Headless service for StatefulSet
apiVersion: v1
kind: Service
metadata:
  name: mysql
spec:
  ports:
  - port: 3306
  clusterIP: None
  selector:
    app: mysql
```

---

## Part 2: Redis with Persistence

### 2.1 Redis Standalone with RDB + AOF

```yaml
# redis-persistent.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: redis-config
data:
  redis.conf: |
    # Persistence
    save 900 1
    save 300 10
    save 60 10000
    appendonly yes
    appendfilename "appendonly.aof"
    appendfsync everysec

    # Memory
    maxmemory 1gb
    maxmemory-policy allkeys-lru

    # Security
    requirepass ${REDIS_PASSWORD}
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: redis
spec:
  serviceName: redis
  replicas: 1
  selector:
    matchLabels:
      app: redis
  template:
    metadata:
      labels:
        app: redis
    spec:
      containers:
      - name: redis
        image: redis:7-alpine
        command:
        - redis-server
        - /etc/redis/redis.conf
        ports:
        - containerPort: 6379
        env:
        - name: REDIS_PASSWORD
          valueFrom:
            secretKeyRef:
              name: redis-secret
              key: password
        volumeMounts:
        - name: data
          mountPath: /data
        - name: config
          mountPath: /etc/redis
        resources:
          requests:
            cpu: "250m"
            memory: "512Mi"
          limits:
            cpu: "1"
            memory: "1Gi"
        readinessProbe:
          exec:
            command:
            - redis-cli
            - ping
          initialDelaySeconds: 5
          periodSeconds: 5
        livenessProbe:
          exec:
            command:
            - redis-cli
            - ping
          initialDelaySeconds: 30
          periodSeconds: 10
      volumes:
      - name: config
        configMap:
          name: redis-config
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: tier1-high-performance
      resources:
        requests:
          storage: 20Gi
---
apiVersion: v1
kind: Secret
metadata:
  name: redis-secret
type: Opaque
stringData:
  password: redissecretpassword
---
apiVersion: v1
kind: Service
metadata:
  name: redis
spec:
  ports:
  - port: 6379
  selector:
    app: redis
```

---

## Part 3: MongoDB with ReplicaSet

### 3.1 MongoDB ReplicaSet

```yaml
# mongodb-replicaset.yaml
apiVersion: v1
kind: Secret
metadata:
  name: mongodb-secret
type: Opaque
stringData:
  MONGO_INITDB_ROOT_USERNAME: admin
  MONGO_INITDB_ROOT_PASSWORD: mongopassword
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: mongodb-scripts
data:
  init-replicaset.sh: |
    #!/bin/bash
    sleep 10
    mongosh --host mongodb-0.mongodb:27017 -u admin -p $MONGO_INITDB_ROOT_PASSWORD --eval "
    rs.initiate({
      _id: 'rs0',
      members: [
        {_id: 0, host: 'mongodb-0.mongodb:27017', priority: 2},
        {_id: 1, host: 'mongodb-1.mongodb:27017', priority: 1},
        {_id: 2, host: 'mongodb-2.mongodb:27017', priority: 1}
      ]
    })
    "
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mongodb
spec:
  serviceName: mongodb
  replicas: 3
  selector:
    matchLabels:
      app: mongodb
  template:
    metadata:
      labels:
        app: mongodb
    spec:
      containers:
      - name: mongodb
        image: mongo:7
        command:
        - mongod
        - "--replSet"
        - "rs0"
        - "--bind_ip_all"
        ports:
        - containerPort: 27017
        envFrom:
        - secretRef:
            name: mongodb-secret
        volumeMounts:
        - name: data
          mountPath: /data/db
        resources:
          requests:
            cpu: "500m"
            memory: "1Gi"
          limits:
            cpu: "2"
            memory: "4Gi"
        readinessProbe:
          exec:
            command:
            - mongosh
            - --eval
            - "db.adminCommand('ping')"
          initialDelaySeconds: 10
          periodSeconds: 10
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: tier1-high-performance
      resources:
        requests:
          storage: 50Gi
---
apiVersion: v1
kind: Service
metadata:
  name: mongodb
spec:
  ports:
  - port: 27017
  clusterIP: None
  selector:
    app: mongodb
```

---

## Part 4: Elasticsearch Cluster

### 4.1 Elasticsearch StatefulSet

```yaml
# elasticsearch-cluster.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: elasticsearch
spec:
  serviceName: elasticsearch
  replicas: 3
  selector:
    matchLabels:
      app: elasticsearch
  template:
    metadata:
      labels:
        app: elasticsearch
    spec:
      initContainers:
      - name: fix-permissions
        image: busybox
        command: ["sh", "-c", "chown -R 1000:1000 /usr/share/elasticsearch/data"]
        securityContext:
          privileged: true
        volumeMounts:
        - name: data
          mountPath: /usr/share/elasticsearch/data
      - name: increase-vm-max-map
        image: busybox
        command: ["sysctl", "-w", "vm.max_map_count=262144"]
        securityContext:
          privileged: true
      containers:
      - name: elasticsearch
        image: docker.elastic.co/elasticsearch/elasticsearch:8.11.0
        ports:
        - containerPort: 9200
          name: http
        - containerPort: 9300
          name: transport
        env:
        - name: cluster.name
          value: "k8s-cluster"
        - name: node.name
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        - name: discovery.seed_hosts
          value: "elasticsearch-0.elasticsearch,elasticsearch-1.elasticsearch,elasticsearch-2.elasticsearch"
        - name: cluster.initial_master_nodes
          value: "elasticsearch-0,elasticsearch-1,elasticsearch-2"
        - name: ES_JAVA_OPTS
          value: "-Xms1g -Xmx1g"
        - name: xpack.security.enabled
          value: "false"
        volumeMounts:
        - name: data
          mountPath: /usr/share/elasticsearch/data
        resources:
          requests:
            cpu: "500m"
            memory: "2Gi"
          limits:
            cpu: "2"
            memory: "4Gi"
        readinessProbe:
          httpGet:
            path: /_cluster/health
            port: 9200
          initialDelaySeconds: 60
          periodSeconds: 10
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: tier1-high-performance
      resources:
        requests:
          storage: 100Gi
---
apiVersion: v1
kind: Service
metadata:
  name: elasticsearch
spec:
  ports:
  - port: 9200
    name: http
  - port: 9300
    name: transport
  clusterIP: None
  selector:
    app: elasticsearch
---
apiVersion: v1
kind: Service
metadata:
  name: elasticsearch-http
spec:
  ports:
  - port: 9200
  selector:
    app: elasticsearch
```

---

## Part 5: Data Migration and Backup

### 5.1 Init Container for Data Restore

```yaml
# data-restore-pattern.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: app-with-restore
spec:
  template:
    spec:
      initContainers:
      - name: restore-data
        image: amazon/aws-cli:2.13.0
        command:
        - /bin/sh
        - -c
        - |
          if [ ! -f /data/.initialized ]; then
            echo "Restoring from backup..."
            aws s3 cp s3://backups/latest.tar.gz /tmp/
            tar -xzf /tmp/latest.tar.gz -C /data/
            touch /data/.initialized
          else
            echo "Data already initialized"
          fi
        env:
        - name: AWS_ACCESS_KEY_ID
          valueFrom:
            secretKeyRef:
              name: aws-credentials
              key: access-key
        - name: AWS_SECRET_ACCESS_KEY
          valueFrom:
            secretKeyRef:
              name: aws-credentials
              key: secret-key
        volumeMounts:
        - name: data
          mountPath: /data
      containers:
      - name: app
        # ...
```

### 5.2 Sidecar for Continuous Backup

```yaml
# continuous-backup-pattern.yaml
spec:
  containers:
  - name: app
    image: myapp:1.0
    volumeMounts:
    - name: data
      mountPath: /data

  - name: backup-sidecar
    image: amazon/aws-cli:2.13.0
    command:
    - /bin/sh
    - -c
    - |
      while true; do
        echo "Creating backup at $(date)"
        tar -czf /tmp/backup-$(date +%Y%m%d-%H%M%S).tar.gz /data/
        aws s3 cp /tmp/backup-*.tar.gz s3://backups/
        rm /tmp/backup-*.tar.gz
        sleep 3600  # Backup every hour
      done
    volumeMounts:
    - name: data
      mountPath: /data
      readOnly: true
```

---

## Part 6: Hands-on Challenges

### Challenge 1: High-Availability Database

Deploy PostgreSQL with:
1. Primary-Replica configuration
2. Automatic failover
3. Read replicas for scaling
4. Monitoring and alerting

### Challenge 2: Distributed Cache

Deploy Redis Cluster with:
1. 3 masters, 3 replicas
2. Persistent storage
3. Cluster mode enabled
4. Automatic resharding

### Challenge 3: Data Platform

Create a complete data platform:
1. PostgreSQL for OLTP
2. Elasticsearch for search
3. Redis for caching
4. Shared backup solution

---

## Verification Tasks

1. [ ] Deployed PostgreSQL with persistent storage
2. [ ] Configured MySQL replication
3. [ ] Set up Redis with RDB and AOF
4. [ ] Deployed MongoDB ReplicaSet
5. [ ] Created Elasticsearch cluster
6. [ ] Implemented backup strategy

---

## Key Takeaways

- StatefulSets provide stable identity for databases
- volumeClaimTemplates create per-pod storage
- Init containers enable data initialization
- Sidecars enable continuous backup
- Storage class selection impacts performance
- Proper resource limits prevent issues

---

## Next Steps

Continue to [Exercise 4: Volume Snapshots](04-volume-snapshots.md)

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Database Deployment Patterns
- Redis with Persistence
- MongoDB with ReplicaSet
- Elasticsearch Cluster

**The gap is not what you forgot. It is where you used a word instead of a mechanism.**

| | |
|---|---|
| ✗ | *"Kubernetes schedules the pod."* |
| ✓ | *"The scheduler watches for pods with no `nodeName`, filters nodes by predicates, scores the survivors, and writes `nodeName` into the pod spec. The kubelet on that node is watching the API for pods bound to it, and starts the containers."* |

**Trace it:** `kubectl apply -f pod.yaml` → a running container. Name every component that acts, in order, and what each one writes.

Stop at the first component you cannot name. Reopen this file and read **only** that.

**Go deeper — only once the gap has a name:** [Kubernetes the Hard Way](https://github.com/kelseyhightower/kubernetes-the-hard-way) — one weekend, and "the control plane" stops being a word.
Full list per domain: [`SOURCES.md`](../../SOURCES.md#kubernetes)

→ Protocol, the three levels of knowing, and worked examples: [`MASTERY.md`](../../MASTERY.md)

<!-- /feynman-check -->

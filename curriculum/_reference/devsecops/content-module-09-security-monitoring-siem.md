# Module 9: Security Monitoring and SIEM

## Learning Objectives

By the end of this module, you will be able to:
- Design and implement comprehensive security monitoring strategies
- Deploy and configure SIEM solutions for threat detection
- Create effective security alerting and correlation rules
- Build security dashboards for visibility and compliance
- Implement log aggregation and analysis for security events
- Respond to security incidents using SIEM data

## Introduction to Security Monitoring

Security monitoring provides continuous visibility into your infrastructure's security posture, enabling rapid detection and response to threats.

### Security Monitoring Fundamentals

```yaml
# Security Monitoring Strategy
security_monitoring:
  objectives:
    - Threat Detection: Identify malicious activities
    - Compliance Monitoring: Track regulatory requirements
    - Incident Response: Enable rapid investigation
    - Risk Management: Understand security posture

  data_sources:
    infrastructure:
      - System logs (syslog, Windows Event Log)
      - Network traffic (NetFlow, packet capture)
      - Cloud provider logs (CloudTrail, Activity Log)
      - Container/Kubernetes logs

    applications:
      - Application logs
      - API access logs
      - Authentication events
      - Database audit logs

    security_tools:
      - Firewall logs
      - IDS/IPS alerts
      - Endpoint detection (EDR)
      - Vulnerability scanners

  metrics:
    - Mean Time to Detect (MTTD)
    - Mean Time to Respond (MTTR)
    - False Positive Rate
    - Coverage Percentage
```

## SIEM Architecture and Deployment

### Elastic Security (ELK Stack)

```yaml
# Elasticsearch Security Cluster
# elasticsearch-security.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: elasticsearch-config
  namespace: security
data:
  elasticsearch.yml: |
    cluster.name: security-cluster
    node.name: ${HOSTNAME}

    # Network settings
    network.host: 0.0.0.0
    http.port: 9200
    transport.port: 9300

    # Discovery
    discovery.seed_hosts:
      - elasticsearch-0.elasticsearch
      - elasticsearch-1.elasticsearch
      - elasticsearch-2.elasticsearch
    cluster.initial_master_nodes:
      - elasticsearch-0
      - elasticsearch-1
      - elasticsearch-2

    # Security settings
    xpack.security.enabled: true
    xpack.security.enrollment.enabled: true

    xpack.security.transport.ssl:
      enabled: true
      verification_mode: certificate
      keystore.path: certs/transport.p12
      truststore.path: certs/transport.p12

    xpack.security.http.ssl:
      enabled: true
      keystore.path: certs/http.p12

    # Audit logging
    xpack.security.audit.enabled: true
    xpack.security.audit.logfile.events.include:
      - access_granted
      - access_denied
      - anonymous_access_denied
      - authentication_failed
      - connection_denied
      - tampered_request
      - run_as_denied
      - run_as_granted

    # Index lifecycle management
    xpack.ilm.enabled: true
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: elasticsearch
  namespace: security
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
      securityContext:
        fsGroup: 1000
      initContainers:
      - name: fix-permissions
        image: busybox:1.35
        command: ["sh", "-c", "chown -R 1000:1000 /usr/share/elasticsearch/data"]
        volumeMounts:
        - name: data
          mountPath: /usr/share/elasticsearch/data
      - name: increase-vm-max-map
        image: busybox:1.35
        command: ["sysctl", "-w", "vm.max_map_count=262144"]
        securityContext:
          privileged: true
      containers:
      - name: elasticsearch
        image: docker.elastic.co/elasticsearch/elasticsearch:8.11.0
        resources:
          requests:
            memory: "4Gi"
            cpu: "1000m"
          limits:
            memory: "8Gi"
            cpu: "2000m"
        ports:
        - containerPort: 9200
          name: http
        - containerPort: 9300
          name: transport
        env:
        - name: ES_JAVA_OPTS
          value: "-Xms4g -Xmx4g"
        - name: ELASTIC_PASSWORD
          valueFrom:
            secretKeyRef:
              name: elasticsearch-credentials
              key: password
        volumeMounts:
        - name: data
          mountPath: /usr/share/elasticsearch/data
        - name: config
          mountPath: /usr/share/elasticsearch/config/elasticsearch.yml
          subPath: elasticsearch.yml
        - name: certs
          mountPath: /usr/share/elasticsearch/config/certs
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: fast-ssd
      resources:
        requests:
          storage: 500Gi
```

### Logstash Security Pipeline

```ruby
# logstash-security-pipeline.conf
input {
  # Beats input for Filebeat/Winlogbeat
  beats {
    port => 5044
    ssl => true
    ssl_certificate => "/etc/logstash/certs/logstash.crt"
    ssl_key => "/etc/logstash/certs/logstash.key"
  }

  # Kafka input for high-volume logs
  kafka {
    bootstrap_servers => "kafka:9092"
    topics => ["security-logs", "audit-logs", "network-logs"]
    group_id => "logstash-security"
    codec => json
    security_protocol => "SSL"
    ssl_truststore_location => "/etc/logstash/certs/truststore.jks"
    ssl_truststore_password => "${TRUSTSTORE_PASSWORD}"
  }

  # Syslog input
  syslog {
    port => 5514
    type => "syslog"
  }
}

filter {
  # Parse common log formats
  if [type] == "syslog" {
    grok {
      match => {
        "message" => [
          "%{SYSLOGTIMESTAMP:timestamp} %{SYSLOGHOST:hostname} %{DATA:program}(?:\[%{POSINT:pid}\])?: %{GREEDYDATA:message}",
          "%{TIMESTAMP_ISO8601:timestamp} %{SYSLOGHOST:hostname} %{DATA:program}: %{GREEDYDATA:message}"
        ]
      }
      overwrite => ["message"]
    }

    date {
      match => ["timestamp", "MMM  d HH:mm:ss", "MMM dd HH:mm:ss", "ISO8601"]
      target => "@timestamp"
    }
  }

  # Enrich with GeoIP for network events
  if [source_ip] {
    geoip {
      source => "source_ip"
      target => "source_geo"
      database => "/etc/logstash/GeoLite2-City.mmdb"
    }

    # Check against threat intelligence
    translate {
      field => "source_ip"
      destination => "threat_intel"
      dictionary_path => "/etc/logstash/threat-feeds/malicious-ips.yml"
      fallback => "clean"
    }
  }

  # Parse AWS CloudTrail logs
  if [eventSource] {
    mutate {
      add_field => { "log_type" => "cloudtrail" }
    }

    # Extract user identity
    if [userIdentity] {
      mutate {
        add_field => {
          "user_type" => "%{[userIdentity][type]}"
          "user_arn" => "%{[userIdentity][arn]}"
        }
      }
    }

    # Flag sensitive actions
    if [eventName] in ["ConsoleLogin", "CreateUser", "DeleteUser", "AttachUserPolicy",
                        "CreateAccessKey", "UpdateLoginProfile", "PutBucketPolicy",
                        "AuthorizeSecurityGroupIngress", "CreateKeyPair"] {
      mutate {
        add_tag => ["sensitive_action"]
        add_field => { "alert_priority" => "high" }
      }
    }
  }

  # Parse Kubernetes audit logs
  if [kind] == "Event" and [apiVersion] =~ /^audit/ {
    mutate {
      add_field => { "log_type" => "kubernetes_audit" }
    }

    # Extract key fields
    mutate {
      add_field => {
        "k8s_verb" => "%{[verb]}"
        "k8s_user" => "%{[user][username]}"
        "k8s_resource" => "%{[objectRef][resource]}"
        "k8s_namespace" => "%{[objectRef][namespace]}"
      }
    }

    # Flag sensitive operations
    if [verb] in ["delete", "deletecollection"] and
       [objectRef][resource] in ["secrets", "configmaps", "deployments", "clusterroles"] {
      mutate {
        add_tag => ["k8s_sensitive_delete"]
        add_field => { "alert_priority" => "high" }
      }
    }
  }

  # Parse authentication events
  if [event_type] == "authentication" {
    # Detect brute force attempts
    aggregate {
      task_id => "%{source_ip}-%{username}"
      code => "
        map['failed_attempts'] ||= 0
        map['failed_attempts'] += 1 if event.get('status') == 'failed'
        event.set('failed_attempts_count', map['failed_attempts'])
      "
      push_map_as_event_on_timeout => true
      timeout => 300
      timeout_tags => ['aggregated_auth']
    }

    if [failed_attempts_count] and [failed_attempts_count] > 5 {
      mutate {
        add_tag => ["brute_force_attempt"]
        add_field => { "alert_priority" => "critical" }
      }
    }
  }

  # Normalize fields to ECS (Elastic Common Schema)
  mutate {
    rename => {
      "src_ip" => "[source][ip]"
      "dst_ip" => "[destination][ip]"
      "src_port" => "[source][port]"
      "dst_port" => "[destination][port]"
      "username" => "[user][name]"
      "hostname" => "[host][name]"
    }
  }

  # Add processing metadata
  mutate {
    add_field => {
      "[@metadata][pipeline_version]" => "2.0"
      "[@metadata][processed_at]" => "%{+ISO8601}"
    }
  }
}

output {
  # Route to appropriate indices
  if "sensitive_action" in [tags] or "brute_force_attempt" in [tags] {
    elasticsearch {
      hosts => ["https://elasticsearch:9200"]
      index => "security-alerts-%{+YYYY.MM.dd}"
      ssl => true
      cacert => "/etc/logstash/certs/ca.crt"
      user => "logstash_writer"
      password => "${ELASTICSEARCH_PASSWORD}"
    }

    # Send high-priority alerts to PagerDuty
    http {
      url => "https://events.pagerduty.com/v2/enqueue"
      http_method => "post"
      format => "json"
      content_type => "application/json"
      mapping => {
        "routing_key" => "${PAGERDUTY_KEY}"
        "event_action" => "trigger"
        "payload" => {
          "summary" => "Security Alert: %{[alert_priority]} - %{[tags]}"
          "source" => "%{[host][name]}"
          "severity" => "critical"
        }
      }
    }
  }

  elasticsearch {
    hosts => ["https://elasticsearch:9200"]
    index => "logs-%{[log_type]}-%{+YYYY.MM.dd}"
    ssl => true
    cacert => "/etc/logstash/certs/ca.crt"
    user => "logstash_writer"
    password => "${ELASTICSEARCH_PASSWORD}"
    ilm_enabled => true
    ilm_rollover_alias => "logs"
    ilm_policy => "security-logs-policy"
  }
}
```

### Wazuh SIEM/XDR Deployment

```yaml
# wazuh-manager.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: wazuh-manager
  namespace: security
spec:
  serviceName: wazuh
  replicas: 1
  selector:
    matchLabels:
      app: wazuh-manager
  template:
    metadata:
      labels:
        app: wazuh-manager
    spec:
      containers:
      - name: wazuh-manager
        image: wazuh/wazuh-manager:4.7.0
        ports:
        - containerPort: 1514
          name: agents
        - containerPort: 1515
          name: cluster
        - containerPort: 55000
          name: api
        env:
        - name: WAZUH_MANAGER_NAME
          value: "wazuh-manager"
        - name: INDEXER_URL
          value: "https://wazuh-indexer:9200"
        - name: INDEXER_USERNAME
          value: "admin"
        - name: INDEXER_PASSWORD
          valueFrom:
            secretKeyRef:
              name: wazuh-credentials
              key: indexer-password
        - name: API_USERNAME
          value: "wazuh-wui"
        - name: API_PASSWORD
          valueFrom:
            secretKeyRef:
              name: wazuh-credentials
              key: api-password
        volumeMounts:
        - name: wazuh-config
          mountPath: /var/ossec/etc/ossec.conf
          subPath: ossec.conf
        - name: wazuh-rules
          mountPath: /var/ossec/etc/rules/local_rules.xml
          subPath: local_rules.xml
        - name: wazuh-data
          mountPath: /var/ossec/data
        resources:
          requests:
            memory: "2Gi"
            cpu: "1000m"
          limits:
            memory: "4Gi"
            cpu: "2000m"
      volumes:
      - name: wazuh-config
        configMap:
          name: wazuh-manager-config
      - name: wazuh-rules
        configMap:
          name: wazuh-custom-rules
  volumeClaimTemplates:
  - metadata:
      name: wazuh-data
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: standard
      resources:
        requests:
          storage: 100Gi
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: wazuh-manager-config
  namespace: security
data:
  ossec.conf: |
    <ossec_config>
      <global>
        <jsonout_output>yes</jsonout_output>
        <alerts_log>yes</alerts_log>
        <logall>no</logall>
        <logall_json>no</logall_json>
        <email_notification>yes</email_notification>
        <smtp_server>smtp.company.com</smtp_server>
        <email_from>wazuh@company.com</email_from>
        <email_to>security-team@company.com</email_to>
        <email_maxperhour>12</email_maxperhour>
      </global>

      <alerts>
        <log_alert_level>3</log_alert_level>
        <email_alert_level>12</email_alert_level>
      </alerts>

      <!-- Vulnerability detection -->
      <vulnerability-detection>
        <enabled>yes</enabled>
        <index-status>yes</index-status>
        <feed-update-interval>60m</feed-update-interval>
      </vulnerability-detection>

      <!-- File integrity monitoring -->
      <syscheck>
        <disabled>no</disabled>
        <frequency>43200</frequency>
        <scan_on_start>yes</scan_on_start>

        <directories check_all="yes" realtime="yes">/etc,/usr/bin,/usr/sbin</directories>
        <directories check_all="yes" realtime="yes">/bin,/sbin</directories>
        <directories check_all="yes">/var/ossec/etc</directories>

        <ignore>/etc/mtab</ignore>
        <ignore>/etc/hosts.deny</ignore>
        <ignore>/etc/mail/statistics</ignore>
        <ignore>/etc/random-seed</ignore>
        <ignore>/etc/adjtime</ignore>

        <nodiff>/etc/ssl/private.key</nodiff>
      </syscheck>

      <!-- Rootkit detection -->
      <rootcheck>
        <disabled>no</disabled>
        <check_files>yes</check_files>
        <check_trojans>yes</check_trojans>
        <check_dev>yes</check_dev>
        <check_sys>yes</check_sys>
        <check_pids>yes</check_pids>
        <check_ports>yes</check_ports>
        <check_if>yes</check_if>
        <frequency>43200</frequency>
      </rootcheck>

      <!-- Active response -->
      <active-response>
        <command>firewall-drop</command>
        <location>local</location>
        <rules_id>5712</rules_id>
        <timeout>1800</timeout>
      </active-response>

      <!-- AWS integration -->
      <wodle name="aws-s3">
        <disabled>no</disabled>
        <interval>10m</interval>
        <run_on_start>yes</run_on_start>
        <bucket type="cloudtrail">
          <name>company-cloudtrail-logs</name>
          <aws_profile>default</aws_profile>
        </bucket>
        <bucket type="guardduty">
          <name>company-guardduty-logs</name>
          <aws_profile>default</aws_profile>
        </bucket>
      </wodle>

      <!-- Docker monitoring -->
      <wodle name="docker-listener">
        <disabled>no</disabled>
      </wodle>

      <indexer>
        <enabled>yes</enabled>
        <hosts>
          <host>https://wazuh-indexer:9200</host>
        </hosts>
        <ssl>
          <certificate_authorities>
            <ca>/var/ossec/etc/ssl/root-ca.pem</ca>
          </certificate_authorities>
        </ssl>
      </indexer>
    </ossec_config>
```

### Custom Detection Rules

```xml
<!-- wazuh-custom-rules/local_rules.xml -->
<group name="local,security">

  <!-- Detect SSH brute force -->
  <rule id="100001" level="10" frequency="6" timeframe="60">
    <if_matched_sid>5710</if_matched_sid>
    <description>SSH brute force attempt detected</description>
    <mitre>
      <id>T1110</id>
    </mitre>
    <group>authentication_failures,brute_force</group>
  </rule>

  <!-- Detect privilege escalation via sudo -->
  <rule id="100002" level="12">
    <if_sid>5401</if_sid>
    <match>COMMAND=/bin/bash|COMMAND=/bin/sh</match>
    <description>Possible privilege escalation - shell spawned via sudo</description>
    <mitre>
      <id>T1548.003</id>
    </mitre>
    <group>privilege_escalation</group>
  </rule>

  <!-- Detect suspicious process execution -->
  <rule id="100003" level="14">
    <if_group>syslog</if_group>
    <match>nc -e|bash -i|python -c.*socket|perl -e.*socket</match>
    <description>Possible reverse shell detected</description>
    <mitre>
      <id>T1059</id>
    </mitre>
    <group>malware,reverse_shell</group>
  </rule>

  <!-- Detect cryptocurrency mining -->
  <rule id="100004" level="12">
    <if_group>syslog</if_group>
    <regex>stratum\+tcp://|xmrig|minerd|cpuminer</regex>
    <description>Cryptocurrency mining activity detected</description>
    <mitre>
      <id>T1496</id>
    </mitre>
    <group>malware,cryptomining</group>
  </rule>

  <!-- AWS CloudTrail rules -->
  <rule id="100100" level="10">
    <if_sid>80200</if_sid>
    <field name="aws.eventName">^ConsoleLogin$</field>
    <field name="aws.responseElements.ConsoleLogin">Failure</field>
    <description>AWS Console login failure</description>
    <group>aws,authentication_failed</group>
  </rule>

  <rule id="100101" level="12" frequency="5" timeframe="300">
    <if_matched_sid>100100</if_matched_sid>
    <description>Multiple AWS Console login failures - possible brute force</description>
    <mitre>
      <id>T1110</id>
    </mitre>
    <group>aws,brute_force</group>
  </rule>

  <rule id="100102" level="14">
    <if_sid>80200</if_sid>
    <field name="aws.eventName">^CreateUser$|^AttachUserPolicy$|^PutUserPolicy$</field>
    <field name="aws.userIdentity.type">^Root$</field>
    <description>AWS Root account used for IAM operations</description>
    <group>aws,privilege_escalation</group>
  </rule>

  <!-- Kubernetes audit rules -->
  <rule id="100200" level="10">
    <if_group>kubernetes</if_group>
    <field name="kubernetes.verb">^create$</field>
    <field name="kubernetes.objectRef.resource">^pods$</field>
    <match>privileged.*true</match>
    <description>Privileged pod creation attempt</description>
    <mitre>
      <id>T1611</id>
    </mitre>
    <group>kubernetes,container_escape</group>
  </rule>

  <rule id="100201" level="12">
    <if_group>kubernetes</if_group>
    <field name="kubernetes.verb">^create$|^patch$</field>
    <field name="kubernetes.objectRef.resource">^clusterrolebindings$|^rolebindings$</field>
    <description>Kubernetes RBAC modification detected</description>
    <group>kubernetes,privilege_escalation</group>
  </rule>

  <rule id="100202" level="14">
    <if_group>kubernetes</if_group>
    <field name="kubernetes.verb">^exec$</field>
    <field name="kubernetes.objectRef.namespace">^kube-system$</field>
    <description>Exec into kube-system namespace pod</description>
    <group>kubernetes,lateral_movement</group>
  </rule>

  <!-- File integrity monitoring rules -->
  <rule id="100300" level="12">
    <if_sid>550,553</if_sid>
    <match>/etc/passwd|/etc/shadow|/etc/sudoers</match>
    <description>Critical authentication file modified</description>
    <mitre>
      <id>T1136</id>
    </mitre>
    <group>fim,account_manipulation</group>
  </rule>

  <rule id="100301" level="14">
    <if_sid>554</if_sid>
    <match>/usr/bin/|/usr/sbin/|/bin/|/sbin/</match>
    <description>System binary added - possible trojan</description>
    <mitre>
      <id>T1554</id>
    </mitre>
    <group>fim,malware</group>
  </rule>

</group>
```

## Security Alerting and Correlation

### Elasticsearch Detection Rules

```json
// security-detection-rules.json
{
  "rules": [
    {
      "name": "Brute Force Attack Detection",
      "description": "Detects multiple failed authentication attempts from single source",
      "risk_score": 73,
      "severity": "high",
      "type": "threshold",
      "query": "event.category:authentication AND event.outcome:failure",
      "threshold": {
        "field": ["source.ip"],
        "value": 10,
        "cardinality": [
          {
            "field": "user.name",
            "value": 3
          }
        ]
      },
      "index": ["logs-*", "security-*"],
      "interval": "5m",
      "from": "now-5m",
      "to": "now",
      "actions": [
        {
          "action_type_id": ".pagerduty",
          "params": {
            "severity": "critical",
            "eventAction": "trigger",
            "summary": "Brute force attack detected from {{context.source.ip}}"
          }
        }
      ],
      "tags": ["Brute Force", "Credential Access", "T1110"],
      "threat": [
        {
          "framework": "MITRE ATT&CK",
          "tactic": {
            "id": "TA0006",
            "name": "Credential Access"
          },
          "technique": [
            {
              "id": "T1110",
              "name": "Brute Force"
            }
          ]
        }
      ]
    },
    {
      "name": "Suspicious PowerShell Execution",
      "description": "Detects potentially malicious PowerShell commands",
      "risk_score": 47,
      "severity": "medium",
      "type": "query",
      "query": "process.name:powershell.exe AND (process.command_line:(*-enc* OR *-encodedcommand* OR *downloadstring* OR *invoke-expression* OR *iex* OR *invoke-webrequest* OR *Net.WebClient*))",
      "index": ["winlogbeat-*", "logs-endpoint*"],
      "interval": "5m",
      "from": "now-5m",
      "to": "now",
      "tags": ["Defense Evasion", "Execution", "T1059.001"],
      "threat": [
        {
          "framework": "MITRE ATT&CK",
          "tactic": {
            "id": "TA0002",
            "name": "Execution"
          },
          "technique": [
            {
              "id": "T1059.001",
              "name": "PowerShell"
            }
          ]
        }
      ]
    },
    {
      "name": "AWS Root Account Activity",
      "description": "Detects any activity using the AWS root account",
      "risk_score": 73,
      "severity": "high",
      "type": "query",
      "query": "event.provider:cloudtrail AND aws.cloudtrail.user_identity.type:Root AND NOT event.action:ConsoleLogin",
      "index": ["logs-aws*", "cloudtrail-*"],
      "interval": "5m",
      "from": "now-5m",
      "to": "now",
      "tags": ["AWS", "Privilege Escalation", "T1078.004"],
      "threat": [
        {
          "framework": "MITRE ATT&CK",
          "tactic": {
            "id": "TA0004",
            "name": "Privilege Escalation"
          },
          "technique": [
            {
              "id": "T1078.004",
              "name": "Cloud Accounts"
            }
          ]
        }
      ]
    },
    {
      "name": "Kubernetes Secret Access from Unexpected Pod",
      "description": "Detects access to secrets from pods not in allow list",
      "risk_score": 50,
      "severity": "medium",
      "type": "eql",
      "language": "eql",
      "query": "any where kubernetes.audit.verb == \"get\" and kubernetes.audit.objectRef.resource == \"secrets\" and not kubernetes.audit.user.username in (\"system:serviceaccount:kube-system:*\", \"system:serviceaccount:vault:*\")",
      "index": ["logs-kubernetes*"],
      "interval": "5m",
      "from": "now-5m",
      "to": "now",
      "tags": ["Kubernetes", "Credential Access", "T1552.007"]
    },
    {
      "name": "Data Exfiltration via DNS",
      "description": "Detects potential DNS tunneling or data exfiltration",
      "risk_score": 73,
      "severity": "high",
      "type": "threshold",
      "query": "network.protocol:dns AND dns.question.type:TXT AND dns.question.name:*.*.*.*",
      "threshold": {
        "field": ["source.ip"],
        "value": 100
      },
      "index": ["packetbeat-*", "logs-network*"],
      "interval": "5m",
      "from": "now-5m",
      "to": "now",
      "tags": ["Exfiltration", "C2", "T1048"]
    }
  ]
}
```

### Alert Correlation with Sigma Rules

```yaml
# sigma-rules/credential-access/brute-force-ssh.yml
title: SSH Brute Force Attack
id: a1b2c3d4-e5f6-7890-abcd-ef1234567890
status: production
description: Detects multiple failed SSH authentication attempts
references:
  - https://attack.mitre.org/techniques/T1110/
author: Security Team
date: 2024/01/15
modified: 2024/06/01
tags:
  - attack.credential_access
  - attack.t1110.001
logsource:
  product: linux
  service: sshd
detection:
  selection:
    - syslog_identifier: sshd
    - process.name: sshd
  keywords:
    - 'Failed password'
    - 'authentication failure'
    - 'Invalid user'
  condition: selection and keywords
  timeframe: 5m
  count:
    field: source.ip
    gte: 10
falsepositives:
  - Users mistyping passwords
  - Automated systems with expired credentials
level: high
---
# sigma-rules/privilege-escalation/sudo-to-root.yml
title: Sudo Privilege Escalation to Root Shell
id: b2c3d4e5-f6a7-8901-bcde-f2345678901a
status: production
description: Detects sudo commands that spawn interactive root shells
references:
  - https://attack.mitre.org/techniques/T1548/003/
author: Security Team
date: 2024/01/15
tags:
  - attack.privilege_escalation
  - attack.t1548.003
logsource:
  product: linux
  service: sudo
detection:
  selection:
    - process.name: sudo
    - syslog_identifier: sudo
  shell_commands:
    process.command_line|contains:
      - '/bin/bash'
      - '/bin/sh'
      - '/bin/zsh'
      - '-i'
      - '--login'
  condition: selection and shell_commands
falsepositives:
  - Legitimate administrative activities
level: high
---
# sigma-rules/defense-evasion/container-escape.yml
title: Container Escape Attempt
id: c3d4e5f6-a7b8-9012-cdef-34567890123b
status: production
description: Detects potential container escape techniques
author: Security Team
date: 2024/01/15
tags:
  - attack.privilege_escalation
  - attack.t1611
logsource:
  product: kubernetes
  service: audit
detection:
  privileged_pod:
    kubernetes.audit.verb: create
    kubernetes.audit.objectRef.resource: pods
    kubernetes.audit.requestObject|contains: '"privileged":true'
  hostpath_mount:
    kubernetes.audit.verb: create
    kubernetes.audit.objectRef.resource: pods
    kubernetes.audit.requestObject|contains:
      - 'hostPath'
      - '/var/run/docker.sock'
      - '/proc'
  hostpid:
    kubernetes.audit.verb: create
    kubernetes.audit.objectRef.resource: pods
    kubernetes.audit.requestObject|contains: '"hostPID":true'
  condition: privileged_pod or hostpath_mount or hostpid
level: critical
```

### Sigma to Elasticsearch Converter

```python
#!/usr/bin/env python3
# sigma_to_elastic.py - Convert Sigma rules to Elasticsearch queries

import yaml
import json
from pathlib import Path
from typing import Dict, List, Any

class SigmaToElastic:
    def __init__(self):
        self.field_mappings = {
            'source.ip': 'source.ip',
            'destination.ip': 'destination.ip',
            'process.name': 'process.name',
            'process.command_line': 'process.command_line',
            'user.name': 'user.name',
            'event.action': 'event.action',
            'syslog_identifier': 'systemd.unit',
        }

    def convert_rule(self, sigma_rule: Dict[str, Any]) -> Dict[str, Any]:
        """Convert a Sigma rule to Elasticsearch detection rule format."""
        elastic_rule = {
            'name': sigma_rule.get('title', 'Untitled Rule'),
            'description': sigma_rule.get('description', ''),
            'risk_score': self._level_to_score(sigma_rule.get('level', 'medium')),
            'severity': sigma_rule.get('level', 'medium'),
            'type': 'query',
            'query': self._build_query(sigma_rule.get('detection', {})),
            'index': self._get_index_pattern(sigma_rule.get('logsource', {})),
            'interval': '5m',
            'from': 'now-5m',
            'to': 'now',
            'tags': sigma_rule.get('tags', []),
            'references': sigma_rule.get('references', []),
            'author': sigma_rule.get('author', 'Unknown'),
            'version': 1,
            'enabled': True,
        }

        # Add MITRE ATT&CK mapping
        if 'tags' in sigma_rule:
            elastic_rule['threat'] = self._map_mitre_tags(sigma_rule['tags'])

        # Handle threshold rules
        if 'count' in sigma_rule.get('detection', {}):
            elastic_rule['type'] = 'threshold'
            elastic_rule['threshold'] = {
                'field': [sigma_rule['detection']['count'].get('field', '')],
                'value': sigma_rule['detection']['count'].get('gte', 10)
            }

        return elastic_rule

    def _build_query(self, detection: Dict[str, Any]) -> str:
        """Build Elasticsearch query from Sigma detection logic."""
        conditions = []

        for key, value in detection.items():
            if key in ['condition', 'timeframe', 'count']:
                continue

            if isinstance(value, dict):
                for field, patterns in value.items():
                    if '|contains' in field:
                        base_field = field.replace('|contains', '')
                        mapped_field = self.field_mappings.get(base_field, base_field)
                        if isinstance(patterns, list):
                            pattern_conditions = [f'{mapped_field}:*{p}*' for p in patterns]
                            conditions.append(f"({' OR '.join(pattern_conditions)})")
                        else:
                            conditions.append(f'{mapped_field}:*{patterns}*')
                    else:
                        mapped_field = self.field_mappings.get(field, field)
                        if isinstance(patterns, list):
                            pattern_conditions = [f'{mapped_field}:{p}' for p in patterns]
                            conditions.append(f"({' OR '.join(pattern_conditions)})")
                        else:
                            conditions.append(f'{mapped_field}:{patterns}')
            elif isinstance(value, list):
                # Keywords list
                keyword_conditions = [f'message:*{kw}*' for kw in value]
                conditions.append(f"({' OR '.join(keyword_conditions)})")

        return ' AND '.join(conditions)

    def _level_to_score(self, level: str) -> int:
        """Convert Sigma level to Elasticsearch risk score."""
        mapping = {
            'informational': 21,
            'low': 47,
            'medium': 50,
            'high': 73,
            'critical': 99
        }
        return mapping.get(level.lower(), 50)

    def _get_index_pattern(self, logsource: Dict[str, Any]) -> List[str]:
        """Determine Elasticsearch index pattern from logsource."""
        product = logsource.get('product', '')
        service = logsource.get('service', '')

        patterns = {
            'linux': ['logs-linux*', 'filebeat-*'],
            'windows': ['winlogbeat-*', 'logs-windows*'],
            'kubernetes': ['logs-kubernetes*'],
            'aws': ['logs-aws*', 'cloudtrail-*'],
        }

        return patterns.get(product, ['logs-*'])

    def _map_mitre_tags(self, tags: List[str]) -> List[Dict[str, Any]]:
        """Map Sigma tags to MITRE ATT&CK format."""
        threats = []

        tactic_mapping = {
            'attack.initial_access': ('TA0001', 'Initial Access'),
            'attack.execution': ('TA0002', 'Execution'),
            'attack.persistence': ('TA0003', 'Persistence'),
            'attack.privilege_escalation': ('TA0004', 'Privilege Escalation'),
            'attack.defense_evasion': ('TA0005', 'Defense Evasion'),
            'attack.credential_access': ('TA0006', 'Credential Access'),
            'attack.discovery': ('TA0007', 'Discovery'),
            'attack.lateral_movement': ('TA0008', 'Lateral Movement'),
            'attack.collection': ('TA0009', 'Collection'),
            'attack.exfiltration': ('TA0010', 'Exfiltration'),
            'attack.impact': ('TA0040', 'Impact'),
        }

        for tag in tags:
            if tag.startswith('attack.t'):
                # This is a technique ID
                technique_id = tag.replace('attack.', '').upper()
                # Find associated tactic
                for tactic_tag in tags:
                    if tactic_tag in tactic_mapping:
                        tactic_id, tactic_name = tactic_mapping[tactic_tag]
                        threats.append({
                            'framework': 'MITRE ATT&CK',
                            'tactic': {'id': tactic_id, 'name': tactic_name},
                            'technique': [{'id': technique_id, 'name': technique_id}]
                        })
                        break

        return threats

    def convert_directory(self, sigma_dir: Path, output_file: Path):
        """Convert all Sigma rules in a directory."""
        rules = []

        for sigma_file in sigma_dir.rglob('*.yml'):
            with open(sigma_file) as f:
                # Handle multi-document YAML
                for doc in yaml.safe_load_all(f):
                    if doc and 'title' in doc:
                        rules.append(self.convert_rule(doc))

        with open(output_file, 'w') as f:
            json.dump({'rules': rules}, f, indent=2)

        print(f"Converted {len(rules)} rules to {output_file}")


if __name__ == '__main__':
    import argparse

    parser = argparse.ArgumentParser(description='Convert Sigma rules to Elasticsearch')
    parser.add_argument('sigma_dir', type=Path, help='Directory containing Sigma rules')
    parser.add_argument('output', type=Path, help='Output JSON file')
    args = parser.parse_args()

    converter = SigmaToElastic()
    converter.convert_directory(args.sigma_dir, args.output)
```

## Security Dashboards

### Kibana Security Dashboard

```json
// kibana-security-dashboard.ndjson
{
  "attributes": {
    "title": "Security Operations Dashboard",
    "description": "Comprehensive security monitoring dashboard",
    "panelsJSON": [
      {
        "gridData": {"x": 0, "y": 0, "w": 12, "h": 8},
        "type": "lens",
        "title": "Security Alerts Over Time",
        "embeddableConfig": {
          "attributes": {
            "visualizationType": "lnsXY",
            "state": {
              "datasourceStates": {
                "indexpattern": {
                  "layers": {
                    "layer1": {
                      "columns": {
                        "timestamp": {
                          "dataType": "date",
                          "operationType": "date_histogram",
                          "sourceField": "@timestamp",
                          "params": {"interval": "1h"}
                        },
                        "count": {
                          "dataType": "number",
                          "operationType": "count"
                        },
                        "severity": {
                          "dataType": "string",
                          "operationType": "terms",
                          "sourceField": "alert.severity"
                        }
                      }
                    }
                  }
                }
              },
              "visualization": {
                "layers": [{
                  "layerId": "layer1",
                  "seriesType": "bar_stacked",
                  "xAccessor": "timestamp",
                  "accessors": ["count"],
                  "splitAccessor": "severity"
                }]
              }
            }
          }
        }
      },
      {
        "gridData": {"x": 12, "y": 0, "w": 12, "h": 8},
        "type": "lens",
        "title": "Top Attack Sources (GeoIP)",
        "embeddableConfig": {
          "attributes": {
            "visualizationType": "lnsChoropleth",
            "state": {
              "datasourceStates": {
                "indexpattern": {
                  "layers": {
                    "layer1": {
                      "columns": {
                        "country": {
                          "dataType": "string",
                          "operationType": "terms",
                          "sourceField": "source.geo.country_iso_code",
                          "params": {"size": 50}
                        },
                        "count": {
                          "dataType": "number",
                          "operationType": "count"
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      },
      {
        "gridData": {"x": 0, "y": 8, "w": 8, "h": 8},
        "type": "lens",
        "title": "Failed Authentication by User",
        "embeddableConfig": {
          "attributes": {
            "visualizationType": "lnsPie",
            "state": {
              "datasourceStates": {
                "indexpattern": {
                  "layers": {
                    "layer1": {
                      "columns": {
                        "user": {
                          "dataType": "string",
                          "operationType": "terms",
                          "sourceField": "user.name",
                          "params": {"size": 10}
                        },
                        "count": {
                          "dataType": "number",
                          "operationType": "count"
                        }
                      }
                    }
                  }
                }
              },
              "query": {
                "query": "event.category:authentication AND event.outcome:failure",
                "language": "kuery"
              }
            }
          }
        }
      },
      {
        "gridData": {"x": 8, "y": 8, "w": 8, "h": 8},
        "type": "lens",
        "title": "MITRE ATT&CK Techniques",
        "embeddableConfig": {
          "attributes": {
            "visualizationType": "lnsHeatmap",
            "state": {
              "datasourceStates": {
                "indexpattern": {
                  "layers": {
                    "layer1": {
                      "columns": {
                        "tactic": {
                          "dataType": "string",
                          "operationType": "terms",
                          "sourceField": "threat.tactic.name",
                          "params": {"size": 15}
                        },
                        "technique": {
                          "dataType": "string",
                          "operationType": "terms",
                          "sourceField": "threat.technique.name",
                          "params": {"size": 20}
                        },
                        "count": {
                          "dataType": "number",
                          "operationType": "count"
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      },
      {
        "gridData": {"x": 16, "y": 8, "w": 8, "h": 8},
        "type": "lens",
        "title": "AWS API Calls by Service",
        "embeddableConfig": {
          "attributes": {
            "visualizationType": "lnsTagcloud",
            "state": {
              "datasourceStates": {
                "indexpattern": {
                  "layers": {
                    "layer1": {
                      "columns": {
                        "service": {
                          "dataType": "string",
                          "operationType": "terms",
                          "sourceField": "aws.cloudtrail.event_source",
                          "params": {"size": 25}
                        },
                        "count": {
                          "dataType": "number",
                          "operationType": "count"
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    ],
    "timeRestore": true,
    "timeTo": "now",
    "timeFrom": "now-24h",
    "refreshInterval": {
      "pause": false,
      "value": 60000
    }
  },
  "type": "dashboard"
}
```

### Grafana Security Dashboard

```json
{
  "dashboard": {
    "title": "Security Monitoring Dashboard",
    "uid": "security-ops",
    "tags": ["security", "siem"],
    "timezone": "browser",
    "refresh": "30s",
    "panels": [
      {
        "title": "Security Alert Rate",
        "type": "stat",
        "gridPos": {"x": 0, "y": 0, "w": 6, "h": 4},
        "targets": [
          {
            "expr": "sum(rate(security_alerts_total[5m]))",
            "legendFormat": "Alerts/sec"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "thresholds": {
              "steps": [
                {"color": "green", "value": null},
                {"color": "yellow", "value": 0.1},
                {"color": "red", "value": 1}
              ]
            }
          }
        }
      },
      {
        "title": "Critical Alerts (24h)",
        "type": "stat",
        "gridPos": {"x": 6, "y": 0, "w": 6, "h": 4},
        "targets": [
          {
            "expr": "sum(increase(security_alerts_total{severity=\"critical\"}[24h]))",
            "legendFormat": "Critical"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "color": {"mode": "thresholds"},
            "thresholds": {
              "steps": [
                {"color": "green", "value": null},
                {"color": "red", "value": 1}
              ]
            }
          }
        }
      },
      {
        "title": "Mean Time to Detect (MTTD)",
        "type": "stat",
        "gridPos": {"x": 12, "y": 0, "w": 6, "h": 4},
        "targets": [
          {
            "expr": "avg(security_incident_detection_time_seconds)",
            "legendFormat": "MTTD"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "s",
            "thresholds": {
              "steps": [
                {"color": "green", "value": null},
                {"color": "yellow", "value": 300},
                {"color": "red", "value": 900}
              ]
            }
          }
        }
      },
      {
        "title": "Alerts by Severity",
        "type": "timeseries",
        "gridPos": {"x": 0, "y": 4, "w": 12, "h": 8},
        "targets": [
          {
            "expr": "sum by (severity) (rate(security_alerts_total[5m]))",
            "legendFormat": "{{severity}}"
          }
        ],
        "fieldConfig": {
          "overrides": [
            {"matcher": {"id": "byName", "options": "critical"}, "properties": [{"id": "color", "value": {"fixedColor": "red", "mode": "fixed"}}]},
            {"matcher": {"id": "byName", "options": "high"}, "properties": [{"id": "color", "value": {"fixedColor": "orange", "mode": "fixed"}}]},
            {"matcher": {"id": "byName", "options": "medium"}, "properties": [{"id": "color", "value": {"fixedColor": "yellow", "mode": "fixed"}}]},
            {"matcher": {"id": "byName", "options": "low"}, "properties": [{"id": "color", "value": {"fixedColor": "green", "mode": "fixed"}}]}
          ]
        }
      },
      {
        "title": "Top Attack Vectors",
        "type": "piechart",
        "gridPos": {"x": 12, "y": 4, "w": 12, "h": 8},
        "targets": [
          {
            "expr": "topk(10, sum by (attack_type) (security_alerts_total))",
            "legendFormat": "{{attack_type}}"
          }
        ]
      },
      {
        "title": "Authentication Failures",
        "type": "timeseries",
        "gridPos": {"x": 0, "y": 12, "w": 12, "h": 8},
        "targets": [
          {
            "expr": "sum by (service) (rate(auth_failures_total[5m]))",
            "legendFormat": "{{service}}"
          }
        ],
        "alert": {
          "name": "High Authentication Failures",
          "conditions": [
            {
              "evaluator": {"params": [10], "type": "gt"},
              "operator": {"type": "and"},
              "query": {"params": ["A", "5m", "now"]},
              "reducer": {"type": "avg"}
            }
          ],
          "frequency": "1m",
          "handler": 1,
          "notifications": [{"uid": "security-channel"}]
        }
      },
      {
        "title": "Suspicious Network Connections",
        "type": "table",
        "gridPos": {"x": 12, "y": 12, "w": 12, "h": 8},
        "targets": [
          {
            "expr": "topk(20, sum by (source_ip, destination_ip, destination_port) (network_suspicious_connections))",
            "format": "table",
            "instant": true
          }
        ],
        "transformations": [
          {
            "id": "organize",
            "options": {
              "renameByName": {
                "source_ip": "Source IP",
                "destination_ip": "Destination IP",
                "destination_port": "Port",
                "Value": "Connections"
              }
            }
          }
        ]
      },
      {
        "title": "Security Events Log",
        "type": "logs",
        "gridPos": {"x": 0, "y": 20, "w": 24, "h": 10},
        "datasource": "Loki",
        "targets": [
          {
            "expr": "{job=\"security\"} |= \"alert\" | json | severity=~\"critical|high\"",
            "legendFormat": ""
          }
        ],
        "options": {
          "showTime": true,
          "showLabels": true,
          "wrapLogMessage": true,
          "prettifyLogMessage": true,
          "enableLogDetails": true
        }
      }
    ]
  }
}
```

## Incident Response Integration

### Automated Incident Response

```python
#!/usr/bin/env python3
# security_incident_handler.py - Automated incident response

import json
import logging
from datetime import datetime
from typing import Dict, Any, List
from dataclasses import dataclass
from enum import Enum
import httpx
import asyncio

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class Severity(Enum):
    LOW = 1
    MEDIUM = 2
    HIGH = 3
    CRITICAL = 4

@dataclass
class SecurityAlert:
    id: str
    title: str
    description: str
    severity: Severity
    source: str
    timestamp: datetime
    indicators: Dict[str, Any]
    raw_event: Dict[str, Any]

class IncidentHandler:
    def __init__(self, config: Dict[str, Any]):
        self.config = config
        self.pagerduty_key = config.get('pagerduty_key')
        self.slack_webhook = config.get('slack_webhook')
        self.jira_config = config.get('jira')

    async def process_alert(self, alert: SecurityAlert):
        """Process incoming security alert."""
        logger.info(f"Processing alert: {alert.id} - {alert.title}")

        # Enrich alert with additional context
        enriched_alert = await self.enrich_alert(alert)

        # Determine response actions based on severity and type
        actions = self.determine_actions(enriched_alert)

        # Execute response actions
        results = await self.execute_actions(enriched_alert, actions)

        # Create incident ticket
        if alert.severity.value >= Severity.HIGH.value:
            await self.create_incident_ticket(enriched_alert, results)

        return results

    async def enrich_alert(self, alert: SecurityAlert) -> SecurityAlert:
        """Enrich alert with threat intelligence and context."""
        enrichments = {}

        # Check IP reputation
        if 'source_ip' in alert.indicators:
            ip = alert.indicators['source_ip']
            enrichments['ip_reputation'] = await self.check_ip_reputation(ip)
            enrichments['geoip'] = await self.get_geoip(ip)

        # Check file hash reputation
        if 'file_hash' in alert.indicators:
            hash_value = alert.indicators['file_hash']
            enrichments['hash_reputation'] = await self.check_hash_reputation(hash_value)

        # Get related alerts
        enrichments['related_alerts'] = await self.find_related_alerts(alert)

        alert.indicators['enrichments'] = enrichments
        return alert

    async def check_ip_reputation(self, ip: str) -> Dict[str, Any]:
        """Check IP against threat intelligence feeds."""
        async with httpx.AsyncClient() as client:
            # VirusTotal check
            try:
                response = await client.get(
                    f"https://www.virustotal.com/api/v3/ip_addresses/{ip}",
                    headers={"x-apikey": self.config.get('virustotal_key')}
                )
                if response.status_code == 200:
                    data = response.json()
                    return {
                        'malicious': data.get('data', {}).get('attributes', {}).get('last_analysis_stats', {}).get('malicious', 0),
                        'reputation': data.get('data', {}).get('attributes', {}).get('reputation', 0)
                    }
            except Exception as e:
                logger.error(f"VirusTotal lookup failed: {e}")

        return {'malicious': 0, 'reputation': 'unknown'}

    async def get_geoip(self, ip: str) -> Dict[str, Any]:
        """Get GeoIP information for IP address."""
        async with httpx.AsyncClient() as client:
            try:
                response = await client.get(f"http://ip-api.com/json/{ip}")
                if response.status_code == 200:
                    return response.json()
            except Exception as e:
                logger.error(f"GeoIP lookup failed: {e}")
        return {}

    async def check_hash_reputation(self, hash_value: str) -> Dict[str, Any]:
        """Check file hash against threat intelligence."""
        async with httpx.AsyncClient() as client:
            try:
                response = await client.get(
                    f"https://www.virustotal.com/api/v3/files/{hash_value}",
                    headers={"x-apikey": self.config.get('virustotal_key')}
                )
                if response.status_code == 200:
                    data = response.json()
                    stats = data.get('data', {}).get('attributes', {}).get('last_analysis_stats', {})
                    return {
                        'malicious': stats.get('malicious', 0),
                        'suspicious': stats.get('suspicious', 0),
                        'harmless': stats.get('harmless', 0)
                    }
            except Exception as e:
                logger.error(f"Hash reputation lookup failed: {e}")
        return {}

    async def find_related_alerts(self, alert: SecurityAlert) -> List[Dict[str, Any]]:
        """Find related alerts from the SIEM."""
        # Query Elasticsearch for related alerts
        async with httpx.AsyncClient() as client:
            query = {
                "query": {
                    "bool": {
                        "should": [
                            {"match": {"source.ip": alert.indicators.get('source_ip', '')}},
                            {"match": {"user.name": alert.indicators.get('username', '')}},
                            {"match": {"host.name": alert.indicators.get('hostname', '')}}
                        ],
                        "minimum_should_match": 1,
                        "filter": [
                            {"range": {"@timestamp": {"gte": "now-24h"}}}
                        ]
                    }
                },
                "size": 10
            }

            try:
                response = await client.post(
                    f"{self.config['elasticsearch_url']}/security-alerts-*/_search",
                    json=query,
                    auth=(self.config['elasticsearch_user'], self.config['elasticsearch_password'])
                )
                if response.status_code == 200:
                    hits = response.json().get('hits', {}).get('hits', [])
                    return [hit['_source'] for hit in hits]
            except Exception as e:
                logger.error(f"Related alerts search failed: {e}")

        return []

    def determine_actions(self, alert: SecurityAlert) -> List[str]:
        """Determine automated response actions based on alert type."""
        actions = ['notify']  # Always notify

        indicators = alert.indicators
        enrichments = indicators.get('enrichments', {})

        # Brute force - block IP if from known bad source
        if 'brute_force' in alert.title.lower():
            if enrichments.get('ip_reputation', {}).get('malicious', 0) > 0:
                actions.append('block_ip')
            actions.append('lock_account_temporarily')

        # Malware detection
        if 'malware' in alert.title.lower() or 'reverse_shell' in alert.title.lower():
            actions.append('isolate_host')
            actions.append('block_ip')
            actions.append('collect_forensics')

        # Privilege escalation
        if 'privilege' in alert.title.lower():
            actions.append('revoke_session')
            actions.append('collect_forensics')

        # Data exfiltration
        if 'exfiltration' in alert.title.lower():
            actions.append('block_ip')
            actions.append('isolate_host')
            actions.append('collect_forensics')

        # AWS root account usage
        if 'root account' in alert.title.lower():
            actions.append('notify_management')
            actions.append('enable_mfa_enforcement')

        return actions

    async def execute_actions(self, alert: SecurityAlert, actions: List[str]) -> Dict[str, Any]:
        """Execute response actions."""
        results = {}

        for action in actions:
            try:
                if action == 'notify':
                    results[action] = await self.send_notifications(alert)
                elif action == 'block_ip':
                    results[action] = await self.block_ip(alert.indicators.get('source_ip'))
                elif action == 'isolate_host':
                    results[action] = await self.isolate_host(alert.indicators.get('hostname'))
                elif action == 'lock_account_temporarily':
                    results[action] = await self.lock_account(alert.indicators.get('username'))
                elif action == 'revoke_session':
                    results[action] = await self.revoke_sessions(alert.indicators.get('username'))
                elif action == 'collect_forensics':
                    results[action] = await self.trigger_forensics(alert)
                elif action == 'notify_management':
                    results[action] = await self.notify_management(alert)

                logger.info(f"Action {action} completed: {results[action]}")
            except Exception as e:
                logger.error(f"Action {action} failed: {e}")
                results[action] = {'status': 'failed', 'error': str(e)}

        return results

    async def send_notifications(self, alert: SecurityAlert) -> Dict[str, Any]:
        """Send notifications via multiple channels."""
        results = {}

        # PagerDuty for critical/high
        if alert.severity.value >= Severity.HIGH.value and self.pagerduty_key:
            async with httpx.AsyncClient() as client:
                response = await client.post(
                    "https://events.pagerduty.com/v2/enqueue",
                    json={
                        "routing_key": self.pagerduty_key,
                        "event_action": "trigger",
                        "dedup_key": alert.id,
                        "payload": {
                            "summary": f"[{alert.severity.name}] {alert.title}",
                            "source": alert.source,
                            "severity": "critical" if alert.severity == Severity.CRITICAL else "error",
                            "timestamp": alert.timestamp.isoformat(),
                            "custom_details": alert.indicators
                        }
                    }
                )
                results['pagerduty'] = response.status_code == 202

        # Slack notification
        if self.slack_webhook:
            color = {
                Severity.LOW: "#36a64f",
                Severity.MEDIUM: "#ffc107",
                Severity.HIGH: "#ff9800",
                Severity.CRITICAL: "#dc3545"
            }.get(alert.severity, "#808080")

            async with httpx.AsyncClient() as client:
                response = await client.post(
                    self.slack_webhook,
                    json={
                        "attachments": [{
                            "color": color,
                            "title": f":rotating_light: Security Alert: {alert.title}",
                            "text": alert.description,
                            "fields": [
                                {"title": "Severity", "value": alert.severity.name, "short": True},
                                {"title": "Source", "value": alert.source, "short": True},
                                {"title": "Time", "value": alert.timestamp.isoformat(), "short": True}
                            ],
                            "footer": f"Alert ID: {alert.id}"
                        }]
                    }
                )
                results['slack'] = response.status_code == 200

        return results

    async def block_ip(self, ip: str) -> Dict[str, Any]:
        """Block IP address at firewall/WAF level."""
        if not ip:
            return {'status': 'skipped', 'reason': 'No IP provided'}

        # AWS WAF IP Set update
        async with httpx.AsyncClient() as client:
            # This would integrate with AWS WAF API to add IP to blocklist
            logger.info(f"Blocking IP {ip} in WAF")
            # Implementation would call AWS WAF UpdateIPSet API

        return {'status': 'success', 'ip': ip}

    async def isolate_host(self, hostname: str) -> Dict[str, Any]:
        """Isolate compromised host from network."""
        if not hostname:
            return {'status': 'skipped', 'reason': 'No hostname provided'}

        # This would integrate with EDR/network tools to isolate host
        logger.info(f"Isolating host {hostname}")

        return {'status': 'success', 'hostname': hostname}

    async def lock_account(self, username: str) -> Dict[str, Any]:
        """Temporarily lock user account."""
        if not username:
            return {'status': 'skipped', 'reason': 'No username provided'}

        # This would integrate with IAM/AD to lock account
        logger.info(f"Locking account {username}")

        return {'status': 'success', 'username': username, 'duration': '30m'}

    async def revoke_sessions(self, username: str) -> Dict[str, Any]:
        """Revoke all active sessions for user."""
        if not username:
            return {'status': 'skipped', 'reason': 'No username provided'}

        # This would integrate with session management to revoke sessions
        logger.info(f"Revoking sessions for {username}")

        return {'status': 'success', 'username': username}

    async def trigger_forensics(self, alert: SecurityAlert) -> Dict[str, Any]:
        """Trigger forensic data collection."""
        hostname = alert.indicators.get('hostname')

        # This would trigger automated forensic collection
        logger.info(f"Triggering forensics collection for alert {alert.id}")

        return {'status': 'initiated', 'collection_id': f"forensics-{alert.id}"}

    async def notify_management(self, alert: SecurityAlert) -> Dict[str, Any]:
        """Send notification to management for critical issues."""
        # Send email to management distribution list
        logger.info(f"Notifying management about alert {alert.id}")

        return {'status': 'success', 'notified': 'security-management@company.com'}

    async def create_incident_ticket(self, alert: SecurityAlert, response_results: Dict[str, Any]):
        """Create incident ticket in JIRA."""
        if not self.jira_config:
            return

        async with httpx.AsyncClient() as client:
            response = await client.post(
                f"{self.jira_config['url']}/rest/api/2/issue",
                auth=(self.jira_config['user'], self.jira_config['token']),
                json={
                    "fields": {
                        "project": {"key": self.jira_config['project']},
                        "summary": f"[Security Incident] {alert.title}",
                        "description": f"""
h2. Alert Details
* *Alert ID:* {alert.id}
* *Severity:* {alert.severity.name}
* *Source:* {alert.source}
* *Timestamp:* {alert.timestamp.isoformat()}

h2. Description
{alert.description}

h2. Indicators
{json.dumps(alert.indicators, indent=2)}

h2. Automated Response Actions
{json.dumps(response_results, indent=2)}
                        """,
                        "issuetype": {"name": "Security Incident"},
                        "priority": {"name": "Highest" if alert.severity == Severity.CRITICAL else "High"},
                        "labels": ["security", "automated-response", alert.severity.name.lower()]
                    }
                }
            )

            if response.status_code == 201:
                issue_key = response.json().get('key')
                logger.info(f"Created JIRA ticket: {issue_key}")
                return issue_key


# Example usage
async def main():
    config = {
        'pagerduty_key': 'your-pagerduty-routing-key',
        'slack_webhook': 'https://hooks.slack.com/services/xxx/yyy/zzz',
        'virustotal_key': 'your-virustotal-api-key',
        'elasticsearch_url': 'https://elasticsearch:9200',
        'elasticsearch_user': 'elastic',
        'elasticsearch_password': 'password',
        'jira': {
            'url': 'https://company.atlassian.net',
            'user': 'jira-bot@company.com',
            'token': 'jira-api-token',
            'project': 'SEC'
        }
    }

    handler = IncidentHandler(config)

    # Example alert
    alert = SecurityAlert(
        id='alert-12345',
        title='SSH Brute Force Attack Detected',
        description='Multiple failed SSH authentication attempts detected from single source',
        severity=Severity.HIGH,
        source='wazuh',
        timestamp=datetime.now(),
        indicators={
            'source_ip': '192.168.1.100',
            'username': 'admin',
            'hostname': 'web-server-01',
            'failed_attempts': 50
        },
        raw_event={}
    )

    results = await handler.process_alert(alert)
    print(json.dumps(results, indent=2, default=str))


if __name__ == '__main__':
    asyncio.run(main())
```

## Summary

Security monitoring and SIEM provides:
- **Centralized Visibility**: Aggregate logs and events from all sources
- **Threat Detection**: Identify malicious activities through correlation rules
- **Compliance Support**: Meet audit and regulatory requirements
- **Incident Response**: Enable rapid investigation and automated response

## References

- [Elastic Security Documentation](https://www.elastic.co/guide/en/security/current/index.html)
- [Wazuh Documentation](https://documentation.wazuh.com/)
- [Sigma Rules Repository](https://github.com/SigmaHQ/sigma)
- [MITRE ATT&CK Framework](https://attack.mitre.org/)
- [NIST Cybersecurity Framework](https://www.nist.gov/cyberframework)

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Introduction to Security Monitoring
- SIEM Architecture and Deployment
- Security Alerting and Correlation
- Security Dashboards

**The gap is not what you forgot. It is where you used a word instead of a mechanism.**

| | |
|---|---|
| ✗ | *"We scan for vulnerabilities in the pipeline."* |
| ✓ | *"SAST reads source without running it, SCA resolves the dependency tree against an advisory database, and image scanning compares installed package versions to that same database. All three report what was known at build time — which is why the registry is re-scanned: the image does not change, the database does."* |

**Trace it:** A CVE published today against your base image → a blocked deploy. Name every component between the advisory and the refused `apply`.

Stop at the first component you cannot name. Reopen this file and read **only** that.

**Go deeper — only once the gap has a name:** the [SLSA threat model](https://slsa.dev/spec/v1.2/threats) — it names every point at which a build can be subverted, and most teams defend three of them.
Full list per domain: [`SOURCES.md`](../SOURCES.md#devsecops)

→ Protocol, the three levels of knowing, and worked examples: [`MASTERY.md`](../MASTERY.md)

<!-- /feynman-check -->

# Module 11: Network Security

## Learning Objectives

By the end of this module, you will be able to:
- Design and implement secure network architectures
- Configure firewalls, WAFs, and network access controls
- Implement network segmentation and micro-segmentation
- Deploy intrusion detection and prevention systems
- Secure cloud networking (VPCs, security groups, NACLs)
- Implement zero-trust network access (ZTNA)

## Introduction to Network Security

Network security encompasses policies, practices, and tools designed to protect the integrity, confidentiality, and accessibility of computer networks and data.

### Defense in Depth Network Architecture

```yaml
# Network Security Architecture
network_security_layers:
  perimeter:
    components:
      - Edge firewalls
      - DDoS protection
      - WAF (Web Application Firewall)
      - CDN security
    purpose: First line of defense against external threats

  network:
    components:
      - Network segmentation
      - VLANs
      - ACLs and firewall rules
      - IDS/IPS
    purpose: Control traffic flow and detect threats

  host:
    components:
      - Host-based firewalls
      - Endpoint detection
      - OS hardening
    purpose: Protect individual systems

  application:
    components:
      - API gateways
      - Service mesh
      - Application-level encryption
    purpose: Secure application communications

  data:
    components:
      - Encryption at rest
      - Encryption in transit
      - Data loss prevention
    purpose: Protect sensitive data
```

## Firewall Configuration

### iptables/nftables Configuration

```bash
#!/bin/bash
# secure-firewall.sh - Production firewall configuration

# Flush existing rules
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X

# Set default policies - DROP all by default
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# Allow loopback
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# Allow established and related connections
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Rate limiting for new connections (anti-DDoS)
iptables -A INPUT -p tcp --syn -m limit --limit 1/s --limit-burst 3 -j ACCEPT
iptables -A INPUT -p tcp --syn -j DROP

# Allow SSH from specific networks only
iptables -A INPUT -p tcp --dport 22 -s 10.0.0.0/8 -m conntrack --ctstate NEW -j ACCEPT
iptables -A INPUT -p tcp --dport 22 -s 192.168.0.0/16 -m conntrack --ctstate NEW -j ACCEPT

# Allow HTTP/HTTPS
iptables -A INPUT -p tcp --dport 80 -m conntrack --ctstate NEW -j ACCEPT
iptables -A INPUT -p tcp --dport 443 -m conntrack --ctstate NEW -j ACCEPT

# Allow ICMP (ping) with rate limiting
iptables -A INPUT -p icmp --icmp-type echo-request -m limit --limit 1/s -j ACCEPT

# Log dropped packets
iptables -A INPUT -m limit --limit 5/min -j LOG --log-prefix "iptables-dropped: " --log-level 4

# Protection against common attacks
# Prevent SYN flood
iptables -A INPUT -p tcp ! --syn -m conntrack --ctstate NEW -j DROP

# Prevent NULL packets
iptables -A INPUT -p tcp --tcp-flags ALL NONE -j DROP

# Prevent XMAS packets
iptables -A INPUT -p tcp --tcp-flags ALL ALL -j DROP

# Block invalid packets
iptables -A INPUT -m conntrack --ctstate INVALID -j DROP
iptables -A FORWARD -m conntrack --ctstate INVALID -j DROP

# Prevent port scanning
iptables -A INPUT -p tcp --tcp-flags SYN,ACK,FIN,RST RST -m limit --limit 1/s -j ACCEPT

# Save rules
iptables-save > /etc/iptables/rules.v4
```

### nftables Modern Configuration

```nftables
#!/usr/sbin/nft -f
# /etc/nftables.conf - Modern firewall using nftables

flush ruleset

# Define variables
define LAN_NET = 10.0.0.0/8
define MGMT_NET = 192.168.100.0/24
define TRUSTED_DNS = { 8.8.8.8, 8.8.4.4 }

table inet filter {
    # Rate limiting set for connection tracking
    set ratelimit {
        type ipv4_addr
        flags dynamic,timeout
        timeout 1m
    }

    # Blocked IPs set
    set blocklist {
        type ipv4_addr
        flags interval
        elements = {
            192.0.2.0/24,    # Example blocked range
            198.51.100.0/24  # Example blocked range
        }
    }

    chain input {
        type filter hook input priority 0; policy drop;

        # Allow loopback
        iif "lo" accept

        # Connection tracking
        ct state established,related accept
        ct state invalid drop

        # Block known bad IPs
        ip saddr @blocklist drop

        # Rate limit new connections
        tcp flags syn limit rate 25/second burst 100 packets accept
        tcp flags syn drop

        # Allow SSH from management network
        tcp dport 22 ip saddr $MGMT_NET ct state new accept

        # Allow HTTP/HTTPS
        tcp dport { 80, 443 } ct state new accept

        # Allow DNS responses
        udp sport 53 ip saddr $TRUSTED_DNS accept

        # ICMP rate limited
        ip protocol icmp icmp type { echo-request, echo-reply } \
            limit rate 10/second accept

        # ICMPv6 for IPv6 functionality
        ip6 nexthdr icmpv6 icmpv6 type {
            echo-request, echo-reply,
            nd-neighbor-solicit, nd-neighbor-advert,
            nd-router-solicit, nd-router-advert
        } accept

        # Log drops (rate limited)
        limit rate 5/minute log prefix "nftables-drop: " level warn
    }

    chain forward {
        type filter hook forward priority 0; policy drop;

        # Allow forwarding for established connections
        ct state established,related accept

        # Allow LAN to WAN
        iif "eth1" oif "eth0" ip saddr $LAN_NET accept

        # Log drops
        limit rate 5/minute log prefix "nftables-forward-drop: "
    }

    chain output {
        type filter hook output priority 0; policy accept;

        # Allow all outbound (can be restricted if needed)
    }
}

# NAT table
table ip nat {
    chain prerouting {
        type nat hook prerouting priority -100;

        # Port forwarding examples
        tcp dport 8080 dnat to 10.0.0.10:80
        tcp dport 8443 dnat to 10.0.0.10:443
    }

    chain postrouting {
        type nat hook postrouting priority 100;

        # Masquerade outbound traffic
        oif "eth0" masquerade
    }
}
```

## Web Application Firewall (WAF)

### ModSecurity with OWASP Core Rule Set

```nginx
# /etc/nginx/modsecurity/modsecurity.conf
SecRuleEngine On
SecRequestBodyAccess On
SecRequestBodyLimit 13107200
SecRequestBodyNoFilesLimit 131072
SecRequestBodyLimitAction Reject

# Response body handling
SecResponseBodyAccess On
SecResponseBodyMimeType text/plain text/html text/xml application/json
SecResponseBodyLimit 1048576

# Audit logging
SecAuditEngine RelevantOnly
SecAuditLogRelevantStatus "^(?:5|4(?!04))"
SecAuditLogParts ABIJDEFHZ
SecAuditLogType Serial
SecAuditLog /var/log/modsec_audit.log

# Temp files
SecTmpDir /tmp/
SecDataDir /tmp/

# Include OWASP Core Rule Set
Include /etc/nginx/modsecurity/crs/crs-setup.conf
Include /etc/nginx/modsecurity/crs/rules/*.conf
```

```nginx
# /etc/nginx/modsecurity/crs/rules/CUSTOM-RULES.conf
# Custom WAF rules

# Block requests with SQL injection patterns
SecRule REQUEST_URI|ARGS|ARGS_NAMES "@rx (?i)(\b(select|insert|update|delete|drop|union|exec)\b.*\b(from|into|set|where|table)\b)" \
    "id:100001,\
    phase:2,\
    deny,\
    status:403,\
    log,\
    msg:'SQL Injection Attempt',\
    tag:'application-multi',\
    tag:'language-sql',\
    tag:'platform-multi',\
    tag:'attack-sqli',\
    severity:'CRITICAL'"

# Block XSS attempts
SecRule REQUEST_URI|ARGS|ARGS_NAMES "@rx (?i)<script[^>]*>.*</script>" \
    "id:100002,\
    phase:2,\
    deny,\
    status:403,\
    log,\
    msg:'XSS Attack Attempt',\
    tag:'application-multi',\
    tag:'attack-xss',\
    severity:'CRITICAL'"

# Block path traversal
SecRule REQUEST_URI "@rx \.\./" \
    "id:100003,\
    phase:1,\
    deny,\
    status:403,\
    log,\
    msg:'Path Traversal Attempt',\
    tag:'attack-lfi',\
    severity:'CRITICAL'"

# Rate limiting by IP
SecRule IP:REQUEST_RATE "@gt 100" \
    "id:100004,\
    phase:1,\
    deny,\
    status:429,\
    log,\
    msg:'Rate limit exceeded',\
    setvar:'IP.REQUEST_RATE=+1',\
    expirevar:'IP.REQUEST_RATE=60'"

# Block suspicious user agents
SecRule REQUEST_HEADERS:User-Agent "@rx (?i)(nikto|sqlmap|nmap|masscan|zgrab)" \
    "id:100005,\
    phase:1,\
    deny,\
    status:403,\
    log,\
    msg:'Suspicious User Agent Blocked',\
    tag:'attack-scanner',\
    severity:'WARNING'"

# API endpoint protection - require authentication header
SecRule REQUEST_URI "@beginsWith /api/" \
    "id:100006,\
    phase:1,\
    chain,\
    deny,\
    status:401,\
    log,\
    msg:'API request without authentication'"
    SecRule &REQUEST_HEADERS:Authorization "@eq 0"

# Block known bad IP ranges (example)
SecRule REMOTE_ADDR "@ipMatch 192.0.2.0/24,198.51.100.0/24" \
    "id:100007,\
    phase:1,\
    deny,\
    status:403,\
    log,\
    msg:'Blocked IP Range'"
```

### AWS WAF Configuration

```python
#!/usr/bin/env python3
# aws_waf_config.py - AWS WAF configuration via boto3

import boto3
import json
from typing import Dict, List, Any

class AWSWAFManager:
    def __init__(self, region: str = 'us-east-1'):
        self.wafv2 = boto3.client('wafv2', region_name=region)
        self.scope = 'REGIONAL'  # or 'CLOUDFRONT' for CloudFront distributions

    def create_ip_set(self, name: str, addresses: List[str], description: str = '') -> str:
        """Create IP set for blocking or allowing."""
        response = self.wafv2.create_ip_set(
            Name=name,
            Scope=self.scope,
            Description=description,
            IPAddressVersion='IPV4',
            Addresses=addresses
        )
        return response['Summary']['ARN']

    def create_regex_pattern_set(self, name: str, patterns: List[str]) -> str:
        """Create regex pattern set for matching."""
        response = self.wafv2.create_regex_pattern_set(
            Name=name,
            Scope=self.scope,
            RegularExpressionList=[{'RegexString': p} for p in patterns]
        )
        return response['Summary']['ARN']

    def create_web_acl(self, name: str, rules: List[Dict]) -> str:
        """Create Web ACL with rules."""
        response = self.wafv2.create_web_acl(
            Name=name,
            Scope=self.scope,
            DefaultAction={'Allow': {}},
            Rules=rules,
            VisibilityConfig={
                'SampledRequestsEnabled': True,
                'CloudWatchMetricsEnabled': True,
                'MetricName': f'{name}-metrics'
            }
        )
        return response['Summary']['ARN']

    def get_managed_rule_group(self, vendor: str, name: str) -> Dict:
        """Get AWS managed rule group configuration."""
        return {
            'Name': name,
            'Priority': 0,
            'Statement': {
                'ManagedRuleGroupStatement': {
                    'VendorName': vendor,
                    'Name': name
                }
            },
            'OverrideAction': {'None': {}},
            'VisibilityConfig': {
                'SampledRequestsEnabled': True,
                'CloudWatchMetricsEnabled': True,
                'MetricName': f'{name}-rule'
            }
        }


def create_production_waf():
    """Create production WAF configuration."""
    waf = AWSWAFManager()

    # Create blocked IP set
    blocked_ips_arn = waf.create_ip_set(
        name='blocked-ips',
        addresses=[],  # Start empty, populate from threat intel
        description='Known malicious IP addresses'
    )

    # Create allowed IP set for admin access
    allowed_admin_arn = waf.create_ip_set(
        name='admin-allowed-ips',
        addresses=['10.0.0.0/8', '192.168.0.0/16'],
        description='Allowed IPs for admin endpoints'
    )

    # Define rules
    rules = [
        # Priority 0: Block known bad IPs
        {
            'Name': 'BlockBadIPs',
            'Priority': 0,
            'Statement': {
                'IPSetReferenceStatement': {
                    'ARN': blocked_ips_arn
                }
            },
            'Action': {'Block': {}},
            'VisibilityConfig': {
                'SampledRequestsEnabled': True,
                'CloudWatchMetricsEnabled': True,
                'MetricName': 'BlockBadIPs'
            }
        },

        # Priority 1: AWS Managed - Common Rule Set
        {
            'Name': 'AWSManagedRulesCommonRuleSet',
            'Priority': 1,
            'Statement': {
                'ManagedRuleGroupStatement': {
                    'VendorName': 'AWS',
                    'Name': 'AWSManagedRulesCommonRuleSet',
                    'ExcludedRules': []
                }
            },
            'OverrideAction': {'None': {}},
            'VisibilityConfig': {
                'SampledRequestsEnabled': True,
                'CloudWatchMetricsEnabled': True,
                'MetricName': 'AWSCommonRules'
            }
        },

        # Priority 2: AWS Managed - Known Bad Inputs
        {
            'Name': 'AWSManagedRulesKnownBadInputsRuleSet',
            'Priority': 2,
            'Statement': {
                'ManagedRuleGroupStatement': {
                    'VendorName': 'AWS',
                    'Name': 'AWSManagedRulesKnownBadInputsRuleSet'
                }
            },
            'OverrideAction': {'None': {}},
            'VisibilityConfig': {
                'SampledRequestsEnabled': True,
                'CloudWatchMetricsEnabled': True,
                'MetricName': 'AWSKnownBadInputs'
            }
        },

        # Priority 3: AWS Managed - SQL Injection
        {
            'Name': 'AWSManagedRulesSQLiRuleSet',
            'Priority': 3,
            'Statement': {
                'ManagedRuleGroupStatement': {
                    'VendorName': 'AWS',
                    'Name': 'AWSManagedRulesSQLiRuleSet'
                }
            },
            'OverrideAction': {'None': {}},
            'VisibilityConfig': {
                'SampledRequestsEnabled': True,
                'CloudWatchMetricsEnabled': True,
                'MetricName': 'AWSSQLiRules'
            }
        },

        # Priority 4: AWS Managed - Linux OS
        {
            'Name': 'AWSManagedRulesLinuxRuleSet',
            'Priority': 4,
            'Statement': {
                'ManagedRuleGroupStatement': {
                    'VendorName': 'AWS',
                    'Name': 'AWSManagedRulesLinuxRuleSet'
                }
            },
            'OverrideAction': {'None': {}},
            'VisibilityConfig': {
                'SampledRequestsEnabled': True,
                'CloudWatchMetricsEnabled': True,
                'MetricName': 'AWSLinuxRules'
            }
        },

        # Priority 5: Rate limiting
        {
            'Name': 'RateLimitRule',
            'Priority': 5,
            'Statement': {
                'RateBasedStatement': {
                    'Limit': 2000,  # requests per 5 minutes
                    'AggregateKeyType': 'IP'
                }
            },
            'Action': {'Block': {}},
            'VisibilityConfig': {
                'SampledRequestsEnabled': True,
                'CloudWatchMetricsEnabled': True,
                'MetricName': 'RateLimit'
            }
        },

        # Priority 6: Geo blocking (optional)
        {
            'Name': 'GeoBlockRule',
            'Priority': 6,
            'Statement': {
                'GeoMatchStatement': {
                    'CountryCodes': ['CN', 'RU', 'KP']  # Example: block certain countries
                }
            },
            'Action': {'Block': {}},
            'VisibilityConfig': {
                'SampledRequestsEnabled': True,
                'CloudWatchMetricsEnabled': True,
                'MetricName': 'GeoBlock'
            }
        },

        # Priority 7: Admin path protection
        {
            'Name': 'AdminPathProtection',
            'Priority': 7,
            'Statement': {
                'AndStatement': {
                    'Statements': [
                        {
                            'ByteMatchStatement': {
                                'SearchString': '/admin',
                                'FieldToMatch': {'UriPath': {}},
                                'PositionalConstraint': 'STARTS_WITH',
                                'TextTransformations': [{'Priority': 0, 'Type': 'LOWERCASE'}]
                            }
                        },
                        {
                            'NotStatement': {
                                'Statement': {
                                    'IPSetReferenceStatement': {
                                        'ARN': allowed_admin_arn
                                    }
                                }
                            }
                        }
                    ]
                }
            },
            'Action': {'Block': {}},
            'VisibilityConfig': {
                'SampledRequestsEnabled': True,
                'CloudWatchMetricsEnabled': True,
                'MetricName': 'AdminProtection'
            }
        }
    ]

    # Create Web ACL
    web_acl_arn = waf.create_web_acl(
        name='production-web-acl',
        rules=rules
    )

    return web_acl_arn


if __name__ == '__main__':
    acl_arn = create_production_waf()
    print(f"Created Web ACL: {acl_arn}")
```

## Network Segmentation

### Kubernetes Network Policies

```yaml
# network-policies/default-deny.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: production
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
---
# network-policies/allow-dns.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns
  namespace: production
spec:
  podSelector: {}
  policyTypes:
  - Egress
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: kube-system
      podSelector:
        matchLabels:
          k8s-app: kube-dns
    ports:
    - protocol: UDP
      port: 53
    - protocol: TCP
      port: 53
---
# network-policies/frontend-policy.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: frontend-policy
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: frontend
  policyTypes:
  - Ingress
  - Egress
  ingress:
  # Allow from ingress controller
  - from:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: ingress-nginx
      podSelector:
        matchLabels:
          app.kubernetes.io/name: ingress-nginx
    ports:
    - protocol: TCP
      port: 8080
  egress:
  # Allow to backend API
  - to:
    - podSelector:
        matchLabels:
          app: backend
    ports:
    - protocol: TCP
      port: 8080
  # Allow to Redis cache
  - to:
    - podSelector:
        matchLabels:
          app: redis
    ports:
    - protocol: TCP
      port: 6379
---
# network-policies/backend-policy.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-policy
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
  - Ingress
  - Egress
  ingress:
  # Allow from frontend
  - from:
    - podSelector:
        matchLabels:
          app: frontend
    ports:
    - protocol: TCP
      port: 8080
  # Allow from other backend services
  - from:
    - podSelector:
        matchLabels:
          tier: backend
    ports:
    - protocol: TCP
      port: 8080
  egress:
  # Allow to database
  - to:
    - podSelector:
        matchLabels:
          app: postgres
    ports:
    - protocol: TCP
      port: 5432
  # Allow to message queue
  - to:
    - podSelector:
        matchLabels:
          app: rabbitmq
    ports:
    - protocol: TCP
      port: 5672
  # Allow to external APIs (specific IPs)
  - to:
    - ipBlock:
        cidr: 0.0.0.0/0
        except:
        - 10.0.0.0/8
        - 172.16.0.0/12
        - 192.168.0.0/16
    ports:
    - protocol: TCP
      port: 443
---
# network-policies/database-policy.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: database-policy
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: postgres
  policyTypes:
  - Ingress
  - Egress
  ingress:
  # Only allow from backend tier
  - from:
    - podSelector:
        matchLabels:
          tier: backend
    ports:
    - protocol: TCP
      port: 5432
  egress:
  # Database should not initiate outbound connections
  # except for replication
  - to:
    - podSelector:
        matchLabels:
          app: postgres
    ports:
    - protocol: TCP
      port: 5432
```

### Cilium Network Policies (Advanced)

```yaml
# cilium-policies/l7-api-policy.yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: api-l7-policy
  namespace: production
spec:
  endpointSelector:
    matchLabels:
      app: api-gateway
  ingress:
  - fromEndpoints:
    - matchLabels:
        app: frontend
    toPorts:
    - ports:
      - port: "8080"
        protocol: TCP
      rules:
        http:
        - method: "GET"
          path: "/api/v1/.*"
        - method: "POST"
          path: "/api/v1/users"
          headers:
          - "Content-Type: application/json"
        - method: "PUT"
          path: "/api/v1/users/[0-9]+"
        - method: "DELETE"
          path: "/api/v1/users/[0-9]+"
          headers:
          - "X-Admin-Token: .*"
---
# cilium-policies/dns-policy.yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: dns-visibility-policy
  namespace: production
spec:
  endpointSelector:
    matchLabels:
      app: backend
  egress:
  - toEndpoints:
    - matchLabels:
        k8s:io.kubernetes.pod.namespace: kube-system
        k8s-app: kube-dns
    toPorts:
    - ports:
      - port: "53"
        protocol: UDP
      rules:
        dns:
        - matchPattern: "*.company.com"
        - matchPattern: "*.amazonaws.com"
        - matchName: "api.stripe.com"
        - matchName: "smtp.sendgrid.net"
---
# cilium-policies/egress-fqdn-policy.yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: external-api-egress
  namespace: production
spec:
  endpointSelector:
    matchLabels:
      app: payment-service
  egress:
  - toFQDNs:
    - matchName: "api.stripe.com"
    - matchName: "api.paypal.com"
    toPorts:
    - ports:
      - port: "443"
        protocol: TCP
---
# cilium-policies/cluster-mesh-policy.yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: cross-cluster-policy
  namespace: production
spec:
  endpointSelector:
    matchLabels:
      app: shared-service
  ingress:
  - fromEndpoints:
    - matchLabels:
        io.cilium.k8s.policy.cluster: cluster-east
        app: frontend
    - matchLabels:
        io.cilium.k8s.policy.cluster: cluster-west
        app: frontend
    toPorts:
    - ports:
      - port: "8080"
        protocol: TCP
```

## Intrusion Detection and Prevention

### Suricata IDS/IPS Configuration

```yaml
# /etc/suricata/suricata.yaml
%YAML 1.1
---
vars:
  address-groups:
    HOME_NET: "[10.0.0.0/8,172.16.0.0/12,192.168.0.0/16]"
    EXTERNAL_NET: "!$HOME_NET"
    HTTP_SERVERS: "$HOME_NET"
    SQL_SERVERS: "$HOME_NET"
    DNS_SERVERS: "$HOME_NET"

  port-groups:
    HTTP_PORTS: "80,8080,443"
    SSH_PORTS: "22"
    DNS_PORTS: "53"

default-rule-path: /var/lib/suricata/rules

rule-files:
  - suricata.rules
  - emerging-threats.rules
  - custom.rules

af-packet:
  - interface: eth0
    threads: auto
    cluster-id: 99
    cluster-type: cluster_flow
    defrag: yes
    use-mmap: yes
    tpacket-v3: yes

outputs:
  - eve-log:
      enabled: yes
      filetype: regular
      filename: eve.json
      types:
        - alert:
            payload: yes
            payload-buffer-size: 4kb
            payload-printable: yes
            packet: yes
            metadata: yes
            http-body: yes
            http-body-printable: yes
        - http:
            extended: yes
        - dns
        - tls:
            extended: yes
        - files:
            force-magic: yes
        - smtp
        - flow
        - netflow

  - fast:
      enabled: yes
      filename: fast.log
      append: yes

# IPS mode settings
stream:
  memcap: 256mb
  checksum-validation: yes
  inline: auto

# Detection engine settings
detect:
  profile: medium
  custom-values:
    toclient-groups: 3
    toserver-groups: 25
  sgh-mpm-context: auto
  inspection-recursion-limit: 3000

# Threading
threading:
  set-cpu-affinity: yes
  cpu-affinity:
    - management-cpu-set:
        cpu: [0]
    - receive-cpu-set:
        cpu: [1]
    - worker-cpu-set:
        cpu: [2-7]

# Logging
logging:
  default-log-level: notice
  outputs:
    - console:
        enabled: yes
    - file:
        enabled: yes
        filename: suricata.log
```

### Custom Suricata Rules

```text
# /var/lib/suricata/rules/custom.rules

# Detect SSH brute force
alert tcp any any -> $HOME_NET $SSH_PORTS (msg:"SSH Brute Force Attempt"; \
    flow:to_server,established; content:"SSH-"; offset:0; depth:4; \
    threshold:type both, track by_src, count 10, seconds 60; \
    classtype:attempted-admin; sid:1000001; rev:1;)

# Detect potential SQL injection in HTTP
alert http any any -> $HTTP_SERVERS $HTTP_PORTS (msg:"SQL Injection Attempt"; \
    flow:to_server,established; \
    content:"SELECT"; nocase; http_uri; \
    content:"FROM"; nocase; http_uri; distance:0; \
    classtype:web-application-attack; sid:1000002; rev:1;)

# Detect XSS attempts
alert http any any -> $HTTP_SERVERS $HTTP_PORTS (msg:"XSS Attack Attempt"; \
    flow:to_server,established; \
    content:"<script"; nocase; http_uri; \
    classtype:web-application-attack; sid:1000003; rev:1;)

# Detect path traversal
alert http any any -> $HTTP_SERVERS $HTTP_PORTS (msg:"Path Traversal Attempt"; \
    flow:to_server,established; \
    content:"../"; http_uri; \
    classtype:web-application-attack; sid:1000004; rev:1;)

# Detect potential reverse shell
alert tcp $HOME_NET any -> $EXTERNAL_NET any (msg:"Potential Reverse Shell"; \
    flow:to_server,established; \
    content:"/bin/sh"; \
    classtype:trojan-activity; sid:1000005; rev:1;)

# Detect cryptocurrency mining
alert tcp $HOME_NET any -> any any (msg:"Cryptocurrency Mining Pool Connection"; \
    flow:to_server,established; \
    content:"stratum+tcp://"; \
    classtype:policy-violation; sid:1000006; rev:1;)

# Detect DNS tunneling (long DNS queries)
alert dns any any -> any any (msg:"Possible DNS Tunneling - Long Query"; \
    dns.query; content:"|00|"; offset:60; \
    classtype:policy-violation; sid:1000007; rev:1;)

# Detect TLS with suspicious JA3 fingerprint (known malware)
alert tls any any -> any any (msg:"Suspicious TLS JA3 Fingerprint"; \
    ja3.hash; content:"a0e9f5d64349fb13191bc781f81f42e1"; \
    classtype:trojan-activity; sid:1000008; rev:1;)

# Detect outbound traffic to TOR exit nodes
# (Requires tor-exit-nodes.txt IP list)
alert ip $HOME_NET any -> [external-ip-list] any (msg:"TOR Exit Node Communication"; \
    classtype:policy-violation; sid:1000009; rev:1;)

# Detect ICMP tunnel (large ICMP packets)
alert icmp any any -> any any (msg:"Possible ICMP Tunnel - Large Payload"; \
    dsize:>800; \
    classtype:policy-violation; sid:1000010; rev:1;)

# Detect SMB lateral movement
alert tcp any any -> $HOME_NET 445 (msg:"SMB Lateral Movement Detected"; \
    flow:to_server,established; \
    content:"|ff|SMB"; offset:4; depth:4; \
    content:"|25 00|"; distance:28; within:2; \
    threshold:type both, track by_src, count 5, seconds 120; \
    classtype:attempted-admin; sid:1000011; rev:1;)
```

## Zero Trust Network Access (ZTNA)

### Istio Service Mesh Security

```yaml
# istio-security/peer-authentication.yaml
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: istio-system
spec:
  mtls:
    mode: STRICT
---
# Per-namespace mTLS settings
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: production-mtls
  namespace: production
spec:
  selector:
    matchLabels:
      security: strict
  mtls:
    mode: STRICT
  portLevelMtls:
    8080:
      mode: STRICT
---
# istio-security/authorization-policy.yaml
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: frontend-policy
  namespace: production
spec:
  selector:
    matchLabels:
      app: frontend
  action: ALLOW
  rules:
  - from:
    - source:
        namespaces: ["ingress-nginx"]
    to:
    - operation:
        methods: ["GET", "POST"]
        paths: ["/*"]
---
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: backend-api-policy
  namespace: production
spec:
  selector:
    matchLabels:
      app: backend
  action: ALLOW
  rules:
  # Allow frontend to call backend
  - from:
    - source:
        principals: ["cluster.local/ns/production/sa/frontend"]
    to:
    - operation:
        methods: ["GET", "POST", "PUT", "DELETE"]
        paths: ["/api/*"]
  # Allow monitoring
  - from:
    - source:
        namespaces: ["monitoring"]
    to:
    - operation:
        methods: ["GET"]
        paths: ["/metrics", "/health"]
---
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: database-policy
  namespace: production
spec:
  selector:
    matchLabels:
      app: postgres
  action: ALLOW
  rules:
  # Only backend services can access database
  - from:
    - source:
        principals:
        - "cluster.local/ns/production/sa/backend"
        - "cluster.local/ns/production/sa/worker"
    to:
    - operation:
        ports: ["5432"]
---
# istio-security/request-authentication.yaml
apiVersion: security.istio.io/v1beta1
kind: RequestAuthentication
metadata:
  name: jwt-auth
  namespace: production
spec:
  selector:
    matchLabels:
      app: backend
  jwtRules:
  - issuer: "https://auth.company.com"
    jwksUri: "https://auth.company.com/.well-known/jwks.json"
    audiences:
    - "api.company.com"
    forwardOriginalToken: true
    outputPayloadToHeader: "x-jwt-payload"
---
# Require JWT for specific paths
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: require-jwt
  namespace: production
spec:
  selector:
    matchLabels:
      app: backend
  action: DENY
  rules:
  - from:
    - source:
        notRequestPrincipals: ["*"]
    to:
    - operation:
        paths: ["/api/v1/users/*", "/api/v1/admin/*"]
```

### BeyondCorp-Style Access Proxy

```yaml
# pomerium-config.yaml - Identity-aware access proxy
apiVersion: v1
kind: ConfigMap
metadata:
  name: pomerium-config
  namespace: pomerium
data:
  config.yaml: |
    # Global settings
    authenticate_service_url: https://authenticate.company.com
    authorize_service_url: https://authorize.company.com

    # Identity provider
    idp_provider: oidc
    idp_provider_url: https://auth.company.com
    idp_client_id: pomerium
    idp_client_secret: ${IDP_CLIENT_SECRET}

    # Cookie settings
    cookie_name: _pomerium
    cookie_secret: ${COOKIE_SECRET}
    cookie_domain: company.com
    cookie_secure: true
    cookie_http_only: true
    cookie_same_site: lax

    # TLS settings
    certificate_file: /etc/pomerium/tls/tls.crt
    certificate_key_file: /etc/pomerium/tls/tls.key

    # Access policies
    policy:
      # Internal dashboard - require authentication
      - from: https://dashboard.company.com
        to: http://dashboard-service.internal:8080
        allowed_users:
          - "*@company.com"
        allow_any_authenticated_user: true

      # Admin panel - require specific group
      - from: https://admin.company.com
        to: http://admin-service.internal:8080
        allowed_groups:
          - "admin-users"
        allowed_idp_claims:
          role:
            - "admin"

      # Production access - require MFA and specific group
      - from: https://prod-ssh.company.com
        to: tcp+https://bastion.internal:22
        allowed_groups:
          - "sre-team"
          - "platform-team"
        pass_identity_headers: true
        allow_websockets: true

      # Database access - strict controls
      - from: https://db-access.company.com
        to: tcp://postgres.internal:5432
        allowed_groups:
          - "dba-team"
        allowed_idp_claims:
          groups:
            - "database-admins"
        timeout: 30m

      # Kubernetes dashboard - context-aware access
      - from: https://k8s.company.com
        to: https://kubernetes-dashboard.kubernetes-dashboard.svc.cluster.local
        allowed_groups:
          - "k8s-users"
        allow_any_authenticated_user: false
        set_request_headers:
          X-Auth-User: "$pomerium.user"
          X-Auth-Groups: "$pomerium.groups"

      # API gateway - device trust required
      - from: https://api-internal.company.com
        to: http://api-gateway.internal:8080
        allowed_groups:
          - "developers"
        allowed_devices:
          required: true
```

## Cloud Network Security

### AWS VPC Security Configuration

```hcl
# terraform/aws-vpc-security.tf

# VPC with multiple subnets
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "production-vpc"
  }
}

# Public subnets (for load balancers)
resource "aws_subnet" "public" {
  count                   = 3
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.${count.index}.0/24"
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "public-${count.index}"
    Type = "public"
  }
}

# Private subnets (for applications)
resource "aws_subnet" "private" {
  count             = 3
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${count.index + 10}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "private-${count.index}"
    Type = "private"
  }
}

# Database subnets (isolated)
resource "aws_subnet" "database" {
  count             = 3
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${count.index + 20}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "database-${count.index}"
    Type = "database"
  }
}

# Network ACLs
resource "aws_network_acl" "public" {
  vpc_id     = aws_vpc.main.id
  subnet_ids = aws_subnet.public[*].id

  # Allow HTTP/HTTPS inbound
  ingress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 110
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }

  # Allow ephemeral ports for responses
  ingress {
    protocol   = "tcp"
    rule_no    = 200
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  # Allow all outbound
  egress {
    protocol   = -1
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = {
    Name = "public-nacl"
  }
}

resource "aws_network_acl" "private" {
  vpc_id     = aws_vpc.main.id
  subnet_ids = aws_subnet.private[*].id

  # Allow from VPC only
  ingress {
    protocol   = -1
    rule_no    = 100
    action     = "allow"
    cidr_block = aws_vpc.main.cidr_block
    from_port  = 0
    to_port    = 0
  }

  # Allow ephemeral ports for NAT responses
  ingress {
    protocol   = "tcp"
    rule_no    = 200
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  # Allow outbound to VPC and internet
  egress {
    protocol   = -1
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = {
    Name = "private-nacl"
  }
}

resource "aws_network_acl" "database" {
  vpc_id     = aws_vpc.main.id
  subnet_ids = aws_subnet.database[*].id

  # Only allow from private subnets
  dynamic "ingress" {
    for_each = aws_subnet.private[*].cidr_block
    content {
      protocol   = "tcp"
      rule_no    = 100 + ingress.key
      action     = "allow"
      cidr_block = ingress.value
      from_port  = 5432
      to_port    = 5432
    }
  }

  # Allow responses to private subnets
  egress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = "10.0.10.0/22"  # Private subnet range
    from_port  = 1024
    to_port    = 65535
  }

  tags = {
    Name = "database-nacl"
  }
}

# Security Groups
resource "aws_security_group" "alb" {
  name        = "alb-sg"
  description = "Security group for Application Load Balancer"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "alb-sg"
  }
}

resource "aws_security_group" "application" {
  name        = "application-sg"
  description = "Security group for application instances"
  vpc_id      = aws_vpc.main.id

  # Allow from ALB only
  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # Allow SSH from bastion
  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "application-sg"
  }
}

resource "aws_security_group" "database" {
  name        = "database-sg"
  description = "Security group for database instances"
  vpc_id      = aws_vpc.main.id

  # Allow from application tier only
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.application.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "database-sg"
  }
}

resource "aws_security_group" "bastion" {
  name        = "bastion-sg"
  description = "Security group for bastion host"
  vpc_id      = aws_vpc.main.id

  # Allow SSH from corporate IP ranges only
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["203.0.113.0/24"]  # Corporate IP range
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "bastion-sg"
  }
}

# VPC Flow Logs
resource "aws_flow_log" "main" {
  iam_role_arn    = aws_iam_role.flow_logs.arn
  log_destination = aws_cloudwatch_log_group.flow_logs.arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.main.id

  tags = {
    Name = "vpc-flow-logs"
  }
}

resource "aws_cloudwatch_log_group" "flow_logs" {
  name              = "/aws/vpc/flow-logs"
  retention_in_days = 90
}
```

## Summary

Network security is a fundamental layer of defense that requires:
- **Defense in Depth**: Multiple layers of security controls
- **Segmentation**: Isolate networks and limit blast radius
- **Zero Trust**: Never trust, always verify
- **Visibility**: Monitor and log all network activity
- **Automation**: Automate security policy enforcement

## References

- [NIST Network Security Guidelines](https://nvd.nist.gov/800-53)
- [CIS Benchmarks](https://www.cisecurity.org/cis-benchmarks)
- [Kubernetes Network Policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
- [Istio Security](https://istio.io/latest/docs/concepts/security/)
- [AWS VPC Security](https://docs.aws.amazon.com/vpc/latest/userguide/security.html)

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Introduction to Network Security
- Firewall Configuration
- Web Application Firewall (WAF)
- Network Segmentation

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

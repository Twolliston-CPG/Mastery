# Lab 3.2: Functions & Expressions

## Objective

Master all HCL function categories and advanced expressions for dynamic configurations.

## Duration: 90 minutes

---

## Part 1: String Functions

```hcl
locals {
  # FORMATTING
  formatted = format("Hello, %s! Count: %d", "World", 42)
  # "Hello, World! Count: 42"

  formatted_list = formatlist("server-%s", ["web", "api", "db"])
  # ["server-web", "server-api", "server-db"]

  # CASE TRANSFORMATION
  upper_name = upper("terraform")      # "TERRAFORM"
  lower_name = lower("TERRAFORM")      # "terraform"
  title_name = title("hello world")    # "Hello World"

  # TRIMMING
  trimmed       = trim("  hello  ", " ")         # "hello"
  trim_prefix   = trimprefix("helloworld", "hello")  # "world"
  trim_suffix   = trimsuffix("helloworld", "world")  # "hello"
  trimmed_space = trimspace("  hello  ")         # "hello"

  # SPLITTING & JOINING
  parts  = split(",", "a,b,c")     # ["a", "b", "c"]
  joined = join("-", ["a", "b"])   # "a-b"

  # REPLACEMENT
  replaced = replace("hello-world", "-", "_")  # "hello_world"
  regex_replaced = replace("server-123", "/[0-9]+/", "XXX")  # "server-XXX"

  # SUBSTRING
  sub = substr("hello world", 0, 5)  # "hello"

  # REGEX
  matched = regex("^([a-z]+)-([0-9]+)$", "server-123")  # ["server", "123"]
  all_numbers = regexall("[0-9]+", "a1b2c3")  # ["1", "2", "3"]
  can_match = can(regex("^[0-9]+$", "123"))  # true

  # INDENTATION (for YAML/JSON embedding)
  indented = indent(4, "line1\nline2")

  # CHOMP (remove trailing newline)
  chomped = chomp("hello\n")  # "hello"
}
```

### String Function Exercises

```hcl
variable "server_names" {
  default = ["Web-Server-01", "API-Server-02", "DB-Server-03"]
}

locals {
  # Normalize to lowercase with hyphens
  normalized_names = [
    for name in var.server_names :
    lower(replace(name, "_", "-"))
  ]

  # Extract server types
  server_types = [
    for name in var.server_names :
    lower(element(split("-", name), 0))
  ]

  # Generate DNS names
  dns_names = formatlist("%s.internal.company.com", local.normalized_names)
}
```

---

## Part 2: Collection Functions

```hcl
locals {
  list1 = ["a", "b", "c"]
  list2 = ["d", "e"]
  map1  = { a = 1, b = 2 }
  map2  = { c = 3, d = 4 }

  # LENGTH
  list_length = length(local.list1)  # 3
  map_length  = length(local.map1)   # 2

  # CONCAT (lists)
  combined = concat(local.list1, local.list2)  # ["a", "b", "c", "d", "e"]

  # FLATTEN
  nested = [["a", "b"], ["c", "d"]]
  flat   = flatten(local.nested)  # ["a", "b", "c", "d"]

  # MERGE (maps)
  merged = merge(local.map1, local.map2)  # { a = 1, b = 2, c = 3, d = 4 }

  # ELEMENT & INDEX
  first = element(local.list1, 0)  # "a"
  idx   = index(local.list1, "b")  # 1

  # CONTAINS
  has_a = contains(local.list1, "a")  # true

  # DISTINCT
  unique = distinct(["a", "b", "a", "c"])  # ["a", "b", "c"]

  # SORT & REVERSE
  sorted   = sort(["c", "a", "b"])     # ["a", "b", "c"]
  reversed = reverse(["a", "b", "c"])  # ["c", "b", "a"]

  # RANGE
  numbers = range(1, 5)      # [1, 2, 3, 4]
  stepped = range(0, 10, 2)  # [0, 2, 4, 6, 8]

  # KEYS & VALUES
  map_keys   = keys(local.map1)    # ["a", "b"]
  map_values = values(local.map1)  # [1, 2]

  # LOOKUP
  found   = lookup(local.map1, "a", "default")  # 1
  missing = lookup(local.map1, "z", "default")  # "default"

  # ZIPMAP
  zipped = zipmap(["a", "b"], [1, 2])  # { a = 1, b = 2 }

  # CHUNKLIST
  chunked = chunklist(["a", "b", "c", "d", "e"], 2)  # [["a", "b"], ["c", "d"], ["e"]]

  # COALESCE (first non-null/non-empty)
  first_valid = coalesce("", null, "hello", "world")  # "hello"
  coalesce_list = coalescelist([], ["a", "b"])  # ["a", "b"]

  # COMPACT (remove empty strings)
  compacted = compact(["a", "", "b", ""])  # ["a", "b"]

  # SETPRODUCT (cartesian product)
  product = setproduct(["web", "api"], ["dev", "prod"])
  # [["web", "dev"], ["web", "prod"], ["api", "dev"], ["api", "prod"]]

  # SETINTERSECTION & SETUNION
  intersection = setintersection(["a", "b"], ["b", "c"])  # ["b"]
  union        = setunion(["a", "b"], ["b", "c"])         # ["a", "b", "c"]
}
```

### Collection Exercises

```hcl
variable "environments" {
  default = ["dev", "staging", "prod"]
}

variable "services" {
  default = ["web", "api", "worker"]
}

locals {
  # Generate all service-environment combinations
  all_deployments = [
    for pair in setproduct(var.services, var.environments) :
    "${pair[0]}-${pair[1]}"
  ]
  # ["web-dev", "web-staging", "web-prod", "api-dev", ...]

  # Group by environment
  deployments_by_env = {
    for env in var.environments :
    env => [for svc in var.services : "${svc}-${env}"]
  }
}
```

---

## Part 3: Numeric Functions

```hcl
locals {
  # BASIC MATH
  absolute = abs(-5)        # 5
  ceiling  = ceil(4.3)      # 5
  floored  = floor(4.7)     # 4

  # MIN & MAX
  minimum = min(1, 5, 3)    # 1
  maximum = max(1, 5, 3)    # 5

  # POWER & LOG
  squared = pow(2, 3)       # 8
  logged  = log(100, 10)    # 2

  # SIGNUM (sign)
  sign_neg = signum(-5)     # -1
  sign_pos = signum(5)      # 1
  sign_zero = signum(0)     # 0

  # PARSEINT
  parsed = parseint("FF", 16)  # 255
}

# Calculate subnet CIDR blocks
variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

variable "subnet_count" {
  default = 4
}

locals {
  # Calculate bits needed for subnets
  new_bits = ceil(log(var.subnet_count, 2))

  subnet_cidrs = [
    for i in range(var.subnet_count) :
    cidrsubnet(var.vpc_cidr, local.new_bits, i)
  ]
  # ["10.0.0.0/18", "10.0.64.0/18", "10.0.128.0/18", "10.0.192.0/18"]
}
```

---

## Part 4: IP Network Functions

```hcl
locals {
  vpc_cidr = "10.0.0.0/16"

  # CIDRHOST - Get specific host IP
  first_host = cidrhost(local.vpc_cidr, 1)   # "10.0.0.1"
  last_host  = cidrhost(local.vpc_cidr, -2)  # "10.0.255.254"

  # CIDRNETMASK - Get netmask
  netmask = cidrnetmask(local.vpc_cidr)  # "255.255.0.0"

  # CIDRSUBNET - Calculate subnet
  subnet_1 = cidrsubnet(local.vpc_cidr, 8, 0)   # "10.0.0.0/24"
  subnet_2 = cidrsubnet(local.vpc_cidr, 8, 1)   # "10.0.1.0/24"
  subnet_10 = cidrsubnet(local.vpc_cidr, 8, 10) # "10.0.10.0/24"

  # CIDRSUBNETS - Multiple subnets at once
  subnets = cidrsubnets(local.vpc_cidr, 4, 4, 8, 8)
  # ["10.0.0.0/20", "10.0.16.0/20", "10.0.32.0/24", "10.0.33.0/24"]

  # Complex subnet calculation
  az_count = 3
  public_subnets = [
    for i in range(local.az_count) :
    cidrsubnet(local.vpc_cidr, 8, i)
  ]
  private_subnets = [
    for i in range(local.az_count) :
    cidrsubnet(local.vpc_cidr, 8, i + 100)
  ]
}

output "network_layout" {
  value = {
    vpc_cidr        = local.vpc_cidr
    netmask         = local.netmask
    public_subnets  = local.public_subnets
    private_subnets = local.private_subnets
  }
}
```

---

## Part 5: Encoding Functions

```hcl
locals {
  # JSON
  json_encoded = jsonencode({
    name  = "example"
    count = 5
    tags  = ["a", "b"]
  })

  json_decoded = jsondecode(local.json_encoded)

  # YAML
  yaml_encoded = yamlencode({
    apiVersion = "v1"
    kind       = "ConfigMap"
  })

  yaml_decoded = yamldecode(local.yaml_encoded)

  # BASE64
  base64_encoded = base64encode("Hello World")  # "SGVsbG8gV29ybGQ="
  base64_decoded = base64decode("SGVsbG8gV29ybGQ=")  # "Hello World"

  # URL ENCODING
  url_encoded = urlencode("hello world")  # "hello%20world"

  # GZIP (for user data)
  gzip_data = base64gzip(<<-EOF
    #!/bin/bash
    echo "Hello from user data"
    yum update -y
  EOF
  )

  # CSV
  csv_data = <<-CSV
    name,instance_type,count
    web,t2.micro,3
    api,t2.small,2
  CSV

  csv_decoded = csvdecode(local.csv_data)
  # [
  #   { name = "web", instance_type = "t2.micro", count = "3" },
  #   { name = "api", instance_type = "t2.small", count = "2" }
  # ]
}
```

---

## Part 6: Filesystem Functions

```hcl
locals {
  # FILE - Read file contents
  config = file("${path.module}/config.json")

  # FILEEXISTS - Check if file exists
  has_config = fileexists("${path.module}/config.json")

  # FILESET - Find files matching pattern
  script_files = fileset("${path.module}/scripts", "*.sh")
  all_tf_files = fileset("${path.module}", "**/*.tf")

  # FILEBASE64 - Read file as base64
  logo_base64 = fileexists("${path.module}/logo.png") ? filebase64("${path.module}/logo.png") : ""

  # TEMPLATEFILE - Render template
  user_data = templatefile("${path.module}/user_data.tftpl", {
    environment = var.environment
    packages    = ["nginx", "htop"]
  })

  # PATH references
  module_path = path.module   # Current module directory
  root_path   = path.root     # Root module directory
  cwd_path    = path.cwd      # Current working directory

  # DIRNAME & BASENAME
  dir  = dirname("/path/to/file.txt")   # "/path/to"
  base = basename("/path/to/file.txt")  # "file.txt"

  # ABSPATH
  abs_path = abspath("./relative/path")
}
```

---

## Part 7: Type Conversion Functions

```hcl
locals {
  # TO* Functions
  to_string = tostring(123)       # "123"
  to_number = tonumber("123")     # 123
  to_bool   = tobool("true")      # true

  to_list = tolist(toset(["a", "b", "a"]))  # ["a", "b"]
  to_set  = toset(["a", "b", "a"])          # toset(["a", "b"])
  to_map  = tomap({ a = 1, b = 2 })

  # TRY - Return first successful expression
  safe_lookup = try(var.config.nested.value, "default")
  safe_index  = try(var.list[5], null)

  # CAN - Check if expression is valid
  is_valid = can(regex("^[0-9]+$", var.input))

  # TYPE - Get type of value (debugging)
  type_of = type(local.to_list)  # "list"

  # SENSITIVE & NONSENSITIVE
  secret = sensitive("password123")
  revealed = nonsensitive(local.secret)  # Use carefully!
}
```

---

## Part 8: For Expressions

```hcl
variable "users" {
  default = {
    alice = { role = "admin", team = "platform" }
    bob   = { role = "developer", team = "app" }
    carol = { role = "developer", team = "platform" }
  }
}

locals {
  # List from map
  user_names = [for name, _ in var.users : name]
  # ["alice", "bob", "carol"]

  # Transform values
  user_emails = [for name, _ in var.users : "${name}@company.com"]
  # ["alice@company.com", ...]

  # Filter
  admins = [for name, user in var.users : name if user.role == "admin"]
  # ["alice"]

  # Map transformation
  user_roles = { for name, user in var.users : name => user.role }
  # { alice = "admin", bob = "developer", carol = "developer" }

  # Group by
  users_by_role = {
    for name, user in var.users :
    user.role => name...
  }
  # { admin = ["alice"], developer = ["bob", "carol"] }

  # With index
  indexed_users = {
    for i, name in local.user_names :
    name => i
  }
  # { alice = 0, bob = 1, carol = 2 }

  # Nested for
  all_permissions = flatten([
    for name, user in var.users : [
      for permission in ["read", "write"] :
      "${name}:${permission}"
    ]
    if user.role == "admin"
  ])
  # ["alice:read", "alice:write"]
}
```

---

## Part 9: Splat Expressions

```hcl
# Assume we have multiple instances
resource "aws_instance" "servers" {
  count         = 3
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t2.micro"
}

locals {
  # Splat expression (shorthand for for expression)
  instance_ids = aws_instance.servers[*].id
  # Equivalent to: [for s in aws_instance.servers : s.id]

  private_ips = aws_instance.servers[*].private_ip

  # Splat on nested attributes
  root_volumes = aws_instance.servers[*].root_block_device[0].volume_id
}

# For for_each resources
resource "aws_instance" "named_servers" {
  for_each      = toset(["web", "api", "db"])
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t2.micro"
}

locals {
  # Must use values() for for_each
  named_instance_ids = values(aws_instance.named_servers)[*].id
}
```

---

## Exercise: Dynamic Configuration Generator

Create a configuration that generates a complete infrastructure setup from a simple input:

### Input

```hcl
variable "config" {
  default = {
    project     = "myapp"
    environment = "prod"
    regions     = ["us-east-1", "us-west-2"]
    services = {
      web    = { instances = 3, type = "t2.small" }
      api    = { instances = 2, type = "t2.medium" }
      worker = { instances = 1, type = "t2.large" }
    }
  }
}
```

### Expected Outputs

Generate:
1. VPC CIDR blocks per region
2. Subnet allocations
3. Instance configurations with naming
4. Security group rules
5. Complete resource tags

---

## Checkpoint

Before moving to Lab 3.3, verify you can:

- [ ] Use all string manipulation functions
- [ ] Transform collections with functions
- [ ] Calculate network CIDRs programmatically
- [ ] Encode/decode data formats
- [ ] Write complex for expressions
- [ ] Use splat expressions effectively

---

## Next: Lab 3.3 - Module Development

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- String Functions
- Collection Functions
- Numeric Functions
- IP Network Functions

**The gap is not what you forgot. It is where you used a word instead of a mechanism.**

| | |
|---|---|
| ✗ | *"Terraform manages your infrastructure."* |
| ✓ | *"`plan` is a three-way comparison: the configuration (desired), the state file (what Terraform believes it created), and a refresh against the real API (what exists). Almost every confusing result is one of those three drifting from the other two."* |

**Trace it:** `terraform apply` on one resource: config → plan → API call → state write. Then say what happens if the process dies between the API call and the state write.

Stop at the first component you cannot name. Reopen this file and read **only** that.

**Go deeper — only once the gap has a name:** [the purpose of Terraform state](https://developer.hashicorp.com/terraform/language/state/purpose) — almost every confusing result is a three-way disagreement, spelled out there.
Full list per domain: [`SOURCES.md`](../../SOURCES.md#terraform)

→ Protocol, the three levels of knowing, and worked examples: [`MASTERY.md`](../../MASTERY.md)

<!-- /feynman-check -->

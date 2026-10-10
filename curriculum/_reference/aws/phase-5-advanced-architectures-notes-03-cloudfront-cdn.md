# Amazon CloudFront -- Content Delivery Network

## Why This Matters for the Exam

CloudFront appears in nearly every exam sitting. Expect 3-5 questions on CloudFront origins, OAC vs OAI, signed URLs vs cookies, and CloudFront Functions vs Lambda@Edge. The exam tests both configuration knowledge and architectural judgment (when to use CloudFront vs Global Accelerator).

---

## What CloudFront Does

CloudFront is a global Content Delivery Network (CDN) that caches content at 450+ edge locations worldwide. It reduces latency by serving content from the edge location closest to the user instead of from the origin.

**Key benefits:**
- Lower latency (content served from nearby edge locations).
- Reduced load on origin servers.
- DDoS protection (integrated with AWS Shield Standard, free).
- HTTPS termination at the edge.
- Access control (signed URLs, signed cookies, geo restriction).

---

## CloudFront Origins

An origin is where CloudFront retrieves the original content when the cache does not have it.

### Supported Origin Types

| Origin | Use Case | Protocol | Notes |
|---|---|---|---|
| **S3 Bucket** | Static websites, media files, software downloads | HTTP/HTTPS | Use OAC to restrict direct S3 access |
| **S3 Static Website Endpoint** | Static website with S3 website hosting enabled | HTTP only | Cannot use OAC (treated as custom origin) |
| **ALB** | Dynamic content from web servers behind a load balancer | HTTP/HTTPS | ALB must be public; EC2 can be private |
| **EC2 Instance** | Dynamic content directly from EC2 | HTTP/HTTPS | EC2 must be public (no ALB intermediary) |
| **Custom HTTP Origin** | Any HTTP server (on-premises, other cloud) | HTTP/HTTPS | Any publicly accessible HTTP endpoint |
| **MediaStore / MediaPackage** | Video streaming | HTTP/HTTPS | Optimized for media delivery |

### Origin Groups (Failover)

You can configure an **origin group** with a primary and secondary origin. If the primary origin returns specific HTTP error codes (e.g., 500, 502, 503, 504), CloudFront automatically fails over to the secondary origin.

**Use case:** S3 bucket in us-east-1 as primary, S3 bucket in us-west-2 as secondary. If us-east-1 fails, CloudFront serves from us-west-2.

---

## OAC vs OAI -- Restricting S3 Access

When using S3 as a CloudFront origin, you want to ensure users can ONLY access S3 through CloudFront, not directly via the S3 URL.

### Comparison Table

| Feature | OAI (Origin Access Identity) | OAC (Origin Access Control) |
|---|---|---|
| **Status** | Legacy (still works, but deprecated for new setups) | **Recommended** (current best practice) |
| **SSE-KMS Support** | No (cannot read KMS-encrypted objects) | **Yes** (supports SSE-KMS) |
| **All S3 Regions** | Only original S3 regions | **All regions** including opt-in regions |
| **HTTP Methods** | GET, HEAD only in some configurations | **All HTTP methods** (GET, PUT, POST, DELETE) |
| **Dynamic Requests** | Limited | Full support (e.g., S3 POST for uploads) |
| **Setup** | Create OAI, update S3 bucket policy | Create OAC, update S3 bucket policy |
| **Granularity** | One OAI per distribution (typically) | One OAC can be shared across distributions |
| **SigV4 Signing** | Uses a legacy signing method | Uses **SigV4** (standard AWS signing) |

### How OAC Works

1. Create an OAC in CloudFront.
2. Associate the OAC with your CloudFront distribution's S3 origin.
3. Update the S3 bucket policy to allow the CloudFront distribution to access objects:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AllowCloudFrontServicePrincipal",
            "Effect": "Allow",
            "Principal": {
                "Service": "cloudfront.amazonaws.com"
            },
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::my-bucket/*",
            "Condition": {
                "StringEquals": {
                    "AWS:SourceArn": "arn:aws:cloudfront::111122223333:distribution/EDFDVBD6EXAMPLE"
                }
            }
        }
    ]
}
```

**Exam tip:** If a question mentions "KMS-encrypted S3 objects served through CloudFront," OAC is the only option. OAI does not support SSE-KMS.

---

## Cache Behaviors

Cache behaviors define how CloudFront handles requests for different URL patterns.

### Default Cache Behavior

Every distribution has exactly one default cache behavior (path pattern: `*`). It handles all requests that do not match any other cache behavior.

### Additional Cache Behaviors

You can add cache behaviors with specific path patterns to customize caching for different content:

| Path Pattern | Origin | TTL | Example |
|---|---|---|---|
| `/api/*` | ALB (dynamic) | 0 (no cache) | API calls should not be cached |
| `/images/*` | S3 bucket | 86400 (1 day) | Images rarely change |
| `/static/*` | S3 bucket | 2592000 (30 days) | CSS/JS with versioned filenames |
| `*` (default) | ALB | 300 (5 min) | Everything else |

**Cache behaviors are evaluated in order** (most specific first). The first matching pattern wins.

### Cache Key

The cache key determines what makes a cached object unique. By default, the cache key is the URL path. You can customize it to include:
- Query strings (all, specific, or none)
- HTTP headers (specific headers)
- Cookies (all, specific, or none)

**Exam tip:** Including more items in the cache key = more unique cached copies = lower cache hit ratio. Only include what is necessary.

---

## TTL (Time to Live)

TTL controls how long CloudFront caches an object before checking with the origin for a new version.

| TTL Setting | Value | Description |
|---|---|---|
| **Minimum TTL** | 0 seconds | Lowest TTL CloudFront will honor |
| **Default TTL** | 86400 seconds (24 hours) | Used when origin does not send Cache-Control headers |
| **Maximum TTL** | 31536000 seconds (365 days) | Highest TTL CloudFront will honor |

**How TTL is determined (priority order):**
1. Origin sends `Cache-Control: max-age=X` header -- CloudFront uses X (clamped between min and max TTL).
2. Origin sends `Cache-Control: no-cache` or `no-store` -- CloudFront always revalidates.
3. Origin sends no cache headers -- CloudFront uses the Default TTL.

---

## Cache Invalidation

Invalidation forces CloudFront to remove cached objects before their TTL expires.

**When to use:**
- You updated content at the origin and need it reflected immediately.
- You accidentally cached incorrect content.

**How it works:**
- Specify path patterns to invalidate (e.g., `/images/*`, `/index.html`).
- First 1,000 invalidation paths per month are free; $0.005 per path after.
- Invalidations propagate to all edge locations (takes a few minutes).

**Better alternative: Object versioning.**
- Instead of invalidating `/style.css`, use `/style-v2.css` or `/style.css?v=2`.
- New URL = new cache key = CloudFront fetches the new version automatically.
- No invalidation cost, instant for new users.

**Exam tip:** If the question asks "most cost-effective way to serve updated content," the answer is object versioning, not invalidation.

---

## Signed URLs vs Signed Cookies

Both restrict access to CloudFront content to authorized users. The difference is granularity.

### Comparison Table

| Feature | Signed URLs | Signed Cookies |
|---|---|---|
| **Scope** | One URL = one file | One cookie = multiple files |
| **Use case** | Individual file downloads (PDF, video) | Entire website or multiple resources (HLS video with segments) |
| **URL modification** | URL contains signature parameters | URL unchanged; signature is in cookie headers |
| **RTMP** | Required for RTMP (legacy) | Not supported for RTMP |
| **Client support** | Works everywhere (just a URL) | Requires client to support cookies |
| **Example** | `https://d1234.cloudfront.net/video.mp4?Expires=...&Signature=...&Key-Pair-Id=...` | Set-Cookie header with CloudFront policy |

### When to Use Which

| Scenario | Use |
|---|---|
| "Restrict access to a specific downloadable file" | Signed URL |
| "Users pay for premium video streaming (multiple segment files)" | Signed Cookies |
| "Provide a temporary download link via email" | Signed URL |
| "Restrict access to an entire members-only website section" | Signed Cookies |
| "Client does not support cookies" | Signed URL |

### How Signing Works

1. Create a **CloudFront key pair** (or use a trusted key group with public/private keys).
2. Your application generates signed URLs or cookies using the private key.
3. CloudFront validates the signature using the public key.
4. The signature encodes: expiration time, allowed IP range (optional), and the resource URL/path.

**Exam tip:** CloudFront signed URLs are NOT the same as S3 pre-signed URLs. CloudFront signed URLs restrict access at the CDN layer; S3 pre-signed URLs restrict access at the S3 layer. If you want to restrict access through CloudFront, use CloudFront signed URLs.

---

## Geo Restriction (Geo-Blocking)

Restrict access to your content based on the geographic location of the viewer.

**Two modes:**
- **Allowlist:** Only users in specified countries can access the content.
- **Blocklist:** Users in specified countries are blocked; everyone else can access.

**How it works:** CloudFront uses a third-party GeoIP database to determine the viewer's country based on their IP address.

**Use case:** Licensing restrictions (e.g., video content only available in certain countries), regulatory compliance (e.g., GDPR-related restrictions).

---

## Field-Level Encryption

Protects sensitive data (e.g., credit card numbers) throughout the entire request chain, from the viewer to your origin.

**How it works:**
1. CloudFront encrypts specific form fields at the edge using a public key you provide.
2. The encrypted data travels through CloudFront to your origin.
3. Only your application (with the private key) can decrypt the data.
4. Even if CloudFront or intermediate systems are compromised, the sensitive fields remain encrypted.

**Use case:** E-commerce checkout forms where credit card numbers must be protected end-to-end.

**Exam tip:** Field-level encryption is specifically for protecting individual fields in POST requests. It is NOT the same as HTTPS (which encrypts the entire connection).

---

## CloudFront Functions vs Lambda@Edge

Both allow you to run code at CloudFront edge locations, but they differ significantly in capabilities and cost.

### Comparison Table

| Feature | CloudFront Functions | Lambda@Edge |
|---|---|---|
| **Runtime** | JavaScript only | Node.js, Python |
| **Execution location** | 450+ CloudFront edge locations | 13 CloudFront Regional Edge Caches |
| **Trigger points** | Viewer Request, Viewer Response only | Viewer Request, Viewer Response, Origin Request, Origin Response |
| **Max execution time** | < 1 ms | 5 seconds (viewer) / 30 seconds (origin) |
| **Max memory** | 2 MB | 128-10,240 MB |
| **Max package size** | 10 KB | 1 MB (viewer) / 50 MB (origin) |
| **Network access** | No | Yes |
| **File system access** | No | Yes (/tmp, 512 MB) |
| **Request body access** | No | Yes |
| **Pricing** | ~$0.10 per million invocations | ~$0.60 per million invocations + duration |
| **Scale** | Millions of requests per second | Thousands of requests per second |
| **Use cases** | URL rewrites, header manipulation, simple redirects, cache key normalization, JWT validation | A/B testing, user authentication, dynamic content generation, origin selection, image resizing |

### When to Use Which

| Scenario | Use |
|---|---|
| "Redirect HTTP to HTTPS" | CloudFront Functions |
| "Add security headers (HSTS, CSP)" | CloudFront Functions |
| "Normalize cache key (lowercase URLs)" | CloudFront Functions |
| "Simple URL rewrites" | CloudFront Functions |
| "Validate JWT tokens" | CloudFront Functions |
| "Resize images on the fly" | Lambda@Edge (needs compute) |
| "A/B testing with different origins" | Lambda@Edge (origin request trigger) |
| "User authentication with external service" | Lambda@Edge (needs network access) |
| "Generate dynamic HTML at edge" | Lambda@Edge (needs compute time) |
| "Modify response body" | Lambda@Edge (origin response trigger) |

### Trigger Points Explained

```
Viewer                CloudFront              Origin
  |                      |                      |
  |--- Request --------->|                      |
  |  [Viewer Request]    |                      |
  |                      |--- Request --------->|
  |                      | [Origin Request]     |
  |                      |                      |
  |                      |<--- Response --------|
  |                      | [Origin Response]    |
  |<--- Response --------|                      |
  |  [Viewer Response]   |                      |
```

- **Viewer Request:** Runs after CloudFront receives the request from the viewer, before checking the cache. (Both CF Functions and Lambda@Edge)
- **Viewer Response:** Runs before CloudFront sends the response to the viewer. (Both CF Functions and Lambda@Edge)
- **Origin Request:** Runs before CloudFront forwards the request to the origin (only on cache miss). (Lambda@Edge only)
- **Origin Response:** Runs after CloudFront receives the response from the origin, before caching. (Lambda@Edge only)

**Exam tip:** If the question needs origin request/response triggers, Lambda@Edge is the only option. If the question needs simple, lightweight, high-scale viewer-level processing, CloudFront Functions is cheaper and faster.

---

## CloudFront Price Classes

You can reduce costs by limiting which edge locations CloudFront uses:

| Price Class | Edge Locations Included | Cost |
|---|---|---|
| **Price Class All** | All 450+ edge locations worldwide | Highest |
| **Price Class 200** | Most regions (excludes most expensive) | Medium |
| **Price Class 100** | North America and Europe only | Lowest |

**Exam tip:** If the question says "reduce CloudFront costs" and the application only serves users in North America and Europe, use Price Class 100.

---

## Key Takeaways

1. **OAC is the current best practice** for S3 origins. OAI is legacy. OAC supports SSE-KMS, all HTTP methods, and all S3 regions.
2. **Signed URLs = one file, Signed Cookies = multiple files.** Choose based on whether you need to protect individual resources or an entire section.
3. **CloudFront Functions for simple, high-scale tasks; Lambda@Edge for complex tasks needing network, compute, or origin triggers.**
4. **Cache invalidation costs money.** Use object versioning (filename or query string) as a cheaper alternative.
5. **Origin groups enable failover** between a primary and secondary origin (useful for DR).
6. **Field-level encryption protects specific fields end-to-end**, beyond what HTTPS provides.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- What CloudFront Does
- CloudFront Origins
- OAC vs OAI -- Restricting S3 Access
- Cache Behaviors

**The gap is not what you forgot. It is where you used a word instead of a mechanism.**

| | |
|---|---|
| ✗ | *"The security group allows the traffic."* |
| ✓ | *"A security group is a stateful allow-list attached to an ENI. Traffic matching an inbound rule is permitted and the reply is permitted automatically, because the connection is tracked — which is why you never write an outbound rule for a reply."* |

**Trace it:** A request from the internet to an instance in a private subnet. Name every hop, every route-table lookup, and every rule evaluated, in order.

Stop at the first component you cannot name. Reopen this file and read **only** that.

**Go deeper — only once the gap has a name:** [Timeouts, retries and backoff with jitter](https://aws.amazon.com/builders-library/timeouts-retries-and-backoff-with-jitter/) — 15 minutes from the AWS Builders' Library, and it changes how you write every client you touch afterwards.
Full list per domain: [`SOURCES.md`](../SOURCES.md#aws)

→ Protocol, the three levels of knowing, and worked examples: [`MASTERY.md`](../MASTERY.md)

<!-- /feynman-check -->

# Distributed Rate Limiter

## 📋 Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Architecture](#architecture)
- [How It Works](#how-it-works)
- [Token Bucket Algorithm](#token-bucket-algorithm)
- [Redis Integration](#redis-integration)
- [Getting Started](#getting-started)
- [Configuration](#configuration)
- [API Usage](#api-usage)
- [Testing](#testing)
- [Project Structure](#project-structure)
- [Troubleshooting](#troubleshooting)

## 🎯 Overview

This distributed rate limiter is designed to protect your APIs from abuse by limiting the number of requests a client can make within a specific time window. It's built to work in distributed environments where multiple instances need to share rate limit state.

**Key Characteristics:**
- **Distributed**: Uses Redis for shared state across multiple instances
- **Flexible**: Supports API Key, User ID, and IP-based rate limiting
- **Efficient**: Uses Lua scripts for atomic operations in Redis
- **Production-Ready**: Includes health checks, proper error handling, and monitoring

## ✨ Features

- ✅ **Token Bucket Algorithm**: Smooth rate limiting with token refill
- ✅ **Multiple Identification Strategies**: API Key, User ID, or IP Address
- ✅ **Distributed State**: Redis-backed for multi-instance deployments
- ✅ **Atomic Operations**: Lua scripts ensure consistency
- ✅ **Configurable**: Adjustable capacity and refill rates
- ✅ **HTTP Headers**: Returns remaining tokens in response headers
- ✅ **Health Checks**: Built-in actuator endpoints for monitoring
- ✅ **Docker Support**: Easy deployment with Docker Compose

## 🏗️ Architecture

```
┌─────────────┐         ┌──────────────┐         ┌─────────────┐
│   Client    │────────▶│  Rate       │────────▶│    Redis     │
│  Request    │         │  Limiter    │         │   (State)    │
└─────────────┘         │  Service    │         └─────────────┘
                        └──────────────┘
                               │
                               ▼
                        ┌──────────────┐
                        │   Backend    │
                        │   Service    │
                        └──────────────┘
```

**Components:**
1. **RateLimitFilter**: Intercepts all HTTP requests
2. **KeyResolver**: Determines the rate limit key (API Key > User ID > IP)
3. **TokenBucketLimiter**: Implements the token bucket algorithm
4. **Redis**: Stores token bucket state (tokens, timestamp)
5. **Lua Script**: Ensures atomic token operations

## 🔄 How It Works

### Request Flow

1. **Request Arrives**: HTTP request hits the Spring Boot application
2. **Filter Intercepts**: `RateLimitFilter` intercepts the request before it reaches the controller
3. **Key Resolution**: `KeyResolver` determines the rate limit key using one of these strategies:
   - **PRIORITY** (default): Uses the most specific identifier available
     - Priority 1: `X-API-KEY` header
     - Priority 2: `X-USER-ID` header or authenticated user
     - Priority 3: Client IP address
   - **COMBINED**: Uses all identifiers together (more granular)
4. **Rate Limit Check**: `TokenBucketLimiter` executes a Lua script in Redis:
   - Calculates token refill based on time elapsed
   - Checks if tokens are available
   - Decrements token if request is allowed
   - Updates Redis with new state
5. **Response**:
   - **Allowed**: Request proceeds, `X-Rate-Limit-Remaining` header added
   - **Rate Limited**: Returns `429 Too Many Requests` with error message

### Example Flow

```
Request: GET /hello
Headers: X-API-KEY: abc123

1. Filter intercepts request
2. KeyResolver creates key: "rate:apikey:abc123"
3. TokenBucketLimiter checks Redis:
   - Current tokens: 5
   - Refill needed: +2 (based on time)
   - New tokens: min(10, 5+2) = 7
   - Request allowed? Yes (7 >= 1)
   - Decrement: 7 - 1 = 6
4. Response: 200 OK
   Headers: X-Rate-Limit-Remaining: 6
```

## 🪣 Token Bucket Algorithm

The Token Bucket algorithm is a popular rate limiting strategy that provides smooth traffic shaping.

### How It Works

1. **Bucket**: A container with a maximum capacity (e.g., 10 tokens)
2. **Tokens**: Each request consumes 1 token
3. **Refill**: Tokens are added back at a constant rate (e.g., 5 tokens/second)
4. **Behavior**:
   - If tokens are available → Request allowed, token consumed
   - If bucket is empty → Request rejected (429)

### Example

**Configuration:**
- Capacity: 10 tokens
- Refill Rate: 5 tokens/second

**Scenario:**
```
Time 0s:  Bucket = [10 tokens] → Request 1 allowed → [9 tokens]
Time 0.1s: Request 2 allowed → [8 tokens]
Time 0.2s: Request 3 allowed → [7 tokens]
...
Time 0.5s: Request 6 allowed → [4 tokens]
Time 1.0s: 0.5s elapsed → Refill: 0.5 * 5 = 2.5 tokens → [6.5 tokens]
Time 1.5s: Request 7 allowed → [5.5 tokens]
Time 2.0s: 1.0s elapsed → Refill: 1.0 * 5 = 5 tokens → [10 tokens] (capped)
```

### Advantages

- ✅ **Smooth Traffic**: Allows bursts up to capacity
- ✅ **Fair Refill**: Tokens refill at constant rate
- ✅ **Predictable**: Easy to understand and configure
- ✅ **Efficient**: Single Redis operation per request

## 🔴 Redis Integration

Redis is used as the distributed state store for rate limiting.

### Why Redis?

- **Fast**: In-memory database with sub-millisecond latency
- **Atomic Operations**: Lua scripts ensure consistency
- **Distributed**: Shared state across multiple instances
- **Persistence**: Optional persistence for durability

### Data Structure

Each rate limit key stores:
```redis
HASH: rate:apikey:abc123
  tokens: 6
  timestamp: 1705789200000
```

### Lua Script

The `token_bucket.lua` script performs atomic operations:

1. **Read**: Gets current tokens and timestamp
2. **Calculate**: Computes refill based on elapsed time
3. **Check**: Determines if request is allowed
4. **Update**: Writes new state atomically
5. **Expire**: Sets TTL to clean up unused keys

**Benefits:**
- ✅ **Atomic**: All operations happen in one Redis call
- ✅ **Consistent**: No race conditions
- ✅ **Efficient**: Single round-trip to Redis

## 🚀 Getting Started

### Prerequisites

- Docker and Docker Compose
- Java 17+ (for local development)
- Gradle (for local development)

### Quick Start with Docker

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd Distributed-Rate-Limiter
   ```

2. **Start services**
   ```bash
   docker-compose up -d
   ```

3. **Verify services are running**
   ```bash
   docker-compose ps
   ```

4. **Check health**
   ```bash
   curl http://localhost:8082/actuator/health
   ```

5. **Test the API**
   ```bash
   curl http://localhost:8082/hello
   ```

### Local Development

1. **Start Redis**
   ```bash
   docker run -d -p 6379:6379 redis:7-alpine
   ```

2. **Build the project**
   ```bash
   ./gradlew clean build
   ```

3. **Run the application**
   ```bash
   ./gradlew bootRun
   ```

4. **Access the application**
   - API: http://localhost:8082
   - Health: http://localhost:8082/actuator/health

## ⚙️ Configuration

### Application Configuration (`application.yml`)

```yaml
server:
  port: 8082

spring:
  data:
    redis:
      host: ${SPRING_DATA_REDIS_HOST:localhost}
      port: ${SPRING_DATA_REDIS_PORT:6379}
      timeout: ${SPRING_DATA_REDIS_TIMEOUT:2000ms}

rate-limiter:
  capacity: 10              # Maximum tokens in bucket
  refill-rate: 5           # Tokens added per second
  key-strategy: PRIORITY   # PRIORITY or COMBINED
```

### Docker Compose Environment Variables

```yaml
environment:
  - SERVER_PORT=8082
  - SPRING_DATA_REDIS_HOST=redis
  - SPRING_DATA_REDIS_PORT=6379
  - RATE_LIMITER_CAPACITY=10
  - RATE_LIMITER_REFILL_RATE=5
  - RATE_LIMITER_KEY_STRATEGY=PRIORITY
```

### Key Strategy Options

**PRIORITY** (Recommended):
- Uses most specific identifier available
- API Key > User ID > IP Address
- Example keys: `rate:apikey:abc123`, `rate:user:456`, `rate:ip:192.168.1.1`

**COMBINED**:
- Uses all identifiers together
- More granular but creates many keys
- Example key: `rate:apikey:abc123:user:456:ip:192.168.1.1`

## 📡 API Usage

### Basic Request

```bash
curl http://localhost:8082/hello
```

**Response:**
```
HTTP/1.1 200 OK
X-Rate-Limit-Remaining: 9

Hello, World!
```

### With API Key

```bash
curl -H "X-API-KEY: my-api-key" http://localhost:8082/hello
```

### With User ID

```bash
curl -H "X-USER-ID: user123" http://localhost:8082/hello
```

### Rate Limited Response

```bash
curl http://localhost:8082/hello
```

**Response:**
```
HTTP/1.1 429 Too Many Requests
X-Rate-Limit-Remaining: 0

{"error":"Rate limit exceeded"}
```

### Response Headers

- `X-Rate-Limit-Remaining`: Number of tokens remaining in the bucket

## 🧪 Testing

### Automated Test Script

Run the comprehensive test suite:

```bash
chmod +x test-rate-limiter.sh
./test-rate-limiter.sh
```

**Tests Included:**
1. Basic connectivity
2. Rate limit headers
3. Rapid requests (rate limit enforcement)
4. API Key based limiting
5. User ID based limiting
6. Concurrent requests
7. Multiple API keys (separate buckets)
8. Token refill mechanism

## 📁 Project Structure

```
Distributed-Rate-Limiter/
├── src/
│   ├── main/
│   │   ├── java/
│   │   │   └── com/platform/gateway/distributed_rate_limiter/
│   │   │       ├── config/
│   │   │       │   └── RedisConfig.java          # Redis configuration
│   │   │       ├── controller/
│   │   │       │   └── HelloController.java      # Sample endpoint
│   │   │       ├── filter/
│   │   │       │   └── RateLimitFilter.java      # Request interceptor
│   │   │       ├── limiter/
│   │   │       │   ├── RateLimiterService.java   # Rate limiter interface
│   │   │       │   └── TokenBucketLimiter.java  # Token bucket implementation
│   │   │       ├── model/
│   │   │       │   └── RateLimitResult.java     # Rate limit result model
│   │   │       └── util/
│   │   │           └── KeyResolver.java         # Key resolution logic
│   │   └── resources/
│   │       ├── application.yml                  # Application configuration
│   │       └── redis/
│   │           └── token_bucket.lua             # Redis Lua script
│   └── test/
├── build.gradle                                  # Build configuration
├── docker-compose.yml                            # Docker Compose setup
├── Dockerfile                                    # Docker image definition
├── test-rate-limiter.sh                          # Test script
└── README.md                                     # This file
```

## 🔧 Troubleshooting

### Container won't start

**Check logs:**
```bash
docker-compose logs rate-limiter-app
```

**Common issues:**
- Port already in use: Change port in `docker-compose.yml`
- Redis connection failed: Ensure Redis container is healthy
- Build failed: Check Dockerfile and build context

### Rate limiting not working

**Verify Redis connection:**
```bash
docker exec distributed-rate-limiter-app env | grep REDIS
```

**Check Redis data:**
```bash
docker exec distributed-rate-limiter-redis redis-cli KEYS "rate:*"
```

### Health check failing

**Check application logs:**
```bash
docker logs distributed-rate-limiter-app --tail 50
```

**Verify actuator endpoint:**
```bash
docker exec distributed-rate-limiter-app curl http://localhost:8082/actuator/health
```

---

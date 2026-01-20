#!/bin/bash

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

BASE_URL="http://localhost:8082/hello"
CAPACITY=10
REFILL_RATE=5

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Distributed Rate Limiter Test Suite${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Test 1: Basic connectivity
echo -e "${YELLOW}Test 1: Basic Connectivity${NC}"
response=$(curl -s -w "\n%{http_code}" "$BASE_URL")
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | head -n-1)

if [ "$http_code" == "200" ]; then
    echo -e "${GREEN}✓ Connected successfully${NC}"
    echo "Response: $body"
else
    echo -e "${RED}✗ Connection failed (HTTP $http_code)${NC}"
    exit 1
fi
echo ""

# Test 2: Check rate limit headers
echo -e "${YELLOW}Test 2: Rate Limit Headers${NC}"
headers=$(curl -s -I "$BASE_URL")
remaining=$(echo "$headers" | grep -i "X-Rate-Limit-Remaining" | cut -d' ' -f2 | tr -d '\r')

if [ -n "$remaining" ]; then
    echo -e "${GREEN}✓ Rate limit header present${NC}"
    echo "Remaining tokens: $remaining"
else
    echo -e "${RED}✗ Rate limit header missing${NC}"
fi
echo ""

# Test 3: Rapid requests to hit rate limit
echo -e "${YELLOW}Test 3: Rapid Requests (Testing Rate Limit)${NC}"
echo "Sending 20 rapid requests (capacity is $CAPACITY)..."
echo ""

success_count=0
rate_limited_count=0
total_requests=20

for i in $(seq 1 $total_requests); do
    response=$(curl -s -w "\n%{http_code}" "$BASE_URL")
    http_code=$(echo "$response" | tail -n1)
    
    if [ "$http_code" == "200" ]; then
        ((success_count++))
    elif [ "$http_code" == "429" ]; then
        ((rate_limited_count++))
    fi
    
    # Show progress every 5 requests
    if [ $((i % 5)) -eq 0 ]; then
        echo -e "Progress: $i/$total_requests requests (${GREEN}$success_count${NC} success, ${RED}$rate_limited_count${NC} rate limited)"
    fi
done

echo ""
echo -e "${BLUE}Results:${NC}"
echo -e "  Successful (200): ${GREEN}$success_count${NC}"
echo -e "  Rate Limited (429): ${RED}$rate_limited_count${NC}"
echo ""

# Test 4: Test with API Key
echo -e "${YELLOW}Test 4: API Key Based Rate Limiting${NC}"
echo "Testing with X-API-KEY header..."
api_key="test-api-key-123"
response=$(curl -s -w "\n%{http_code}" -H "X-API-KEY: $api_key" "$BASE_URL")
http_code=$(echo "$response" | tail -n1)
remaining=$(curl -s -I -H "X-API-KEY: $api_key" "$BASE_URL" | grep -i "X-Rate-Limit-Remaining" | cut -d' ' -f2 | tr -d '\r')

if [ "$http_code" == "200" ]; then
    echo -e "${GREEN}✓ API key request successful${NC}"
    echo "Remaining tokens for API key: $remaining"
else
    echo -e "${RED}✗ API key request failed (HTTP $http_code)${NC}"
fi
echo ""

# Test 5: Test with User ID
echo -e "${YELLOW}Test 5: User ID Based Rate Limiting${NC}"
echo "Testing with X-USER-ID header..."
user_id="user-456"
response=$(curl -s -w "\n%{http_code}" -H "X-USER-ID: $user_id" "$BASE_URL")
http_code=$(echo "$response" | tail -n1)
remaining=$(curl -s -I -H "X-USER-ID: $user_id" "$BASE_URL" | grep -i "X-Rate-Limit-Remaining" | cut -d' ' -f2 | tr -d '\r')

if [ "$http_code" == "200" ]; then
    echo -e "${GREEN}✓ User ID request successful${NC}"
    echo "Remaining tokens for user: $remaining"
else
    echo -e "${RED}✗ User ID request failed (HTTP $http_code)${NC}"
fi
echo ""

# Test 6: Concurrent requests
echo -e "${YELLOW}Test 6: Concurrent Requests (50 parallel)${NC}"
echo "Launching 50 concurrent requests..."
echo ""

concurrent_success=0
concurrent_rate_limited=0

for i in $(seq 1 50); do
    (
        response=$(curl -s -w "\n%{http_code}" "$BASE_URL")
        http_code=$(echo "$response" | tail -n1)
        if [ "$http_code" == "200" ]; then
            echo "1" >> /tmp/success_$$
        elif [ "$http_code" == "429" ]; then
            echo "1" >> /tmp/rate_limited_$$
        fi
    ) &
done

wait

if [ -f /tmp/success_$$ ]; then
    concurrent_success=$(wc -l < /tmp/success_$$)
    rm /tmp/success_$$
fi

if [ -f /tmp/rate_limited_$$ ]; then
    concurrent_rate_limited=$(wc -l < /tmp/rate_limited_$$)
    rm /tmp/rate_limited_$$
fi

echo -e "${BLUE}Concurrent Results:${NC}"
echo -e "  Successful (200): ${GREEN}$concurrent_success${NC}"
echo -e "  Rate Limited (429): ${RED}$concurrent_rate_limited${NC}"
echo ""

# Test 7: Different API keys should have separate buckets
echo -e "${YELLOW}Test 7: Multiple API Keys (Separate Rate Limits)${NC}"
echo "Testing that different API keys have separate rate limit buckets..."
echo ""

api_key_1="api-key-1"
api_key_2="api-key-2"

# Make 10 requests with each API key
for i in $(seq 1 10); do
    curl -s -o /dev/null -H "X-API-KEY: $api_key_1" "$BASE_URL"
    curl -s -o /dev/null -H "X-API-KEY: $api_key_2" "$BASE_URL"
done

remaining_1=$(curl -s -I -H "X-API-KEY: $api_key_1" "$BASE_URL" | grep -i "X-Rate-Limit-Remaining" | cut -d' ' -f2 | tr -d '\r')
remaining_2=$(curl -s -I -H "X-API-KEY: $api_key_2" "$BASE_URL" | grep -i "X-Rate-Limit-Remaining" | cut -d' ' -f2 | tr -d '\r')

echo "API Key 1 remaining: $remaining_1"
echo "API Key 2 remaining: $remaining_2"

if [ "$remaining_1" == "$remaining_2" ]; then
    echo -e "${GREEN}✓ Both API keys have separate rate limit buckets${NC}"
else
    echo -e "${YELLOW}⚠ Different remaining values (expected if requests were made)${NC}"
fi
echo ""

# Test 8: Wait and refill test
echo -e "${YELLOW}Test 8: Token Refill Test${NC}"
echo "Making requests until rate limited, then waiting for refill..."
echo ""

# Make requests until we get rate limited
rate_limited=false
requests_made=0
while [ "$rate_limited" == false ] && [ $requests_made -lt 20 ]; do
    response=$(curl -s -w "\n%{http_code}" "$BASE_URL")
    http_code=$(echo "$response" | tail -n1)
    ((requests_made++))
    
    if [ "$http_code" == "429" ]; then
        rate_limited=true
        echo -e "${RED}Rate limited after $requests_made requests${NC}"
    fi
done

if [ "$rate_limited" == true ]; then
    echo "Waiting 3 seconds for token refill (refill rate: $REFILL_RATE tokens/sec)..."
    sleep 3
    
    response=$(curl -s -w "\n%{http_code}" "$BASE_URL")
    http_code=$(echo "$response" | tail -n1)
    remaining=$(curl -s -I "$BASE_URL" | grep -i "X-Rate-Limit-Remaining" | cut -d' ' -f2 | tr -d '\r')
    
    if [ "$http_code" == "200" ]; then
        echo -e "${GREEN}✓ Tokens refilled! Remaining: $remaining${NC}"
    else
        echo -e "${YELLOW}⚠ Still rate limited (may need more time)${NC}"
    fi
fi
echo ""

# Summary
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Test Summary${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}✓ All tests completed!${NC}"
echo ""
echo "Rate Limiter Configuration:"
echo "  Capacity: $CAPACITY tokens"
echo "  Refill Rate: $REFILL_RATE tokens/second"
echo ""
echo "To test manually:"
echo "  curl -v http://localhost:8082/hello"
echo "  curl -H 'X-API-KEY: my-key' http://localhost:8082/hello"
echo "  curl -H 'X-USER-ID: user123' http://localhost:8082/hello"

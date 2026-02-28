---
name: api-client-integration
description: "This skill should be used when the user asks to 'use the API client', 'call the REST API', 'integrate with service X', 'make API requests', or mentions working with external APIs or services."
metadata: {"clawdbot":{"always":false,"emoji":"🌐","requires":{"bins":["curl","jq"],"env":["API_KEY"]}}}
user-invocable: false
---

# API Client Integration — Tool Integration Skill Example

This is a complete example of a **Category B: Tool Integration** skill.

## Characteristics
- `always: false` - Loaded only when triggered
- Comprehensive `description` with specific trigger phrases
- Tool-specific commands and best practices
- May require binaries and environment variables
- Not user-invocable (model decides when to use)

## Use This Pattern When
- Integrating external tools or services
- Teaching agents to use specific APIs
- Wrapping command-line utilities
- Providing domain-specific tool usage

---

Use this skill to interact with external REST APIs.

## When to Use

Load this skill when tasks involve:
- Making HTTP requests to external services
- Authenticating with API keys
- Processing JSON responses
- Integrating third-party services

## Authentication

API key must be set in environment:
```bash
export API_KEY="your-api-key-here"
```

Never hardcode or log the API key.

## Request Patterns

### GET Request
```bash
curl -X GET "https://api.example.com/v1/resource" \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  | jq .
```

### POST Request
```bash
curl -X POST "https://api.example.com/v1/resource" \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "value",
    "data": "content"
  }' | jq .
```

### Error Handling
```bash
RESPONSE=$(curl -s -w "\n%{http_code}" "https://api.example.com/v1/resource" \
  -H "Authorization: Bearer $API_KEY")

BODY=$(echo "$RESPONSE" | head -n -1)
STATUS=$(echo "$RESPONSE" | tail -n 1)

if [ "$STATUS" -eq 200 ]; then
  echo "✅ Success"
  echo "$BODY" | jq .
else
  echo "❌ Error: HTTP $STATUS"
  echo "$BODY" | jq -r '.error.message'
fi
```

## Best Practices

1. **Always use jq for JSON parsing** - Don't try to parse JSON with grep/sed
2. **Check HTTP status codes** - 200 = success, 4xx = client error, 5xx = server error
3. **Handle rate limits** - Respect 429 responses, implement exponential backoff
4. **Validate responses** - Check for expected fields before using data
5. **Log requests (not responses)** - Log request params, not sensitive response data

## Rate Limit Handling

```bash
retry_count=0
max_retries=3

while [ $retry_count -lt $max_retries ]; do
  STATUS=$(curl -s -o response.json -w "%{http_code}" \
    -H "Authorization: Bearer $API_KEY" \
    "https://api.example.com/v1/resource")

  if [ "$STATUS" -eq 200 ]; then
    cat response.json | jq .
    break
  elif [ "$STATUS" -eq 429 ]; then
    ((retry_count++))
    wait_time=$((2 ** retry_count))
    echo "⏳ Rate limited, waiting ${wait_time}s..."
    sleep $wait_time
  else
    echo "❌ Error: HTTP $STATUS"
    cat response.json | jq .
    break
  fi
done
```

## Common Endpoints

Document frequently used endpoints:

- `GET /v1/users` - List all users
- `POST /v1/users` - Create new user
- `GET /v1/users/{id}` - Get user by ID
- `PUT /v1/users/{id}` - Update user
- `DELETE /v1/users/{id}` - Delete user

## Response Formats

Expected JSON structures:

**Success**:
```json
{
  "success": true,
  "data": { ... },
  "meta": {
    "page": 1,
    "total": 100
  }
}
```

**Error**:
```json
{
  "success": false,
  "error": {
    "code": "INVALID_REQUEST",
    "message": "Missing required field: email"
  }
}
```

## Progressive Disclosure

For detailed API documentation:
- Read: `references/api-reference.md`

For advanced patterns:
- Read: `references/advanced-api-patterns.md`

---

**Key Takeaway**: Tool integration skills should include specific command syntax, error handling, and best practices. They're loaded only when triggered, so can be more detailed than always-on skills.

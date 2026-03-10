#!/bin/bash

# Test script for Postiz Integration
# This script verifies that the Postiz API is accessible using the provided credentials.

echo "=== Testing Postiz Integration ==="

# 1. 从环境变量读取配置（source .env.deploy 后运行）
POSTIZ_API_URL="${POSTIZ_API_URL:?请设置 POSTIZ_API_URL，例如: export POSTIZ_API_URL=http://your-host:4007/api}"
POSTIZ_API_KEY="${POSTIZ_API_KEY:?请设置 POSTIZ_API_KEY}"
export PATH="$HOME/.npm-global/bin:$PATH"

echo "POSTIZ_API_URL: $POSTIZ_API_URL"
echo "POSTIZ_API_KEY: ${POSTIZ_API_KEY:0:5}...${POSTIZ_API_KEY: -5}"

# 2. Test HTTP API Directly
echo -e "\n=== Testing HTTP API ==="
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $POSTIZ_API_KEY" "$POSTIZ_API_URL/public/v1/integrations")

if [ "$HTTP_STATUS" == "200" ]; then
    echo "✅ HTTP API Connection Successful (Status: 200)"
    echo "Integrations found:"
    curl -s -H "Authorization: Bearer $POSTIZ_API_KEY" "$POSTIZ_API_URL/public/v1/integrations" | jq '.[].provider' 2>/dev/null || echo "Could not parse JSON"
else
    echo "❌ HTTP API Connection Failed (Status: $HTTP_STATUS)"
    curl -s -H "Authorization: Bearer $POSTIZ_API_KEY" "$POSTIZ_API_URL/public/v1/integrations"
fi

# 3. Test CLI (if installed locally)
if command -v postiz &> /dev/null; then
    echo -e "\n=== Testing Postiz CLI ==="
    postiz integrations:list || echo "CLI command failed."
else
    echo -e "\n⚠️ Postiz CLI not found in local PATH. Skipping CLI test."
    echo "To test CLI, run: npm install -g postiz"
fi

echo -e "\n=== Test Complete ==="

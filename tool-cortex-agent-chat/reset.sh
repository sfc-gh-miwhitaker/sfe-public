#!/bin/bash
# Save this as tools/cortex-agent-chat/reset.sh

cd "$(dirname "$0")"

echo "🧹 Cleaning up Cortex Agent Chat..."

# Stop any running processes
pkill -f "node server/index.js" 2>/dev/null || true
pkill -f "react-scripts start" 2>/dev/null || true

# Remove generated files
rm -f .env.local .env.server.local
rm -f rsa_key.pem rsa_key.pub
rm -f deploy_with_key.sql
rm -rf .pids
rm -f npm-debug.log

# Remove dependencies
rm -rf node_modules
rm -f package-lock.json

echo "✅ Clean! Now run: ./tools/01_setup.sh"

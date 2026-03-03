#!/bin/bash

cd "$(dirname "$0")/.."

echo "=== Service Status ==="

if [ -f .pids/backend.pid ] && kill -0 "$(cat .pids/backend.pid)" 2>/dev/null; then
  echo "Backend:  RUNNING (PID: $(cat .pids/backend.pid))"
else
  echo "Backend:  STOPPED"
fi

if [ -f .pids/frontend.pid ] && kill -0 "$(cat .pids/frontend.pid)" 2>/dev/null; then
  echo "Frontend: RUNNING (PID: $(cat .pids/frontend.pid))"
else
  echo "Frontend: STOPPED"
fi

echo ""
echo "=== Port Status ==="
lsof -ti :3000 >/dev/null 2>&1 && echo "Port 3000 (frontend): IN USE" || echo "Port 3000 (frontend): FREE"
lsof -ti :3001 >/dev/null 2>&1 && echo "Port 3001 (backend):  IN USE" || echo "Port 3001 (backend):  FREE"

echo ""
echo "=== Environment ==="
if [ -n "$SNOWFLAKE_ACCOUNT" ]; then
  echo "SNOWFLAKE_ACCOUNT: $SNOWFLAKE_ACCOUNT"
else
  echo "SNOWFLAKE_ACCOUNT: NOT SET"
fi
if [ -n "$SNOWFLAKE_PAT" ]; then
  echo "SNOWFLAKE_PAT:     (set)"
else
  echo "SNOWFLAKE_PAT:     NOT SET"
fi

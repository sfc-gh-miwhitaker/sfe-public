#!/bin/bash

cd "$(dirname "$0")/.."

echo "Stopping services..."

if [ -f .pids/backend.pid ]; then
  kill "$(cat .pids/backend.pid)" 2>/dev/null && echo "Backend stopped" || echo "Backend was not running"
  rm .pids/backend.pid
fi

if [ -f .pids/frontend.pid ]; then
  kill "$(cat .pids/frontend.pid)" 2>/dev/null && echo "Frontend stopped" || echo "Frontend was not running"
  rm .pids/frontend.pid
fi

echo "All services stopped."

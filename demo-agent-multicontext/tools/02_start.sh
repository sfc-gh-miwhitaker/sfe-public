#!/bin/bash
set -e

cd "$(dirname "$0")/.."

if [ -z "$SNOWFLAKE_ACCOUNT" ] || [ -z "$SNOWFLAKE_PAT" ]; then
  echo "ERROR: Required environment variables not set."
  echo ""
  echo "  export SNOWFLAKE_ACCOUNT=\"myorg-myaccount\""
  echo "  export SNOWFLAKE_PAT=\"your-personal-access-token\""
  echo ""
  echo "Get a PAT: Snowsight -> Settings -> Authentication -> Personal Access Tokens"
  exit 1
fi

mkdir -p .pids

echo "Installing backend dependencies..."
cd backend && npm install --silent && cd ..

echo "Installing frontend dependencies..."
cd frontend && npm install --silent && cd ..

echo "Starting backend on http://localhost:3001..."
cd backend && npm start &
BACKEND_PID=$!
echo $BACKEND_PID > ../.pids/backend.pid
cd ..

sleep 2
if ! kill -0 "$BACKEND_PID" 2>/dev/null; then
  echo "ERROR: Backend failed to start. Check SNOWFLAKE_ACCOUNT and SNOWFLAKE_PAT."
  exit 1
fi

echo "Starting frontend on http://localhost:3000..."
cd frontend && npm run dev &
FRONTEND_PID=$!
echo $FRONTEND_PID > ../.pids/frontend.pid
cd ..

echo ""
echo "Services started:"
echo "  Frontend: http://localhost:3000"
echo "  Backend:  http://localhost:3001"
echo "  Health:   http://localhost:3001/health"
echo ""
echo "Check status: ./tools/03_status.sh"
echo "Stop:         ./tools/04_stop.sh"

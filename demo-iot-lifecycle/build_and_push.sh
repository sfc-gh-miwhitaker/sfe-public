#!/bin/bash
set -euo pipefail

echo "============================================"
echo "  IoT Fleet Dashboard -- Build & Push"
echo "============================================"
echo ""

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="$SCRIPT_DIR/app"

# Preflight checks
if ! command -v snow &> /dev/null; then
    echo "ERROR: Snow CLI not found."
    echo "Install: pip install snowflake-cli"
    echo "Docs:    https://docs.snowflake.com/en/developer-guide/snowflake-cli/installation"
    exit 1
fi

if ! command -v podman &> /dev/null; then
    echo "ERROR: Podman not found."
    echo "Install: brew install podman"
    exit 1
fi

if ! command -v node &> /dev/null; then
    echo "ERROR: Node.js not found."
    echo "Install: brew install node"
    exit 1
fi

echo "Step 1: Building React frontend..."
echo ""
cd "$APP_DIR/frontend"
npm install --silent
npm run build
echo "  Done -- app/frontend/dist/"
echo ""

echo "Step 2: Getting your image repository URL from Snowflake..."
echo ""
REPO_URL=$(snow sql -q "SELECT repository_url FROM (SHOW IMAGE REPOSITORIES LIKE 'IOT_IMAGE_REPO' IN SCHEMA SNOWFLAKE_EXAMPLE.IOT_LIFECYCLE) WHERE \"name\" = 'IOT_IMAGE_REPO'" --format=json 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin)[0]['REPOSITORY_URL'])" 2>/dev/null || echo "")

if [ -z "$REPO_URL" ]; then
    echo "  Could not auto-detect repository URL."
    echo "  Run this in Snowsight to find it:"
    echo ""
    echo "    SHOW IMAGE REPOSITORIES LIKE 'IOT_IMAGE_REPO' IN SCHEMA SNOWFLAKE_EXAMPLE.IOT_LIFECYCLE;"
    echo ""
    echo "  Copy the repository_url value (looks like: orgname-acctname.registry.snowflakecomputing.com/snowflake_example/iot_lifecycle/iot_image_repo)"
    echo ""
    read -p "  Paste repository_url: " REPO_URL
    if [ -z "$REPO_URL" ]; then
        echo "ERROR: repository_url required. Run deploy_all.sql first to create the image repo."
        exit 1
    fi
fi

REGISTRY=$(echo "$REPO_URL" | cut -d'/' -f1)
IMAGE_TAG="${REPO_URL}/fleet-dashboard:latest"
echo "  Registry: $REGISTRY"
echo "  Image:    $IMAGE_TAG"
echo ""

echo "Step 3: Building container (linux/amd64 for SPCS)..."
echo ""
cd "$APP_DIR"
podman build --platform linux/amd64 -t fleet-dashboard .
podman tag fleet-dashboard "$IMAGE_TAG"
echo ""

echo "Step 4: Authenticating to Snowflake registry via Snow CLI..."
echo ""
snow spcs image-registry token --format=JSON | podman login "$REGISTRY" -u 0sessiontoken --password-stdin
echo ""

echo "Step 5: Pushing image..."
echo ""
podman push "$IMAGE_TAG"

echo ""
echo "============================================"
echo "  SUCCESS! Image pushed to Snowflake."
echo "============================================"
echo ""
echo "  Next: Run deploy_service.sql in Snowsight"
echo "  The SHOW ENDPOINTS output gives you the dashboard URL."
echo ""

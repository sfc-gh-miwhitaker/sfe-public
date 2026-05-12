#!/bin/bash
#==============================================================================
# BUILD & PUSH -- IoT Fleet Dashboard Container
#
# Run this AFTER deploy_all.sql completes in Snowsight.
# It builds the React app + FastAPI backend into a container and pushes
# it to your Snowflake image repository.
#
# Prerequisites:
#   - podman installed (brew install podman / dnf install podman)
#   - Snowflake CLI installed (for registry login)
#   - deploy_all.sql already run in Snowsight
#
# Usage:
#   cd demo-iot-lifecycle
#   ./build_and_push.sh
#==============================================================================

set -euo pipefail

echo "============================================"
echo "  IoT Fleet Dashboard -- Build & Push"
echo "============================================"
echo ""

# Get the registry URL from Snowflake
echo "Step 1: Fetching your image repository URL from Snowflake..."
echo ""
echo "Run this query in Snowsight and copy the repository_url value:"
echo ""
echo "  SHOW IMAGE REPOSITORIES LIKE 'IOT_IMAGE_REPO' IN SCHEMA SNOWFLAKE_EXAMPLE.IOT_LIFECYCLE;"
echo ""
echo "The repository_url column looks like:"
echo "  <orgname>-<acctname>.registry.snowflakecomputing.com/snowflake_example/iot_lifecycle/iot_image_repo"
echo ""
read -p "Paste your repository_url here: " REPO_URL

if [ -z "$REPO_URL" ]; then
    echo "ERROR: repository_url is required. Run the SHOW IMAGE REPOSITORIES query first."
    exit 1
fi

REGISTRY=$(echo "$REPO_URL" | cut -d'/' -f1)
IMAGE_TAG="${REPO_URL}/fleet-dashboard:latest"

echo ""
echo "Step 2: Building container image (linux/amd64 for SPCS)..."
echo "  Image: $IMAGE_TAG"
echo ""

podman build --platform linux/amd64 -t fleet-dashboard app/

echo ""
echo "Step 3: Tagging..."
podman tag fleet-dashboard "$IMAGE_TAG"

echo ""
echo "Step 4: Logging in to Snowflake registry..."
echo "  Registry: $REGISTRY"
echo "  (Use your Snowflake username and password when prompted)"
echo ""
podman login "$REGISTRY"

echo ""
echo "Step 5: Pushing image to Snowflake..."
podman push "$IMAGE_TAG"

echo ""
echo "============================================"
echo "  SUCCESS! Image pushed."
echo "============================================"
echo ""
echo "Final step: Run deploy_service.sql in Snowsight to start the service."
echo "The dashboard URL will appear in the SHOW ENDPOINTS output."
echo ""

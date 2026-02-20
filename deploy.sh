cat > deploy.sh <<'EOF'
#!/bin/bash
set -e

NET="cicd-net"
IMAGE="myapp:latest"
BLUE="myapp-blue"
GREEN="myapp-green"
NGINX="nginx-proxy"

# Ensure docker network exists
docker network inspect "$NET" >/dev/null 2>&1 || docker network create "$NET"

# Find current active container (blue or green)
ACTIVE=$(docker ps --format "{{.Names}}" | grep -E "^(${BLUE}|${GREEN})$" || true)

if [ "$ACTIVE" == "$BLUE" ]; then
  NEW="$GREEN"
  OLD="$BLUE"
else
  NEW="$BLUE"
  OLD="$GREEN"
fi

echo "👉 Deploying $NEW (image: $IMAGE)"

# Start NEW container
docker rm -f "$NEW" >/dev/null 2>&1 || true
docker run -d --name "$NEW" --network "$NET" "$IMAGE"

# Health check NEW container
echo "✅ Health check $NEW..."
sleep 2
docker exec "$NEW" wget -qO- http://localhost >/dev/null

# Create runtime nginx config pointing to NEW container
echo "🔁 Updating nginx upstream -> $NEW"
sed "s/APP_UPSTREAM/${NEW}/g" nginx.conf > nginx.runtime.conf

# Restart nginx-proxy with updated config (reliable)
docker rm -f "$NGINX" >/dev/null 2>&1 || true
docker run -d --name "$NGINX" --network "$NET" -p 80:80 \
  -v "$(pwd)/nginx.runtime.conf:/etc/nginx/nginx.conf:ro" nginx:alpine

# Remove OLD container
if [ -n "$OLD" ]; then
  echo "🧹 Removing old container: $OLD"
  docker rm -f "$OLD" >/dev/null 2>&1 || true
fi

echo "🎉 Deployment done! Active: $NEW"
EOF

chmod +x deploy.sh

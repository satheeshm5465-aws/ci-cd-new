cat > deploy.sh <<'EOF'
#!/bin/bash
set -e

NET="cicd-net"
IMAGE="myapp:latest"
BLUE="myapp-blue"
GREEN="myapp-green"
NGINX="nginx-proxy"

docker network inspect "$NET" >/dev/null 2>&1 || docker network create "$NET"

ACTIVE=$(docker ps --format "{{.Names}}" | grep -E "^(${BLUE}|${GREEN})$" || true)

if [ "$ACTIVE" == "$BLUE" ]; then
  NEW="$GREEN"
  OLD="$BLUE"
else
  NEW="$BLUE"
  OLD="$GREEN"
fi

echo "👉 Deploying $NEW"

docker rm -f "$NEW" >/dev/null 2>&1 || true
docker run -d --name "$NEW" --network "$NET" "$IMAGE"

echo "✅ Health check..."
sleep 2
docker exec "$NEW" wget -qO- http://localhost >/dev/null

cat > nginx.conf <<CONF
events {}

http {
  upstream myapp {
    server ${NEW}:80;
  }

  server {
    listen 80;
    location / {
      proxy_pass http://myapp;
    }
  }
}
CONF

docker rm -f "$NGINX" >/dev/null 2>&1 || true
docker run -d --name "$NGINX" --network "$NET" -p 80:80 \
  -v "$(pwd)/nginx.conf:/etc/nginx/nginx.conf:ro" nginx:alpine

docker rm -f "$OLD" >/dev/null 2>&1 || true

echo "🎉 Done. Active = $NEW"
EOF

chmod +x deploy.sh

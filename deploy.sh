#!/bin/bash
set -e

IMAGE="myapp:latest"
BLUE="myapp-blue"
GREEN="myapp-green"

BLUE_PORT=8081
GREEN_PORT=8082

ACTIVE=$(docker ps --format "{{.Names}}" | grep -E "^$BLUE$|^$GREEN$" || true)

if [ "$ACTIVE" == "$BLUE" ]; then
  NEW="$GREEN"
  NEW_PORT=$GREEN_PORT
  OLD="$BLUE"
else
  NEW="$BLUE"
  NEW_PORT=$BLUE_PORT
  OLD="$GREEN"
fi

echo "👉 Deploying $NEW on port $NEW_PORT"

docker rm -f $NEW || true
docker run -d --name $NEW -p $NEW_PORT:80 $IMAGE

echo "✅ Running health check..."
sleep 3
curl -f http://localhost:$NEW_PORT >/dev/null

echo "🔁 Updating Nginx upstream to $NEW_PORT"
sed -i "s/server 127.0.0.1:[0-9]\+/server 127.0.0.1:$NEW_PORT/" nginx.conf

echo "♻ Reloading Nginx container"
docker rm -f nginx-proxy || true
docker run -d --name nginx-proxy -p 80:80 -v $(pwd)/nginx.conf:/etc/nginx/nginx.conf:ro nginx:alpine

echo "🧹 Stopping old container: $OLD"
docker rm -f $OLD || true

echo "🎉 Deployment Successful! Live on http://SERVER_PUBLIC_IP/"

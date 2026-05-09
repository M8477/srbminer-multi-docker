#!/bin/bash
set -euo pipefail

IMAGE="ghcr.io/m8477/srbminer-multi-docker"
VERSION=$(grep -oP 'ARG VERSION_TAG=\K[0-9.]+' Dockerfile)
EXPECTED_MD5=$(grep -oP 'ARG EXPECTED_MD5=\K[0-9a-f]+' Dockerfile)

echo "Building $IMAGE:$VERSION (MD5: $EXPECTED_MD5) ..."
docker build \
  --build-arg "VERSION_TAG=$VERSION" \
  --build-arg "EXPECTED_MD5=$EXPECTED_MD5" \
  --tag "$IMAGE:$VERSION" \
  --tag "$IMAGE:latest" \
  .

echo "Done. Push with:"
echo "  docker push $IMAGE:$VERSION"
echo "  docker push $IMAGE:latest"

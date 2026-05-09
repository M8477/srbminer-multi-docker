#!/bin/bash
set -euo pipefail

IMAGE="ghcr.io/m8477/srbminer-multi-docker"
VERSION=$(grep -oP 'ARG VERSION_TAG=\K[0-9.]+' Dockerfile)

echo "Building $IMAGE:$VERSION ..."
docker build --build-arg "VERSION_TAG=$VERSION" --tag "$IMAGE:$VERSION" --tag "$IMAGE:latest" .

echo "Done. Push with:"
echo "  docker push $IMAGE:$VERSION"
echo "  docker push $IMAGE:latest"

#!/bin/sh
set -e

BUILD_FAST=0
UBUNTU_BASE=0
TAG_SUFFIX=""

while [ "$1" != "" ]; do
  case "$1" in
    "--fast")
      BUILD_FAST=1
      echo "Fast build enabled"
      shift
      ;;
    "--ubuntu")
      UBUNTU_BASE=1
      TAG_SUFFIX="-ubuntu"
      echo "Ubuntu base image enabled"
      shift
      ;;
    * )
      # unknown param causes args to be passed through to $@
      break
      ;;
  esac
done

_grafana_tag=v11.5.1
_docker_repo=${2:-widhaprasa/grafana}

# If the tag starts with v, treat this as an official release
if echo "$_grafana_tag" | grep -q "^v"; then
  _grafana_version=$(echo "${_grafana_tag}" | cut -d "v" -f 2)
else
  _grafana_version=$_grafana_tag
fi

echo "Building ${_docker_repo}:${_grafana_version}${TAG_SUFFIX}"

export DOCKER_CLI_EXPERIMENTAL=enabled

# Build grafana image for a specific arch
docker_build () {
  arch=$1

  case "$arch" in
    "x64")
      base_arch=""
      repo_arch=""
      ;;
    "armv7")
      base_arch="arm32v7/"
      repo_arch="-arm32v7-linux"
      ;;
    "arm64")
      base_arch="arm64v8/"
      repo_arch="-arm64v8-linux"
      ;;
  esac
  if [ $UBUNTU_BASE = "0" ]; then
    libc="-musl"
    base_image="${base_arch}alpine:3.18.5"
  else
    libc=""
    base_image="${base_arch}ubuntu:22.04"
  fi

  grafana_tgz=${GRAFANA_TGZ:-"grafana-latest.linux-${arch}${libc}.tar.gz"}
  tag="${_docker_repo}${repo_arch}:${_grafana_version}${TAG_SUFFIX}"

  DOCKER_BUILDKIT=1 \
  docker build \
    --build-arg BASE_IMAGE=${base_image} \
    --build-arg GRAFANA_TGZ=${grafana_tgz} \
    --build-arg GO_SRC=tgz-builder \
    --build-arg JS_SRC=tgz-builder \
    --build-arg RUN_SH=./run.sh \
    --tag "${tag}" \
    --no-cache=true \
    --file Dockerfile.go.build \
    .
}

docker_tag_linux_amd64 () {
  tag=$1
  docker tag "${_docker_repo}:${_grafana_version}${TAG_SUFFIX}" "${_docker_repo}:${tag}${TAG_SUFFIX}"
}

# Tag docker images of all architectures
docker_tag_all () {
  tag=$1
  docker_tag_linux_amd64 $1
  if [ $BUILD_FAST = "0" ]; then
    docker tag "${_docker_repo}-arm32v7-linux:${_grafana_version}${TAG_SUFFIX}" "${_docker_repo}-arm32v7-linux:${tag}${TAG_SUFFIX}"
    docker tag "${_docker_repo}-arm64v8-linux:${_grafana_version}${TAG_SUFFIX}" "${_docker_repo}-arm64v8-linux:${tag}${TAG_SUFFIX}"
  fi
}

docker_build "x64"

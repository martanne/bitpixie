#!/bin/sh

docker run --platform linux/amd64 --rm -v "$PWD":/mnt -w /root \
    alpine:3.20.3 "/mnt/download-docker.sh"

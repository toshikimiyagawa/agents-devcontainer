# Dogfood: this repo uses its own published base image as the devcontainer.
# To iterate on Dockerfile.base locally, build it manually first:
#   docker build -t agents-base:dev -f .devcontainer/Dockerfile.base .
# then temporarily change the FROM below to `agents-base:dev`.
ARG BASE_IMAGE=ghcr.io/toshikimiyagawa/agents-devcontainer:latest
FROM ${BASE_IMAGE}

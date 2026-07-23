#!/usr/bin/env bash
# Initialize Hermes Agent configuration for the ubuntu user so the devcontainer
# works out of the box with the custom vLLM endpoint (qwen3.6-35b-a3b).
#
# This script runs as root during Docker build, right after Hermes is installed.
# It creates ~/.hermes/config.yaml with the custom provider settings and
# ~/.hermes/.env with a dummy api_key (vLLM instance has no auth).
set -euo pipefail

HOME=/home/ubuntu
HERMES_HOME="$HOME/.hermes"

mkdir -p "$HERMES_HOME"

# --- config.yaml --------------------------------------------------------------
# The "custom" provider is Hermes's generic OpenAI-compatible endpoint.
# Set model.default, model.provider, model.base_url, model.api_key at the top level
# (Hermes reads them in the first pass, before section-based routing).
cat > "$HERMES_HOME/config.yaml" <<'EOF'
model:
  default: qwen3.6-35b-a3b
  provider: custom
  base_url: https://vllm.solvelio.com/v1
  api_key: dummy
  max_token: 8192

agent:
  max_turns: 150
  tool_use_enforcement: auto

terminal:
  backend: local
  timeout: 180

compression:
  enabled: true
  threshold: 0.5
  target_ratio: 0.2

display:
  skin: default
  language: ja
  show_cost: false

memory:
  memory_enabled: true
  user_profile_enabled: true

approvals:
  mode: manual

security:
  redact_secrets: true
EOF

# --- .env (minimal — no secrets needed for the custom vLLM endpoint) -----------
cat > "$HERMES_HOME/.env" <<'EOF'
# Hermes Agent environment configuration
# Custom vLLM endpoint (no auth required)
EOF

# Set correct ownership (ubuntu:ubuntu)
chown -R ubuntu:ubuntu "$HERMES_HOME"

echo "[hermes-init] config written to $HERMES_HOME/config.yaml"

#!/usr/bin/env bash
set -euo pipefail

PROJECT="${1:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
BASE="${BASE_JSON:-$PROJECT/vendor/agents-devcontainer/scaffold/devcontainer.base.json}"
PROJ_JSON_PATH="${PROJ_JSON_FILE:-$PROJECT/.devcontainer/devcontainer.project.json}"
OUTPUT="${OUTPUT_FILE:-$PROJECT/.devcontainer/devcontainer.json}"

log() { printf '[merge.sh] %s\n' "$*"; }

if [[ ! -f "$BASE" ]]; then
  log "error: base config not found: $BASE" >&2
  exit 1
fi

PROJ_CONTENT='{}'
if [[ -f "$PROJ_JSON_PATH" ]]; then
  PROJ_CONTENT=$(cat "$PROJ_JSON_PATH")
fi

NAME=$(printf '%s' "$PROJ_CONTENT" | jq -r '.name // empty' 2>/dev/null || true)
[[ -z "$NAME" ]] && NAME=$(basename "$PROJECT")

jq -n \
  --argjson base "$(cat "$BASE")" \
  --argjson proj "$PROJ_CONTENT" \
  --arg name "$NAME" \
  '
    ($base) as $b |
    ($proj) as $p |

    $b
    | .name = $name
    | (if ($p | has("build")) then del(.image) | .build = $p.build
       elif ($p | has("image")) then .image = $p.image
       else . end)
    | .mounts = (($b.mounts // []) + ($p.mounts // []))
    | .remoteEnv = (($b.remoteEnv // {}) + ($p.remoteEnv // {}))
    | if ($p | has("postCreateCommand")) then .postCreateCommand = $p.postCreateCommand else . end
    | if ($p | has("postStartCommand")) then .postStartCommand = $p.postStartCommand else . end
    | . + ($p | del(.name, .image, .build, .mounts, .remoteEnv, .postCreateCommand, .postStartCommand))
  ' > "$OUTPUT"

log "generated $OUTPUT"

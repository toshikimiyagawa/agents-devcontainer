#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

if [ -r /etc/os-release ]; then
  . /etc/os-release
else
  echo "Unsupported OS: /etc/os-release is missing" >&2
  exit 1
fi

case " ${ID:-} ${ID_LIKE:-} " in
  *" debian "*|*" ubuntu "*)
    ;;
  *)
    echo "Unsupported OS: Agents Devcontainer Tooling initially supports Debian/Ubuntu containers only." >&2
    exit 1
    ;;
esac

install -d -m 0755 /usr/local/bin
install -d -m 0777 /usr/local/share/agents-devcontainer/state
install -m 0755 "$SCRIPT_DIR/scripts/agents-feature-post-create" /usr/local/bin/agents-feature-post-create
install -m 0755 "$SCRIPT_DIR/scripts/agents-feature-post-start" /usr/local/bin/agents-feature-post-start


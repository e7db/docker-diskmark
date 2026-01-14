#!/bin/bash
# update.sh - Update check functionality
# Provides: check_for_updates

is_semver() {
  [[ "$1" =~ ^v?[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.]+)?$ ]]
}

check_for_updates() {
  if [[ "$UPDATE_CHECK" -eq 1 ]] && [ -f "$VERSION_FILE" ]; then
    CURRENT_VERSION="$SCRIPT_VERSION"
    LATEST_VERSION=$(wget --no-check-certificate -qO- https://api.github.com/repos/e7db/docker-diskmark/releases/latest 2>/dev/null | grep '"tag_name"' | cut -d'"' -f4 || true)
    if [[ "$CURRENT_VERSION" != "unknown" ]] && is_semver "$CURRENT_VERSION" && is_semver "$LATEST_VERSION" && [[ "$CURRENT_VERSION" != "$LATEST_VERSION" ]]; then
      echo -e "Update available: \e[1;37m$CURRENT_VERSION\e[0m => \e[1;37m$LATEST_VERSION\e[0m (docker pull e7db/diskmark:latest)\n"
    fi
  fi
}

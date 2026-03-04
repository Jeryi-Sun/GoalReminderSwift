#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="$ROOT_DIR/release/GoalReminderSwift.app"

if [[ ! -d "$APP_PATH" ]]; then
  "$ROOT_DIR/scripts/build_release_app.sh"
fi

open "$APP_PATH"

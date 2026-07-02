#!/usr/bin/env bash
# cc — запуск Claude Code с выбранным провайдером (отдельный исполняемый файл).
#
# Использование:  cc <claude|glm|ds> [аргументы claude ...]
# Примеры:        cc glm
#                 cc ds --resume
#
# Удобно для JetBrains: в Settings -> Tools -> Claude Code в поле
# "Claude command" укажите, например:  cc glm
set -euo pipefail

CC_PROVIDERS_DIR="${CC_PROVIDERS_DIR:-$HOME/.config/cc-providers}"

if [ ! -f "$CC_PROVIDERS_DIR/cc-providers.sh" ]; then
  echo "cc: не найден $CC_PROVIDERS_DIR/cc-providers.sh" >&2
  exit 1
fi
# shellcheck source=/dev/null
. "$CC_PROVIDERS_DIR/cc-providers.sh"

provider="${1:-claude}"
shift || true

_cc_apply "$provider"
exec claude "$@"

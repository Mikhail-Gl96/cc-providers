#!/usr/bin/env bash
# install.sh — быстрая установка тулкита cc-providers.
#
# Что делает:
#   1) проверяет зависимости (python 3.11+ с tomllib; claude CLI — предупреждение);
#   2) копирует библиотеку/механику/провайдеров в ~/.config/cc-providers;
#   3) кладёт лаунчеры cc и cc-use в ~/bin;
#   4) подключает библиотеку и PATH в ваш shell rc (~/.zshrc или ~/.bashrc).
#
# Идемпотентно: можно запускать повторно. Существующий keys.env НЕ затирается.
#
# Переопределяемые переменные окружения:
#   CC_PROVIDERS_DIR  куда класть конфиг   (по умолчанию ~/.config/cc-providers)
#   BIN_DIR           куда класть лаунчеры  (по умолчанию ~/bin)
set -euo pipefail

CONFIG_DIR="${CC_PROVIDERS_DIR:-$HOME/.config/cc-providers}"
BIN_DIR="${BIN_DIR:-$HOME/bin}"
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ok()   { printf '\033[32m✓\033[0m %s\n' "$*"; }
warn() { printf '\033[33m!\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[31m✗ %s\033[0m\n' "$*" >&2; exit 1; }

# Файлы, которые ожидаем рядом со скриптом.
for f in cc-providers.sh cc-settings.py providers.toml cc cc-use keys.env.example; do
  [ -f "$SRC_DIR/$f" ] || die "рядом со скриптом нет $f — запускайте install.sh из папки репозитория"
done

echo "==> Проверка зависимостей"

command -v python3 >/dev/null 2>&1 || die "python3 не найден. Нужен python 3.11+ (для tomllib)."
if ! python3 -c 'import sys; sys.exit(0 if sys.version_info >= (3, 11) else 1)'; then
  die "нужен python 3.11+, а найден $(python3 -V 2>&1). Модуль tomllib появился в 3.11."
fi
python3 -c 'import tomllib' 2>/dev/null || die "модуль tomllib недоступен (python старше 3.11?)."
ok "python $(python3 -c 'import sys; print(".".join(map(str, sys.version_info[:3])))') — tomllib на месте"

if command -v claude >/dev/null 2>&1; then
  ok "claude CLI найден ($(command -v claude))"
else
  warn "claude CLI не найден — тулкит запускает именно его."
  warn "  установите Claude Code: https://claude.com/claude-code"
fi

echo "==> Установка файлов"
mkdir -p "$CONFIG_DIR" "$BIN_DIR"

install -m 0644 "$SRC_DIR/cc-providers.sh" "$CONFIG_DIR/cc-providers.sh"
install -m 0644 "$SRC_DIR/cc-settings.py"  "$CONFIG_DIR/cc-settings.py"
install -m 0644 "$SRC_DIR/providers.toml"  "$CONFIG_DIR/providers.toml"
ok "конфиг -> $CONFIG_DIR"

if [ -f "$CONFIG_DIR/keys.env" ]; then
  ok "keys.env уже есть — оставляю без изменений"
else
  install -m 0600 "$SRC_DIR/keys.env.example" "$CONFIG_DIR/keys.env"
  ok "создан $CONFIG_DIR/keys.env (chmod 600) — впишите в него ключи"
fi

install -m 0755 "$SRC_DIR/cc"     "$BIN_DIR/cc"
install -m 0755 "$SRC_DIR/cc-use" "$BIN_DIR/cc-use"
ok "лаунчеры -> $BIN_DIR (cc, cc-use)"

echo "==> Подключение к shell"
case "${SHELL##*/}" in
  zsh)  RC="$HOME/.zshrc" ;;
  bash) RC="$HOME/.bashrc" ;;
  *)    RC="${RC:-$HOME/.profile}" ;;
esac
touch "$RC"

# Пути под домом пишем как $HOME/... — переносимо, шелл раскроет сам при старте.
rc_path() { case "$1" in "$HOME"/*) printf '$HOME/%s' "${1#"$HOME"/}" ;; *) printf '%s' "$1" ;; esac; }

# Дописать строку в rc, если записи ещё нет. Ищем по МАРКЕРУ ($1), а не по всей
# строке: ручную запись (без кавычек / с комментарием) иначе сочли бы «другой»
# и дописали бы дубль. $2 — что реально записать.
ensure_line() { grep -qsF -- "$1" "$RC" || printf '%s\n' "$2" >> "$RC"; }

ensure_line "cc-providers/cc-providers.sh"  "source \"$(rc_path "$CONFIG_DIR")/cc-providers.sh\""
ensure_line "$(rc_path "$BIN_DIR"):\$PATH"  "export PATH=\"$(rc_path "$BIN_DIR"):\$PATH\""
ok "прописано в $RC (source + PATH)"

echo
ok "Установка завершена."
echo "Дальше:"
echo "  1) ключи:     \$EDITOR $CONFIG_DIR/keys.env"
echo "  2) обновить:  source $RC   (или откройте новый терминал)"
echo "  3) проверка:  cc-show glm"

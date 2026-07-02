# cc-providers.sh — мульти-провайдерный лаунчер Claude Code.
#
# Провайдеры описаны в providers.toml, вся механика — в cc-settings.py.
# Подключение: добавьте в ~/.zshrc (или ~/.bashrc) строку:
#   source ~/.config/cc-providers/cc-providers.sh
#
# Даёт команды: cc-claude / cc-glm / cc-ds  и  cc-show <провайдер>.
# Совместимо с zsh и bash. Переменные провайдера НЕ протекают в ваш шелл
# (claude запускается в субшелле).
#
# Требуется python3 (читает providers.toml).

CC_PROVIDERS_DIR="${CC_PROVIDERS_DIR:-$HOME/.config/cc-providers}"
CC_PROVIDERS_FILE="${CC_PROVIDERS_FILE:-$CC_PROVIDERS_DIR/providers.toml}"
CC_SETTINGS_PY="${CC_SETTINGS_PY:-$CC_PROVIDERS_DIR/cc-settings.py}"

# Грузим ключи, если файл есть (нужны в окружении, чтобы cc-settings.py взял токен).
if [ -f "$CC_PROVIDERS_DIR/keys.env" ]; then
  # shellcheck source=/dev/null
  . "$CC_PROVIDERS_DIR/keys.env"
fi

# Выставляет env-переменные выбранного провайдера в ТЕКУЩЕМ окружении.
# env считает python из providers.toml, шелл только применяет (eval работает в bash и zsh).
_cc_apply() {
  local out
  out=$(python3 "$CC_SETTINGS_PY" env "$CC_PROVIDERS_FILE" "$1") || return $?
  eval "$out"
}

# Запуск claude с провайдером в субшелле (env не утекает наружу).
_cc_run() {
  local provider="$1"; shift
  ( _cc_apply "$provider" || exit $?; exec claude "$@" )
}

cc-claude() { _cc_run claude   "$@"; }
cc-glm()    { _cc_run glm      "$@"; }
cc-ds()     { _cc_run ds       "$@"; }
cc-lms()    { _cc_run lmstudio "$@"; }

# Показать, что уйдёт провайдеру (без запуска claude, токен скрыт).
cc-show() { python3 "$CC_SETTINGS_PY" show "$CC_PROVIDERS_FILE" "${1:-claude}"; }

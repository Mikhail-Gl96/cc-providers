#!/usr/bin/env python3
"""cc-settings.py — единая механика провайдеров для тулкита cc-providers.

Провайдеры описаны в providers.toml (URL, модели, имя переменной с токеном).
Секретов здесь нет: токен берётся из окружения по имени `auth_token_env`
(его в шелл загружает keys.env). Значит этот файл — чистая механика, данных нет.

Команды:
  cc-settings.py env    <providers.toml> <provider>                 # печатает shell (unset+export)
  cc-settings.py show   <providers.toml> <provider>                 # то же, но человекочитаемо, токен скрыт
  cc-settings.py write  <providers.toml> <settings.json> <provider> # прописать провайдера в settings.json
  cc-settings.py status <providers.toml> <settings.json>            # показать текущего провайдера
"""
import json
import os
import shlex
import sys
import tomllib


def load_json(path, default):
    if not os.path.exists(path):
        return default
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except json.JSONDecodeError:
        print(f"ВНИМАНИЕ: {path} — битый JSON.", file=sys.stderr)
        return default


def providers(path):
    if not os.path.exists(path):
        sys.exit(f"{path}: файл провайдеров не найден")
    try:
        with open(path, "rb") as f:      # tomllib требует бинарный режим
            data = tomllib.load(f)
    except tomllib.TOMLDecodeError as e:
        sys.exit(f"{path}: ошибка TOML — {e}")
    if not isinstance(data, dict):
        sys.exit(f"{path}: ожидался объект провайдеров")
    return data


def managed_vars(provs):
    """Всё, чем управляет тулкит = объединение env-ключей всех провайдеров + токен."""
    keys = {"ANTHROPIC_AUTH_TOKEN"}
    for p in provs.values():
        keys.update((p.get("env") or {}).keys())
    return sorted(keys)


def resolve_env(provs, name):
    """env-словарь провайдера с подставленным токеном; проверяет провайдера и ключ."""
    if name not in provs:
        sys.exit(f"неизвестный провайдер '{name}'. Доступны: {', '.join(provs)}")
    p = provs[name]
    env = dict(p.get("env") or {})
    tok_var = p.get("auth_token_env")
    if tok_var:
        tok = os.environ.get(tok_var, "")
        if not tok:
            sys.exit(f"переменная {tok_var} пуста — проверьте keys.env")
        env["ANTHROPIC_AUTH_TOKEN"] = tok
    return env


def cmd_env(pp, name):
    provs = providers(pp)
    env = resolve_env(provs, name)
    print("unset " + " ".join(managed_vars(provs)))
    for k, v in env.items():
        print(f"export {k}={shlex.quote(v)}")


# Поля, которые show печатает по «вайтлисту»: (env-переменная, подпись).
# Порядок здесь = порядок вывода. Токен обрабатывается отдельно (маскируется).
SHOW_FIELDS = (
    ("ANTHROPIC_BASE_URL",             "base URL"),
    ("ANTHROPIC_DEFAULT_OPUS_MODEL",   "opus"),
    ("ANTHROPIC_DEFAULT_SONNET_MODEL", "sonnet"),
    ("ANTHROPIC_DEFAULT_HAIKU_MODEL",  "haiku"),
    ("CLAUDE_CODE_SUBAGENT_MODEL",     "subagent"),
    ("CLAUDE_CODE_EFFORT_LEVEL",       "reasoning"),
)


def _render_env(env, token_state):
    """Строки для показа env: поля по вайтлисту SHOW_FIELDS + прочее.
    token_state — готовая (уже замаскированная) подпись токена."""
    rows = []
    for key, label in SHOW_FIELDS:
        if key == "ANTHROPIC_BASE_URL":
            rows.append((label, env.get(key, "<default Anthropic>")))
        elif key in env:
            rows.append((label, env[key]))
    rows.append(("token", token_state))
    # всё, что вне вайтлиста — чтобы ничего не прятать
    known = {k for k, _ in SHOW_FIELDS} | {"ANTHROPIC_AUTH_TOKEN"}
    for k in sorted(env):
        if k not in known:
            rows.append((k, env[k]))
    width = max(len(label) for label, _ in rows)
    return [f"  {label:<{width}} = {value}" for label, value in rows]


def cmd_show(pp, name):
    provs = providers(pp)
    if name not in provs:
        sys.exit(f"неизвестный провайдер '{name}'. Доступны: {', '.join(provs)}")
    env = dict(provs[name].get("env") or {})
    tok_var = provs[name].get("auth_token_env")
    if tok_var:
        state = "<задан>" if os.environ.get(tok_var) else "<ПУСТ! проверьте keys.env>"
        token_state = f"{state}  ({tok_var})"
    elif "ANTHROPIC_AUTH_TOKEN" in env:
        token_state = "<локальная заглушка>"
    else:
        token_state = "<не нужен>"
    print(f"Провайдер: {name}")
    print("\n".join(_render_env(env, token_state)))


def cmd_write(pp, sp, name):
    provs = providers(pp)
    env_new = resolve_env(provs, name)
    settings = load_json(sp, {})
    if not isinstance(settings, dict):
        settings = {}
    env = settings.get("env") if isinstance(settings.get("env"), dict) else {}
    for k in managed_vars(provs):     # снять наши ключи, чужие настройки пользователя не трогаем
        env.pop(k, None)
    env.update(env_new)               # для 'claude' env_new пуст -> дефолтный Anthropic
    settings["env"] = env
    os.makedirs(os.path.dirname(sp) or ".", exist_ok=True)
    with open(sp, "w", encoding="utf-8") as f:
        json.dump(settings, f, indent=2, ensure_ascii=False)
        f.write("\n")
    try:
        os.chmod(sp, 0o600)
    except OSError:
        pass


def _match_provider(provs, base):
    """По base URL из settings.json определить имя провайдера через providers.toml."""
    if not base:
        return "claude (Anthropic по умолчанию)"
    for pname, p in provs.items():
        if (p.get("env") or {}).get("ANTHROPIC_BASE_URL") == base:
            return pname
    return f"неизвестный (base URL {base})"


def cmd_status(pp, sp):
    provs = providers(pp)
    data = load_json(sp, {})
    env = data.get("env") if isinstance(data, dict) else {}
    if not isinstance(env, dict):
        env = {}
    name = _match_provider(provs, env.get("ANTHROPIC_BASE_URL"))
    token_state = "<задан>" if "ANTHROPIC_AUTH_TOKEN" in env else "<не нужен>"
    print(f"Текущий провайдер в {sp}: {name}")
    print("\n".join(_render_env(env, token_state)))


def main(a):
    if len(a) == 4 and a[1] == "env":
        cmd_env(a[2], a[3])
    elif len(a) == 4 and a[1] == "show":
        cmd_show(a[2], a[3])
    elif len(a) == 5 and a[1] == "write":
        cmd_write(a[2], a[3], a[4])
    elif len(a) == 4 and a[1] == "status":
        cmd_status(a[2], a[3])
    else:
        sys.exit(
            "usage:\n"
            "  cc-settings.py env    <providers.toml> <provider>\n"
            "  cc-settings.py show   <providers.toml> <provider>\n"
            "  cc-settings.py write  <providers.toml> <settings.json> <provider>\n"
            "  cc-settings.py status <providers.toml> <settings.json>"
        )


if __name__ == "__main__":
    main(sys.argv)

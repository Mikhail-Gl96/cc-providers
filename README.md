# cc-providers

Multi-provider toolkit for Claude Code: run and switch between Claude, z.ai GLM,
DeepSeek and more — in CLI, VS Code and JetBrains. Per-project pinning or
in-session switching.

Провайдеры описаны **в одном месте** — `providers.toml` (с комментариями). Вся
механика — в `cc-settings.py`. Шелл-обёртки тонкие. Добавить нового провайдера =
дописать блок в TOML, ключ — в `keys.env`. Больше нигде править не нужно.

Работает в CLI, VS Code и JetBrains (десктоп-приложение Claude Code сторонних
провайдеров штатно не поддерживает — см. раздел в конце).

Требуется **python 3.11+** (`cc-settings.py` читает `providers.toml` через
`tomllib` из стандартной библиотеки — никаких pip-зависимостей).

---

## Что в комплекте

| Файл | Назначение |
|------|------------|
| `providers.toml` | **Единственный источник** описаний провайдеров (URL, модели, имя ключа); можно комментировать |
| `cc-settings.py` | Вся механика: отдать env / записать settings.json / статус (данных о провайдерах нет) |
| `cc-providers.sh` | Библиотека + команды `cc-claude` / `cc-glm` / `cc-ds` / `cc-lms` / `cc-show` для шелла |
| `cc` | Отдельный лаунчер: `cc <claude\|glm\|ds\|lmstudio>`. Для PATH и для JetBrains |
| `cc-use` | Переключалка глобального провайдера в `~/.claude/settings.json` (для VS Code) |
| `install.sh` | Быстрая установка: проверка зависимостей + раскладка файлов и подключение к shell |
| `keys.env.example` | Шаблон файла с ключами (секреты, не коммитить) |

---

## Установка

### Быстро — `install.sh`

```bash
git clone https://github.com/Mikhail-Gl96/cc-providers.git
cd cc-providers
./install.sh
```

Скрипт проверит зависимости (**python 3.11+** с `tomllib`, наличие `claude`),
разложит файлы в `~/.config/cc-providers` и `~/bin` и подключит библиотеку
к вашему shell rc. Идемпотентен — можно перезапускать; существующий `keys.env` не
трогает. Пути переопределяются: `CC_PROVIDERS_DIR=... BIN_DIR=... ./install.sh`.

Дальше: впишите ключи в `~/.config/cc-providers/keys.env` и откройте новый
терминал (или `source ~/.zshrc`).

### Вручную

```bash
# 1. Каталог для конфигов
mkdir -p ~/.config/cc-providers

# 2. Положить механику, провайдеров и ключи
cp cc-providers.sh cc-settings.py providers.toml ~/.config/cc-providers/
cp keys.env.example ~/.config/cc-providers/keys.env
chmod 600 ~/.config/cc-providers/keys.env
# впишите свои ключи:
$EDITOR ~/.config/cc-providers/keys.env

# 3. Лаунчеры в PATH (~/bin или /usr/local/bin)
mkdir -p ~/bin
cp cc cc-use ~/bin/
chmod +x ~/bin/cc ~/bin/cc-use

# 4. Подключить функции в шелле
echo 'source ~/.config/cc-providers/cc-providers.sh' >> ~/.zshrc   # или ~/.bashrc
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

Проверка (токен скрыт):

```bash
cc-show glm
cc-show ds
```

> Ключи Anthropic для самого Claude обычно не нужны — достаточно `claude login`.
> z.ai и DeepSeek авторизуются ключом из `keys.env`.

---

## Как добавить нового провайдера

1. Впишите ключ в `~/.config/cc-providers/keys.env`, например:
   ```bash
   export MY_API_KEY="..."
   ```
2. Добавьте блок в `providers.toml` (`auth_token_env` = имя переменной из шага 1):
   ```toml
   [myprov]
   auth_token_env = "MY_API_KEY"
   [myprov.env]
   ANTHROPIC_BASE_URL             = "https://api.example.com/anthropic"
   ANTHROPIC_DEFAULT_SONNET_MODEL = "my-model"
   ANTHROPIC_DEFAULT_HAIKU_MODEL  = "my-model-mini"
   ```
   > Локальному провайдеру без ключа `auth_token_env` не нужен — впишите
   > `ANTHROPIC_AUTH_TOKEN` прямо в `[myprov.env]` (пример — `lmstudio`).
3. Готово. `cc-use myprov`, `cc myprov` и `cc-settings.py` подхватят автоматически.
   Для новой шелл-обёртки при желании допишите в `cc-providers.sh`:
   `cc-myprov() { _cc_run myprov "$@"; }`.

---

## Сценарий 1 — переключение внутри проекта

### В CLI

```bash
cd ~/projects/my-app

cc-claude        # сессия на Claude (Anthropic)
# вышли (/exit или Ctrl-D), затем:
cc-glm           # та же папка, но уже GLM
cc-ds            # или DeepSeek
```

Аргументы прокидываются в `claude`: `cc-ds --resume`, `cc-glm -p "..."`.
Переменные провайдера живут только внутри запущенной сессии и не «протекают» в
ваш шелл. Внутри сессии текущий провайдер видно командой `/status`.

### В JetBrains

`Settings → Tools → Claude Code → Claude command:`

```
cc glm
```

Для другого провайдера — `cc ds` или `cc claude`, затем перезапустите сессию.
Для WSL: `wsl -d Ubuntu -- bash -lic "cc glm"`.

---

## Сценарий 2 — свой провайдер закреплён за проектом

Пропишите провайдера в локальный (не коммитится) `.claude/settings.local.json`
проекта — туда же уедет и токен:

```bash
cd ~/projects/my-app
CLAUDE_SETTINGS="$PWD/.claude/settings.local.json" cc-use glm
```

Claude Code читает `.claude/settings.local.json` поверх глобального, так что этот
проект всегда будет на GLM, а секрет в коммит не попадёт.

---

## Глобальный провайдер (VS Code, голый `claude`)

```bash
cc-use glm       # прописать GLM в ~/.claude/settings.json
cc-use status    # показать текущего
cc-use claude    # вернуть дефолтный Anthropic
```

После смены перезапустите сессию Claude Code — env читается при старте.

---

## Заметки

- Секреты живут только в `keys.env`; в `providers.toml` — лишь имя переменной
  (`auth_token_env`), так что конфиг можно спокойно коммитить.
- `cc-settings.py` не содержит данных о провайдерах — только читает `providers.toml`
  и пишет `settings.json`, поэтому его удобно покрыть тестами и линтерами.
- Десктоп-приложение Claude Code сторонних провайдеров штатно не поддерживает —
  используйте CLI, VS Code или JetBrains.

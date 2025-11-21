# Arch Installer (modular)

Проект собирает воспроизводимый установщик Arch Linux с чёткой модульной структурой, YAML-конфигом и CLI-оркестратором. Цель — быстро поднимать систему (по умолчанию профиль `desktop` с Hyprland), сохраняя безопасность, идемпотентность и расширяемость.

## Новая структура
- `cli/` — единый вход (`install.sh`) с опциями `--dry-run`, `--stage`, `--profile`, `--log-level`, `--log-file`.
- `core/` — общие библиотеки: логирование, ошибки, промпты, сеть, железо, загрузка конфигурации.
- `stages/` — по сценарию на стадию (`preflight`, `disk`, `system`, `apps`, `postinstall`, `aur`), каждый экспортирует `run_stage`.
- `config/` — декларативный `config.yaml` + генератор `generate.sh` → `generated.sh` (bash-окружение).
- `hooks/` — хуки `hooks/<stage>/{before,after}.d/*.sh` (исполняемые файлы выполняются по сортировке).
- `tests/` — дымовой тест `smoke.sh` (dry-run preflight).
- `dist/` — артефакты сборки (`make package`).

## Быстрый старт (live Arch)
```bash
# 1) Сеть
#    Wi‑Fi: iwctl station wlan0 connect MyWiFi
#    Ethernet: ip link set eth0 up && dhcpcd eth0

# 2) Синхронизация времени
 timedatectl set-ntp true

# 3) Получение исходников
pacman -Sy --noconfirm git
 git clone https://github.com/arch-installer/modular-arch.git arch-installer
 cd arch-installer

# 4) Подготовка конфигурации
nano config/config.yaml
./config/generate.sh

# 5) Сухой прогон всего пайплайна
./cli/install.sh --dry-run

# 6) Запуск только одной стадии
./cli/install.sh --dry-run --stage apps --profile desktop
```

## Конфигурация через `config/config.yaml`
- Раздел `install`: корень установки, диск, пользователь, профиль по умолчанию.
- Разделы `packages.pacman` и `packages.aur`: группы пакетов.
- `profiles`: наборы групп и флаги (`ENABLE_*`) для разных сценариев (например, `desktop`, `minimal`).
- `services`: системные сервисы для автозапуска.

Запуск `config/generate.sh` создаёт `config/generated.sh` с bash-массивами (`PACMAN_GROUP_*`, `AUR_GROUP_*`, `PROFILE_*`). CLI автоматически пересобирает кеш, если YAML новее.

## Стадии и безопасность
- **preflight** — root-права, UEFI, сеть, NTP, SMART (при наличии), обязательный `set -euo pipefail`.
- **disk** — двойное подтверждение перед wipe, whitelisting через `TARGET_DISK`, поддержка dry-run.
- **system** — `pacstrap`, `fstab`, локали, hostname, микрокод и GPU/virt пакеты.
- **apps** — pacman-пакеты по профилю + GPU дополнения.
- **postinstall** — создание пользователя, sudo, включение сервисов.
- **aur** — установка `yay` и AUR-пакетов по профилю + GPU-ветки.

Каждая стадия идемпотентна в части проверок, принимает `INSTALL_DRY_RUN` и использует общий логгер. Хуки `before/after` позволяют добавлять шаги без правки ядра.

## Makefile
- `make config` — генерация `config/generated.sh`.
- `make lint`/`make shellcheck` — статический анализ.
- `make format` — форматирование `shfmt`.
- `make test` — дымовой тест (dry-run preflight).
- `make run` — полный dry-run.
- `make package` — архив в `dist/arch-installer.tar.gz`.

## Безопасный запуск
- Всегда начинайте с `--dry-run` и проверяйте лог (`logs/install-*.log`).
- Перед стадией `disk` убедитесь, что `TARGET_DISK` в YAML указывает на нужное устройство.
- В live-окружении должны быть доступны `pacstrap`, `parted`, `lsblk`, `arch-chroot`, `git`, `systemd-boot`.

## Минимальные зависимости
- Bash, coreutils, `python` (для генерации bash-конфига из YAML/JSON), `pacstrap`, `parted`, `lsblk`, `arch-chroot`, `git`, `systemd-boot`.

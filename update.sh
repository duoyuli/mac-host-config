#!/usr/bin/env bash
# ==============================================================================
# update.sh: 一键将系统中的最新配置同步回当前备份目录（直接覆盖）
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 同步清单：系统路径 -> 备份目录相对路径
declare -a SYNC_FILES=(
  "$HOME/.zshrc:.zshrc"
  "$HOME/.npmrc:.npmrc"
  "$HOME/.tmux.conf:.tmux.conf"
  "$HOME/.config/zsh/up.zsh:.config/zsh/up.zsh"
  "$HOME/.config/sheldon/plugins.toml:.config/sheldon/plugins.toml"
  "$HOME/.config/starship.toml:.config/starship.toml"
)

info()    { printf "\033[34m[INFO]\033[0m %s\n" "$*"; }
success() { printf "\033[32m[OK]\033[0m %s\n" "$*"; }
warn()    { printf "\033[33m[WARN]\033[0m %s\n" "$*"; }

info "开始从本机同步最新配置到当前目录..."

for item in "${SYNC_FILES[@]}"; do
  src="${item%%:*}"
  dst_rel="${item#*:}"
  dst="$SCRIPT_DIR/$dst_rel"

  if [[ ! -f "$src" ]]; then
    warn "本机文件不存在，跳过: $src"
    continue
  fi

  mkdir -p "$(dirname "$dst")"

  if [[ -f "$dst" ]] && cmp -s "$src" "$dst"; then
    printf "  \033[90m- %-32s (无变化)\033[0m\n" "$dst_rel"
  else
    cp -p "$src" "$dst"
    printf "  \033[32m✔ %-32s (已同步更新)\033[0m\n" "$dst_rel"
  fi
done

echo ""
success "所有配置已同步更新到当前目录！"

# PATH / fpath 自动去重，每个目录只保留首次出现的位置。
typeset -U path PATH fpath

## Homebrew：macOS 包管理器；安装：/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
[[ -x /opt/homebrew/bin/brew ]] && eval "$(/opt/homebrew/bin/brew shellenv)"
## OrbStack（Docker）：容器运行环境；安装：brew install --cask orbstack
[[ -r $HOME/.orbstack/shell/init.zsh ]] && source "$HOME/.orbstack/shell/init.zsh"
## Rust：Rust 工具链；安装：curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
[[ -r $HOME/.cargo/env ]] && source "$HOME/.cargo/env"
## Java / Maven / Gradle（SDKMAN）：Java 构建工具链；启动时只设置 <工具>_HOME 和 PATH，首次执行 sdk 时再完整加载 SDKMAN；安装：curl -s "https://get.sdkman.io" | bash
export SDKMAN_DIR="$HOME/.sdkman"
() {
  local dir
  for dir in $SDKMAN_DIR/candidates/*/current(N-/); do
    export ${(U)${dir:h:t}}_HOME=$dir
    path=($dir/bin $path)
  done
}
sdk() {
  unfunction sdk
  source "$SDKMAN_DIR/bin/sdkman-init.sh" && sdk "$@"
}
## Bun：JavaScript 运行时与工具链；安装：curl -fsSL https://bun.com/install | bash
export BUN_INSTALL="$HOME/.bun"
## pnpm：Node.js 包管理器；安装：corepack enable pnpm（由 npm 全局包 corepack 提供）
export PNPM_HOME="$HOME/Library/pnpm"

# PATH 按优先级从前到后排列。
path=(
  $HOME/.grok/bin                                           # grok
  $HOME/.local/bin                                          # uv 工具；node shim -> node@24
  ${HOMEBREW_PREFIX:-/opt/homebrew}/opt/python/libexec/bin  # python / pip -> Homebrew Python 3
  $PNPM_HOME/bin                                            # pnpm 全局包命令（pnpm 11+）
  $PNPM_HOME
  $BUN_INSTALL/bin
  $path
)
fpath=($HOME/.grok/completions/zsh $fpath)

## up：一键升级，具体策略见该文件
[[ -r ${XDG_CONFIG_HOME:-$HOME/.config}/zsh/up.zsh ]] && source "${XDG_CONFIG_HOME:-$HOME/.config}/zsh/up.zsh"
## y：退出 Yazi 后切换到最后浏览的目录（保留官方写法）；安装：brew install yazi ffmpeg-full sevenzip jq poppler fd ripgrep fzf zoxide resvg imagemagick-full font-symbols-only-nerd-font
y() {
  local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
  command yazi "$@" --cwd-file="$tmp"
  IFS= read -r -d '' cwd < "$tmp"
  [ "$cwd" != "$PWD" ] && [ -d "$cwd" ] && builtin cd -- "$cwd"
  rm -f -- "$tmp"
}

# History
HISTSIZE=50000
SAVEHIST=50000
# 多终端共享历史，重复命令只保留最新一条，空格开头的命令不记录。
setopt share_history hist_ignore_all_dups hist_reduce_blanks hist_ignore_space

# Aliases
alias ls="ls -laG"
alias sz='exec zsh'                  # 重启 shell，重新加载配置
## tmux：brew install tmux
alias tns='tmux new -e mode=dev -s'
alias tat='tmux attach -t'
alias tls='tmux ls'
alias tkt='tmux kill-session -t'
## Agents
alias att='cd ~/.agents-tmp'
alias cc='claude --dangerously-skip-permissions'

# Starship：shell 补全提示符；安装：brew install starship
(( $+commands[starship] )) && eval "$(command starship init zsh)"
# Sheldon：zsh 插件管理器；安装：brew install sheldon
(( $+commands[sheldon] )) && eval "$(command sheldon source)"

# Completion：zsh 命令补全；缓存超过 24 小时才完整检查，否则直接使用缓存。
autoload -Uz compinit
() { if (( $# )); then compinit; else compinit -C; fi } ${ZDOTDIR:-$HOME}/.zcompdump(N.mh+24)

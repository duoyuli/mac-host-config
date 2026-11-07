# up：一键升级 coding agent、Homebrew、npm / pnpm / bun 全局包。由 ~/.zshrc 加载。
#
# 策略
#   - 默认 Node 是 node@24，只升 24.x 小版本；node（26）和 npm 自身不升级。
#   - 全局包（npm / pnpm / bun）升级前后必须一个不少，否则记为失败。
#   - 某一步失败不影响后续步骤，最后统一汇总。
#
# 依赖与一次性设置
#   - brew pin node：让 brew upgrade 跳过 node（26）。
#   - node@24 保持不 pin，才会跟随 brew upgrade 升小版本。
#   - ~/.local/bin/node 是指向 node@24 的 shim，保证 PATH 里的 node 始终是 v24。
#   - jq（brew install jq）：读取 pnpm / bun 的全局包列表。
#   - pnpm 由 npm 全局包 corepack 提供（corepack enable pnpm）。

typeset -g UP_NODE_MAJOR=24

_up_step() { print -r -- "***** $*" }
_up_err()  { print -u2 -r -- "ERROR: $*" }

# 检查当前 Node 是 v24，并输出 npm 全局 prefix，供前后对比。
_up_node_prefix() {
  local version
  version=$(node -p process.version) || return 1
  if [[ $version != v${UP_NODE_MAJOR}.* ]]; then
    _up_err "active Node is $version, expected v$UP_NODE_MAJOR"
    return 1
  fi
  npm config get prefix
}

# 各包管理器的全局包名（每行一个）。npm 的列表包含 npm 自身。
_up_npm_pkgs() {
  emulate -L zsh
  local prefix=$1
  local -a pkgs
  pkgs=(${${(f)"$(npm ls -g --depth=0 --parseable)"}#$prefix/lib/node_modules/})
  print -rl -- ${pkgs:#$prefix/lib}
}
_up_pnpm_pkgs() { pnpm ls -g --depth=0 --json | jq -r '.[].dependencies // {} | keys[]' }
_up_bun_pkgs() {
  local manifest=$HOME/.bun/install/global/package.json
  [[ -r $manifest ]] || return 0
  jq -r '.dependencies // {} | keys[]' $manifest
}

# 用法：_up_check_missing <阶段> <之前的列表> <之后的列表>，有缺失就报出来。
_up_check_missing() {
  emulate -L zsh
  local -a before=(${(f)2}) after=(${(f)3}) missing
  missing=(${before:|after})
  (( ${#missing} )) || return 0
  _up_err "global packages missing after $1: ${missing[*]}"
  return 1
}

# Homebrew：除 node@24 外的 Node 公式必须已 pin，然后整体升级。
_up_brew() {
  emulate -L zsh
  local f
  local -a pinned

  brew update || return 1
  pinned=(${(f)"$(brew list --pinned)"}) || return 1
  for f in ${(f)"$(brew list --formula -1)"}; do
    [[ $f == node || $f == node@<-> ]] || continue
    [[ $f == node@$UP_NODE_MAJOR ]] && continue
    if (( ! ${pinned[(Ie)$f]} )); then
      _up_err "$f is not pinned; run: brew pin $f"
      return 1
    fi
  done
  HOMEBREW_NO_AUTO_UPDATE=1 brew upgrade --formula
}

# 升级 node@24 后，确保 $HOMEBREW_PREFIX/bin/node 仍指向 node@24。
# 只修复缺失或本来就指向 node@24 的链接，其他情况拒绝覆盖。
_up_fix_node_link() {
  emulate -L zsh
  local brew_prefix=${HOMEBREW_PREFIX:-/opt/homebrew}
  local link=$brew_prefix/bin/node target=../opt/node@$UP_NODE_MAJOR/bin/node
  [[ -x $brew_prefix/opt/node@$UP_NODE_MAJOR/bin/node ]] || return 0
  if [[ -L $link ]]; then
    [[ $(readlink $link) == *node@$UP_NODE_MAJOR/* ]] || {
      _up_err "refusing to replace $link -> $(readlink $link)"
      return 1
    }
  elif [[ -e $link ]]; then
    _up_err "refusing to replace non-symlink $link"
    return 1
  fi
  ln -sfn $target $link
}

# npm：升级除 npm 外的全部全局包；拒绝不兼容当前 Node 的版本，npm 自身版本不得变化。
_up_npm() {
  emulate -L zsh
  local prefix=$1 npm_before npm_after
  local -a pkgs

  npm_before=$(npm -v) || return 1
  pkgs=(${(f)"$(_up_npm_pkgs $prefix)"})
  pkgs=(${pkgs:#npm})
  if (( ${#pkgs} )); then
    print -r -- "upgrade global packages: ${pkgs[*]}"
    npm -g update --engine-strict -- $pkgs || return 1
  fi
  npm_after=$(npm -v)
  if [[ $npm_after != $npm_before ]]; then
    _up_err "npm version changed ($npm_before -> $npm_after)"
    return 1
  fi
}

# 用法：_up_global <名称> <列包函数> <升级命令...>
# 用于 pnpm / bun：没有全局包就跳过；升级后检查一个不少。
_up_global() {
  emulate -L zsh
  local name=$1 list=$2 before after
  shift 2
  before=$($list) || { _up_err "cannot list $name global packages"; return 1 }
  if [[ -z $before ]]; then
    print -r -- "no $name global packages"
    return 0
  fi
  print -r -- "upgrade $name global packages: ${(f)before}"
  "$@" || return 1
  after=$($list) || return 1
  _up_check_missing "$name update" "$before" "$after"
}

up() {
  emulate -L zsh
  local prefix pkgs_before
  local -a failures

  print -r -- "software update start"
  prefix=$(_up_node_prefix) && [[ -n $prefix ]] &&
    pkgs_before=$(_up_npm_pkgs $prefix) && [[ -n $pkgs_before ]] || {
    _up_err "Node/npm preflight failed; no updates started"
    return 1
  }

  _up_step "① coding agent update"
  claude update             || failures+=("claude update")
  grok update               || failures+=("grok update")
  uv tool upgrade --all     || failures+=("uv tool upgrade")

  _up_step "② brew upgrade"
  _up_brew                  || failures+=("brew upgrade")
  _up_fix_node_link         || failures+=("Node entry point")
  _up_check_missing brew "$pkgs_before" "$(_up_npm_pkgs $prefix)" ||
    failures+=("global packages after brew")

  _up_step "③ npm global update"
  if [[ $(_up_node_prefix) != $prefix ]]; then
    _up_err "Node runtime or npm prefix changed; skipping npm update"
    failures+=("Node/npm environment check")
  else
    _up_npm $prefix         || failures+=("npm global update")
    [[ $(_up_node_prefix) == $prefix ]] || failures+=("Node/npm post-update check")
    _up_check_missing npm "$pkgs_before" "$(_up_npm_pkgs $prefix)" ||
      failures+=("global packages after npm")
  fi

  _up_step "④ pnpm / bun global update"
  if (( $+commands[pnpm] )); then
    _up_global pnpm _up_pnpm_pkgs pnpm update -g --latest || failures+=("pnpm global update")
  fi
  if (( $+commands[bun] )); then
    _up_global bun _up_bun_pkgs bun update -g --latest    || failures+=("bun global update")
  fi

  if (( ${#failures} )); then
    print -u2 -r -- "software update finished with failures:"
    printf '  - %s\n' $failures >&2
    return 1
  fi
  print -r -- "software update finished successfully"
}

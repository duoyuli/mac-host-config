# 🍏 Mac 开发环境配置

> 敲了 10 年代码，最后发现能让自己每天舒舒服服干活的，不是酷炫的动效，而是「稳」和「快」。

这是我个人 Mac 的终端与开发环境配置备份：Zsh、tmux、Starship、Sheldon、npm 和一键升级脚本 `up`。新电脑把下文的提示词交给 Coding Agent，由它按本文完成安装和部署。

- **启动快**：PATH 去重、SDKMAN 惰性加载、补全缓存，终端打开不等待。
- **Node 稳**：默认锁定 `node@24`，只跟随 24.x 小版本升级。
- **升级省心**：`up` 一条命令升级 Coding Agent、Homebrew 和 npm / pnpm / bun 全局包，并检查全局包没有丢失。

---

## 目录

- [让 Agent 安装](#让-agent-安装)
- [仓库内容](#仓库内容)
- [设计要点](#设计要点)
- [组件说明](#组件说明)
- [日常使用](#日常使用)
- [维护：同步本机配置回仓库](#维护同步本机配置回仓库)
- [注意事项](#注意事项)

---

## 让 Agent 安装

在新 Mac 上把本仓库放到本地，在仓库目录中启动 Coding Agent，然后发送以下提示词：

```text
阅读本仓库的 README.md，在这台 Mac 上安装「组件说明」中列出的全部软件，并部署「仓库内容」中的配置文件。

要求：
1. 严格遵守 README 中「安装约束」一节的顺序和注意事项。
2. 已经安装的软件跳过，不要重装或降级。
3. 覆盖 ~ 下已有的配置文件前，先备份为 <文件名>.bak。
4. 需要我手动操作的步骤（系统弹窗、启动 GUI 应用、输入密码）停下来告诉我，完成后再继续。
5. 全部完成后，在新的 zsh 中验证：node -v 为 v24.x，starship、sheldon、tmux、yazi、claude、grok 均可执行；列出失败或跳过的项目。
```

### 安装约束

1. **先装基础**：先执行 `xcode-select --install`（系统弹窗，需等待完成），再安装 Homebrew：

   ```bash
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   eval "$(/opt/homebrew/bin/brew shellenv)"   # 只在当前会话生效，之后由 .zshrc 处理
   ```

   无法直连 GitHub 时，改用国内镜像：`/bin/bash -c "$(curl -fsSL https://gitee.com/cunkai/HomebrewCN/raw/master/Homebrew.sh)"`。
2. **不要写 `~/.zprofile`**：Homebrew 安装结束后会提示把 `brew shellenv` 写入 `~/.zprofile`，不要照做。`.zshrc` 已包含这段逻辑。
3. **Node 按策略安装**：`brew install node@24 && brew link --overwrite --force node@24`；如果装了最新版 `node` 公式，执行 `brew pin node`；创建 `~/.local/bin/node` shim。详见 [Node 版本策略](#node-版本策略)。
4. **先跑安装脚本，再部署配置**：Bun、SDKMAN 等安装脚本会向 `~/.zshrc` 追加内容，部署时用仓库里的 `.zshrc` 覆盖即可，所需环境变量已写在仓库版本中。
5. **部署配置后再装 npm 全局包**：`npm install -g` 依赖 `~/.npmrc` 中的 `prefix` 和安装脚本策略。
6. **OrbStack 需启动一次**：安装后打开一次 OrbStack 应用，它会生成 `~/.orbstack/shell/init.zsh`，`.zshrc` 检测到后自动加载。

---

## 仓库内容

| 仓库文件 | 部署位置 | 作用 |
| :--- | :--- | :--- |
| `.zshrc` | `~/.zshrc` | Zsh 主配置：PATH 去重与排序、各运行时环境变量、SDKMAN 惰性加载、`y` 函数、历史记录、别名、Starship / Sheldon 初始化、补全缓存。 |
| `.npmrc` | `~/.npmrc` | npm 全局前缀 `prefix=/opt/homebrew`，以及安装脚本执行策略。 |
| `.tmux.conf` | `~/.tmux.conf` | 鼠标、系统剪贴板、状态栏配色、分屏快捷键和 dev 三分屏布局。 |
| `.config/zsh/up.zsh` | `~/.config/zsh/up.zsh` | 定义 `up` 一键升级函数，由 `.zshrc` 加载。 |
| `.config/sheldon/plugins.toml` | `~/.config/sheldon/plugins.toml` | Zsh 插件：`zsh-completions`、`zsh-autosuggestions`、`zsh-syntax-highlighting`。 |
| `.config/starship.toml` | `~/.config/starship.toml` | Starship 提示符样式。 |
| `update.sh` | — | 把本机最新配置同步回本仓库，见[维护](#维护同步本机配置回仓库)。 |

---

## 设计要点

### 终端启动速度

- **PATH 去重**：`typeset -U path PATH fpath`，同一目录只保留最靠前的一次。
- **SDKMAN 惰性加载**：启动时只为 `~/.sdkman/candidates/*/current` 设置 `<工具>_HOME` 和 PATH；完整的 SDKMAN 脚本在第一次执行 `sdk` 时才加载。`sdk default` 切换版本后，环境变量自动跟随。
- **补全缓存**：`~/.zcompdump` 超过 24 小时才执行完整的 `compinit`，否则用 `compinit -C` 直接读缓存。

### PATH 优先级

`.zshrc` 中越靠前优先级越高：

1. `~/.grok/bin`：Grok CLI
2. `~/.local/bin`：Claude Code、uv 工具，以及指向 `node@24` 的 `node` shim
3. `/opt/homebrew/opt/python/libexec/bin`：让 `python` / `pip` 指向 Homebrew Python 3
4. `~/Library/pnpm/bin`、`~/Library/pnpm`：pnpm 全局命令
5. `~/.bun/bin`：Bun
6. 系统原有 PATH（含 Homebrew、Cargo、SDKMAN）

### Node 版本策略

- 默认 Node 是 `node@24`。它**不 pin**，所以 `brew upgrade` 会跟随升级 24.x 小版本。
- 如果同时装了最新版 `node` 公式（目前是 26），必须执行 `brew pin node`。`up` 会检查：除 `node@24` 外的 Node 公式若未 pin，Homebrew 步骤直接失败。
- `~/.local/bin/node` 是指向 `node@24` 的 shim，保证 PATH 里的 `node` 始终是 v24。新机需要手动创建，例如：

  ```bash
  mkdir -p ~/.local/bin
  ln -s /opt/homebrew/opt/node@24/bin/node ~/.local/bin/node
  ```

- npm 自身不随 `up` 升级。

### 一键升级 `up`

`up` 按以下顺序执行：

1. **预检**：确认当前 Node 是 v24，并记录 npm 全局包清单。预检失败则不执行任何升级。
2. **Coding Agent**：`claude update`、`grok update`、`uv tool upgrade --all`。
3. **Homebrew**：`brew update` 后升级全部公式；升级后修复 `/opt/homebrew/bin/node`，确保仍指向 `node@24`（如果该链接指向其他目标，拒绝覆盖并报错）。
4. **npm 全局包**：升级除 npm 外的全部全局包，使用 `--engine-strict` 拒绝不兼容当前 Node 的版本；升级后检查 npm 版本没有变化。
5. **pnpm / bun 全局包**：命令存在且有全局包时才执行。

每个阶段结束后都会对比全局包清单，有包丢失即记为失败。某一步失败**不会中断**后续步骤，所有失败在最后统一列出，并以非零状态退出。

`up` 依赖 `jq` 读取 pnpm / bun 的全局包列表。

---

## 组件说明

### 终端与 Shell

```bash
brew install starship sheldon tmux font-symbols-only-nerd-font
```

| 组件 | 说明 |
| :--- | :--- |
| Starship | 提示符，读取 `~/.config/starship.toml`，显示 Git 状态和语言版本。 |
| Sheldon | Zsh 插件管理器，读取 `~/.config/sheldon/plugins.toml`。在 `compinit` 之前加载，因为 `zsh-completions` 需要先加入 `fpath`。 |
| tmux | 终端复用器，读取 `~/.tmux.conf`。 |
| font-symbols-only-nerd-font | 显示 Git 分支、文件类型等图标。 |
| 终端软件 | 推荐 Ghostty 或 iTerm2。 |

### 文件管理与 CLI 工具

`.zshrc` 中的 `y` 函数启动 Yazi，退出后 shell 自动切换到最后浏览的目录。

```bash
brew install yazi ffmpeg-full sevenzip jq poppler fd ripgrep fzf zoxide resvg imagemagick-full
```

| 工具 | 用途 |
| :--- | :--- |
| `yazi` | 终端文件管理器 |
| `poppler`、`ffmpeg-full`、`sevenzip`、`resvg`、`imagemagick-full` | Yazi 预览 PDF、音视频、压缩包、SVG 和图片 |
| `fd`、`ripgrep`、`fzf`、`zoxide` | 文件查找、文本搜索、模糊选择、目录跳转 |
| `jq` | JSON 处理；`up` 的必需依赖 |

### 编程语言与运行时

| 运行时 | 安装方式 | `.zshrc` 中的处理 |
| :--- | :--- | :--- |
| Node.js | `brew install node@24 && brew link --overwrite --force node@24` | 见 [Node 版本策略](#node-版本策略) |
| pnpm | `npm install -g corepack && corepack enable pnpm` | `PNPM_HOME=~/Library/pnpm` |
| Bun | `curl -fsSL https://bun.com/install \| bash` | `BUN_INSTALL=~/.bun` |
| Rust | `curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \| sh -s -- -y` | 加载 `~/.cargo/env` |
| Java / Maven / Gradle | `curl -s "https://get.sdkman.io" \| bash` | 惰性加载，见[设计要点](#终端启动速度) |
| Python 3 | `brew install python` | `python` / `pip` 指向 Homebrew Python 3 |
| uv | `brew install uv` | `up` 中执行 `uv tool upgrade --all` |

SDKMAN 安装后按需安装 JDK 和构建工具：

```bash
sdk install java 21.0.2-tem
sdk install maven
sdk install gradle
```

### 容器

OrbStack（`brew install --cask orbstack`）提供 Docker 和 Linux 虚拟机，比 Docker Desktop 更轻量。`.zshrc` 在 `~/.orbstack/shell/init.zsh` 存在时自动加载。

### AI Coding Agent

| 工具 | 安装方式 | 说明 |
| :--- | :--- | :--- |
| Herdr | `brew install --cask herdr-app` | 面向终端与 Coding Agent 的桌面环境 |
| Claude Code | `curl -fsSL https://claude.ai/install.sh \| bash` | 安装到 `~/.local/bin`；`up` 中执行 `claude update` |
| Grok CLI | `curl -fsSL https://x.ai/cli/install.sh \| bash` | 安装到 `~/.grok/bin`，补全在 `~/.grok/completions/zsh`；`up` 中执行 `grok update` |
| Codex | `npm install -g @openai/codex` | OpenAI 命令行代码助手 |
| Pi | `npm install -g @earendil-works/pi-coding-agent` | 极简终端 Coding Agent |
| OpenCode | `npm install -g @opencode/cli` | 终端 Coding Agent |

---

## 日常使用

### 命令与别名

| 命令 | 作用 |
| :--- | :--- |
| `up` | 一键升级，见[一键升级 `up`](#一键升级-up) |
| `sz` | `exec zsh`，重启 shell 并重新加载配置 |
| `y` | 启动 Yazi，按 `q` 退出后切换到最后浏览的目录 |
| `cc` | `claude --dangerously-skip-permissions`，跳过权限确认启动 Claude Code |
| `att` | `cd ~/.agents-tmp`，进入 Agent 临时工作目录 |
| `ls` | `ls -laG`，默认显示隐藏文件、详细信息和颜色 |

### tmux

| 命令 / 按键 | 作用 |
| :--- | :--- |
| `tns <name>` | 以 dev 模式新建会话，自动生成三分屏布局 |
| `tat <name>` | 连接已有会话 |
| `tls` | 列出所有会话 |
| `tkt <name>` | 结束指定会话 |
| `Prefix` + `r` | 重新加载 `~/.tmux.conf` |
| `Prefix` + `\|` / `-` | 左右分屏 / 上下分屏 |
| `Prefix` + `m` | 开关 tmux 鼠标模式，关闭后可使用终端原生框选 |
| `Option` + 方向键 | 不按 Prefix 直接切换 pane |
| copy-mode 中按 `Enter` | 复制选中内容到系统剪贴板 |

dev 布局为上方两个 pane（左窄右宽）加下方一个 pane。左上 pane 创建后自动执行 `mo status`，需要本机已安装提供 `mo` 命令的工具，否则该 pane 会提示命令不存在。

### Shell 历史

保留 50000 条历史；多个终端共享历史；重复命令只保留最新一条；以空格开头的命令不记录。

---

## 维护：同步本机配置回仓库

在本机修改配置后，执行以下命令把最新版本复制回仓库：

```bash
./update.sh
```

脚本逐个对比 [仓库内容](#仓库内容) 中的 6 个配置文件：有变化则覆盖仓库中的文件，无变化则跳过，本机不存在的文件会给出警告并跳过。

---

## 注意事项

> [!WARNING]
> - `.npmrc` 中的 `dangerously-allow-all-scripts=true` 允许所有包运行安装脚本（恢复 npm 11 及以前的行为），避免 `better-sqlite3`、`esbuild`、`node-pty` 等含原生构建的全局包被拦截后装坏。代价是关闭了 npm 12 针对依赖投毒的脚本拦截，且对项目中的 `npm install` 同样生效。
> - 同一文件中的 `allow-scripts` 白名单在上一项为 `true` 时**不起作用**。如需恢复拦截，删除 `dangerously-allow-all-scripts=true` 这一行，白名单即重新生效。
> - `cc` 别名跳过 Claude Code 的所有权限确认，只在可信目录中使用。
> - 部署步骤使用 `cp` 直接覆盖 `~` 下的配置文件，不会自动备份。

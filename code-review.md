# コードレビュー

> 実施日: 2026-05-05

## ディレクトリ構成

```
/home/kaka/dotfiles-nixos/
├── flake.nix
├── flake.lock
├── README.md
├── docs/
│   ├── install-vbox.md
│   ├── install-minipc.md
│   └── install-main.md
├── hosts/
│   ├── common/
│   │   ├── default.nix
│   │   ├── nix.nix
│   │   ├── user.nix
│   │   ├── locale.nix
│   │   ├── fonts.nix
│   │   ├── input-method.nix
│   │   └── desktop.nix
│   ├── vbox/
│   │   ├── default.nix
│   │   ├── kde.nix
│   │   ├── gnome.nix
│   │   └── hardware-configuration.nix
│   ├── minipc/
│   │   ├── default.nix
│   │   ├── kde.nix
│   │   ├── gnome.nix
│   │   └── hardware-configuration.nix
│   └── main/
│       ├── default.nix
│       ├── kde.nix
│       └── hardware-configuration.nix (要生成)
├── home/
│   ├── default.nix
│   ├── git.nix
│   ├── bash.nix
│   ├── zsh.nix
│   ├── fish.nix
│   ├── nvim.nix
│   ├── zed.nix
│   ├── plasma.nix
│   ├── fcitx5.nix
│   ├── gnome.nix
│   ├── tmux/
│   │   └── tmux.conf
│   ├── yazi/
│   │   ├── yazi.toml
│   │   ├── theme.toml
│   │   └── keymap.toml
│   ├── nvim/
│   │   ├── init.lua
│   │   ├── lua/config/
│   │   │   ├── lazy.lua
│   │   │   ├── options.lua
│   │   │   └── keymaps.lua
│   │   ├── lua/lsp/
│   │   │   ├── init.lua
│   │   │   ├── lua_ls.lua
│   │   │   └── nixd.lua
│   │   └── lua/plugins/
│   │       ├── blink-cmp.lua
│   │       ├── colorscheme.lua
│   │       ├── lspconfig.lua
│   │       └── oil.lua
│   ├── ghostty/
│   │   └── config
│   ├── wezterm/
│   │   ├── wezterm.lua
│   │   └── config/
│   │       └── keybinds.lua
│   └── icons/
│       └── upnote.png
└── scripts/
    ├── font-ls.sh
    └── install-upnote.sh
```

---

## 問題一覧

### 優先度: 高

| ファイル | 行 | 問題 |
|---------|-----|------|
| `home/git.nix` | 6 | `user.email = "kaka@example.com"` はプレースホルダーのまま。全コミットにこのメールアドレスが付与される |
| `home/nvim/lua/plugins/blink-cmp.lua` | 15 | `nerd_font_variant = 'mono'` 末尾のカンマが欠落 → Lua構文エラー |
| `scripts/install-upnote.sh` | 9 | 外部URLからAppImageをダウンロードしているがチェックサム検証なし（セキュリティリスク） |

### 優先度: 中

| ファイル | 行 | 問題 |
|---------|-----|------|
| `home/wezterm/config/keybinds.lua` | 6-8 | コメントに「水平分割（上下に分割）」とあるが実際のアクションは `SplitVertical`。コメントとアクションの方向が不一致の可能性 |
| `hosts/vbox/default.nix`, `hosts/minipc/default.nix`, `hosts/main/default.nix` | - | `environment.systemPackages` と xremap の設定が3ホストでほぼ同一内容で重複。`hosts/common/` に統合すべき |
| `home/nvim/lua/lsp/init.lua` | 4-5 | `vim.lsp.enable()` は古いパターン。`require('lspconfig').xxx.setup()` を使うべき |
| `flake.nix` | 27-28 | main / minipc の nixosConfigurations がコメントアウトされたまま |
| `docs/install-*.md` | - | GitHubのURLが `https://github.com/<owner>/<repo>` のプレースホルダーのまま |

### 優先度: 低

| ファイル | 行 | 問題 |
|---------|-----|------|
| `home/tmux/tmux.conf` | 10-26 | ステータスラインの設定が2箇所に重複・競合している |
| `home/tmux/tmux.conf` | 62 | クリップボードに `xclip` をハードコード。Wayland環境では `wl-copy` が必要 |
| `home/tmux/tmux.conf` | 66 | Fishのパスを `/run/current-system/sw/bin/fish` とハードコード。Nix式で参照するほうが望ましい |
| `home/fish.nix` | 10 | `J_SEARCH_DIRS` に `Work` ディレクトリをハードコード。存在しない環境でエラーになる可能性 |
| `home/default.nix` | 28-32 | AppImageラッパーのパスが `/home/kaka/Applications/UpNote.AppImage` とハードコード |
| `hosts/minipc/default.nix` | 50-52 | deprecated とコメントされた `amdvlk` の記述が残っている |
| `hosts/vbox/default.nix` | 20-21 | `LIBGL_ALWAYS_SOFTWARE = "1"` がグローバルに設定されている |
| `hosts/common/nix.nix` | 22 | Tailscaleがテスト用VirtualBoxを含む全ホストで有効になっている |
| プロジェクト全体 | - | `.gitignore` が存在しない |
| プロジェクト全体 | - | フォーマッタ（nixfmt, stylua）や pre-commit フックが未設定 |

---

## セキュリティ上の懸念点

1. **Gitメールのプレースホルダー** (`home/git.nix:6`) — 全コミットに `kaka@example.com` が付与される
2. **AppImageのチェックサム未検証** (`scripts/install-upnote.sh:9`) — ダウンロードファイルの完全性を確認していない
3. **Tailscaleの全ホスト有効化** (`hosts/common/nix.nix:22`) — テスト用VMにも VPN が有効
4. **Tailscaleインターフェースの完全信頼** (`hosts/common/nix.nix:27`) — `tailscale0` を trusted interface に設定

---

## 良い点

- ホスト別・Home Manager別のモジュール構造が整理されている
- 共通設定を `hosts/common/` に分離するアーキテクチャが適切
- Flakes、Home Manager、lazy.nvim 等の現代的なツールを採用
- 各ハードウェア向けのインストールドキュメントが整備されている
- Fishシェルのカスタム関数が充実している
- ハードウェア固有の最適化（AMD Vulkan ドライバー設定など）が施されている

---

## 推奨する修正順序

1. `home/git.nix` のメールアドレスを実際のものに変更（最優先）
2. `home/nvim/lua/plugins/blink-cmp.lua:15` の構文エラー修正
3. `scripts/install-upnote.sh` にSHA256チェックサム検証を追加
4. `hosts/*/default.nix` の共通パッケージリストを `hosts/common/` に統合
5. `home/tmux/tmux.conf` のステータスライン設定の重複を解消
6. `home/wezterm/config/keybinds.lua` の分割方向コメントを確認・修正
7. LSP初期化を `lspconfig.xxx.setup()` パターンに移行
8. `.gitignore` と nixfmt/stylua によるフォーマット整備

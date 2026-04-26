# dotfiles-nixos

NixOS + Home Manager によるシステム設定の管理リポジトリ。

## 構成

```
.
├── flake.nix              # Nix Flake エントリポイント
├── hosts/
│   ├── vbox/              # VirtualBox VM
│   ├── minipc/            # MiniPC (AMD Ryzen 7 8745H + Radeon 780M)
│   └── main/              # メインPC (Intel i7-2700 + RTX 3060 Ti)
├── home/
│   ├── default.nix        # Home Manager メイン設定
│   ├── git.nix            # Git 設定
│   ├── zsh.nix            # Zsh 設定
│   ├── fish.nix           # Fish シェル設定
│   └── nvim/              # Neovim 設定
├── docs/
│   ├── install-vbox.md    # VirtualBox インストール手順
│   ├── install-minipc.md  # MiniPC インストール手順
│   └── install-main.md    # メインPC インストール手順
└── scripts/
    └── font-ls.sh         # フォント一覧スクリプト
```

## 新規マシンへのインストール手順

機種別の詳細手順は `docs/` を参照:

- [VirtualBox VM](docs/install-vbox.md)
- [MiniPC (AMD Ryzen 7 8745H + Radeon 780M)](docs/install-minipc.md)
- [メインPC (Intel i7-2700 + RTX 3060 Ti)](docs/install-main.md)

---

## 使い方

### NixOS システムの再ビルド

```bash
# カレントディレクトリが dotfiles の場合
sudo nixos-rebuild switch --flake .#vbox
sudo nixos-rebuild switch --flake .#minipc
sudo nixos-rebuild switch --flake .#main

# パスを直接指定する場合
sudo nixos-rebuild switch --flake ~/dotfiles-nixos#vbox
```

### Home Manager の適用

```bash
home-manager switch --flake .#myHome
```

### 古い世代の削除（実行後に再ビルド）
```bash
sudo nix-collect-garbage -d
```

## 依存関係

- [nixpkgs-unstable](https://github.com/NixOS/nixpkgs/tree/nixpkgs-unstable)
- [home-manager](https://github.com/nix-community/home-manager)
- [xremap](https://github.com/xremap/nix-flake)

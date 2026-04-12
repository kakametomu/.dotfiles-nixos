# NixOS インストール手順 — メインPC

対象ハードウェア: **Intel Core i7-2700 + NVIDIA GeForce RTX 3060 Ti**
デスクトップ環境: **KDE Plasma 6**

---

## 1. NixOS ISO で起動

[NixOS 公式](https://nixos.org/download) から最新の **Minimal** 版 ISO をダウンロードして USB ブートする。

> Graphical 版でも問題ないが、Minimal 版で十分。

---

## 2. root に昇格

ライブ環境は `nixos` ユーザーでログインしている。以降の作業はほぼ root 権限が必要なため、最初に昇格しておく。

```bash
sudo -i
```

> 以降のコマンドはすべて root として実行する。

---

## 3. パーティション作成 & フォーマット

```bash
# ディスク確認（SATA SSD は /dev/sda、NVMe は /dev/nvme0n1）
lsblk
```

```bash
# パーティション設定（EFI 構成）
gdisk /dev/sda
# n, 1, (デフォルト), +512M, ef00  → EFI System Partition (512MB)
# n, 2, (デフォルト), (デフォルト), 8300  → Linux filesystem (残り全部)
# w → 書き込み

# フォーマット
mkfs.fat -F 32 /dev/sda1
mkfs.ext4 /dev/sda2

# マウント
mount /dev/sda2 /mnt
mkdir -p /mnt/boot
mount /dev/sda1 /mnt/boot
```

---

## 4. ハードウェア設定の生成

```bash
nixos-generate-config --root /mnt
```

`/mnt/etc/nixos/hardware-configuration.nix` が生成される。

---

## 5. dotfiles のクローン

```bash
nix-shell -p git

mkdir -p /mnt/home/kaka
git clone https://github.com/<owner>/<repo> /mnt/home/kaka/dotfiles-nixos
```

> root でクローンしているためファイルの所有者が root になる。初回ログイン後に修正する（手順 9 参照）。

---

## 6. ホスト設定を作成

```bash
mkdir -p /mnt/home/kaka/dotfiles-nixos/hosts/main

# 生成したハードウェア設定をコピー
cp /mnt/etc/nixos/hardware-configuration.nix \
   /mnt/home/kaka/dotfiles-nixos/hosts/main/
```

`hosts/main/default.nix` を作成する。`hosts/vbox/default.nix` をベースに以下を変更:

- `environment.variables.LIBGL_ALWAYS_SOFTWARE = "1"` を**削除**（VM 専用の設定）
- `inputs.xremap.nixosModules.default` は**そのまま**（CapsLock→Ctrl）
- デスクトップ環境を **GNOME → KDE Plasma 6** に変更:

```nix
# GNOME の設定を削除
# services.displayManager.gdm.enable = true;
# services.desktopManager.gnome.enable = true;

# KDE Plasma 6 に変更
services.displayManager.sddm = {
  enable = true;
  wayland.enable = true;
};
services.desktopManager.plasma6.enable = true;
```

- 以下を**追加**:

```nix
# Intel CPU マイクロコードアップデート
hardware.cpu.intel.updateMicrocode = true;

# NVIDIA ドライバー（RTX 3060 Ti）
services.xserver.videoDrivers = ["nvidia"];

hardware.nvidia = {
  modesetting.enable = true;
  powerManagement.enable = false;
  open = false; # プロプライエタリドライバーを使用
  nvidiaSettings = true;
  package = config.boot.kernelPackages.nvidiaPackages.stable;
};

hardware.graphics = {
  enable = true;
  enable32Bit = true;
};
```

---

## 7. flake.nix にホスト設定を追加

`flake.nix` の `nixosConfigurations` に追記する:

```nix
nixosConfigurations = {
  main = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    modules = [ ./hosts/main/default.nix ];
    specialArgs = { inherit inputs; };
  };
  vbox = ...; # 既存の設定
};
```

---

## 8. NixOS をインストール

```bash
cd /mnt/home/kaka/dotfiles-nixos
nixos-install --flake .#main --root /mnt
poweroff
```

電源が切れたら USB を抜いてから電源を入れる。

---

## 9. 再起動後: 所有者の修正 & Home Manager の適用

```bash
# dotfiles の所有者を kaka に変更
sudo chown -R kaka:users ~/dotfiles-nixos

cd ~/dotfiles-nixos
home-manager switch --flake .#myHome

# home-manager コマンドがない場合
nix run home-manager/master -- switch --flake .#myHome
```

---

## 10. Tailscale の認証

```bash
sudo tailscale up
```

---

## トラブルシューティング

| 症状 | 対処 |
|------|------|
| 起動後に画面が黒い / NVIDIA が認識されない | `lspci \| grep VGA` でデバイス確認。`hardware.nvidia.open = false` になっているか確認 |
| KDE が起動しない | `journalctl -b -p err` でエラー確認。SDDM のログは `journalctl -u sddm` |
| Wayland で不具合が出る | SDDM の `wayland.enable = false` にして X11 で起動するか試す |
| `nixos-install` が失敗する | flake.nix の `main` エントリが正しく追記されているか確認 |

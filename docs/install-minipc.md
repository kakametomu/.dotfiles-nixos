# NixOS インストール手順 — MiniPC

対象ハードウェア: **AMD Ryzen 7 8745H + Radeon 780M (RDNA 3)**

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
# ディスク確認（NVMe の場合は /dev/nvme0n1）
lsblk
```

```bash
# パーティション設定（EFI 構成）
gdisk /dev/nvme0n1
# n, 1, (デフォルト), +512M, ef00  → EFI System Partition (512MB)
# n, 2, (デフォルト), (デフォルト), 8300  → Linux filesystem (残り全部)
# w → 書き込み

# フォーマット
mkfs.fat -F 32 /dev/nvme0n1p1
mkfs.ext4 /dev/nvme0n1p2

# マウント
mount /dev/nvme0n1p2 /mnt
mkdir -p /mnt/boot
mount /dev/nvme0n1p1 /mnt/boot
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

## 6. ハードウェア設定をコピー

`hosts/minipc/default.nix`・`hosts/minipc/kde.nix`・`hosts/minipc/gnome.nix` はリポジトリに含まれている。
`hardware-configuration.nix` のみコピーすればよい。

```bash
cp /mnt/etc/nixos/hardware-configuration.nix \
   /mnt/home/kaka/dotfiles-nixos/hosts/minipc/
```

> デスクトップ環境を変更したい場合は `hosts/minipc/default.nix` の import を編集する（デフォルトは KDE、`./gnome.nix` に切り替え可）。

---

## 7. flake.nix のコメントを外す

`flake.nix` の `minipc` エントリはすでに存在しているのでコメントを外す:

```nix
nixosConfigurations = {
  vbox = mkSystem { hostname = "vbox"; };
  minipc = mkSystem { hostname = "minipc"; }; # ← コメントを外す
};
```

---

## 8. NixOS をインストール

```bash
cd /mnt/home/kaka/dotfiles-nixos
nixos-install --flake .#minipc --root /mnt
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
| 画面が映らない / GPU 認識されない | `lspci \| grep VGA` でデバイス確認。`amdgpu` モジュールが読まれているか `lsmod` で確認 |
| `nixos-install` が失敗する | flake.nix の `minipc` エントリが正しく追記されているか確認 |
| ブート後に GNOME が起動しない | `journalctl -b -p err` でエラーを確認 |

# NixOS インストール手順 — VirtualBox

対象環境: **VirtualBox 上の仮想マシン（x86_64）**

---

## 1. VirtualBox VM の作成

VirtualBox で以下の設定で VM を作成する。

| 項目 | 推奨値 |
|------|--------|
| メモリ | 4096 MB 以上 |
| CPU | 2 コア以上 |
| ディスク | 40 GB 以上（動的割り当て可） |
| グラフィック | VMSVGA（3D アクセラレーション: OFF） |
| ネットワーク | NAT または ブリッジアダプター |

[NixOS 公式](https://nixos.org/download) から最新の **Minimal** 版 ISO をダウンロードして VM の光学ドライブにセットして起動する。

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
# ディスク確認（VirtualBox の SATA ディスクは /dev/sda）
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

> root でクローンしているためファイルの所有者が root になる。初回ログイン後に修正する（手順 8 参照）。

---

## 6. ハードウェア設定をコピー

```bash
cp /mnt/etc/nixos/hardware-configuration.nix \
   /mnt/home/kaka/dotfiles-nixos/hosts/vbox/
```

> `hosts/vbox/default.nix` はすでに存在する。`LIBGL_ALWAYS_SOFTWARE = "1"` が設定されており、VirtualBox の OpenGL 制限（4.1 まで）に対応している。

---

## 7. NixOS をインストール

```bash
cd /mnt/home/kaka/dotfiles-nixos

# flake はgit管理下のファイルのみ参照するため、追加したファイルをステージングする
git add .

nixos-install --flake .#vbox --root /mnt
```

インストール完了後、電源を切る前にユーザーパスワードを設定する:

```bash
nixos-enter --root /mnt -c 'passwd kaka'
```

パスワードを設定したら電源を切る:

```bash
poweroff
```

VM の電源が切れたら、光学ドライブから ISO を取り出してから電源を入れる。

---

## 8. 再起動後: 所有者の修正 & Home Manager の適用

```bash
# dotfiles の所有者を kaka に変更
sudo chown -R kaka:users ~/dotfiles-nixos

cd ~/dotfiles-nixos
home-manager switch -b backup --flake .#myHome

# home-manager コマンドがない場合
nix run home-manager/master -- switch --flake .#myHome -b backup
```

---

## 9. Tailscale の認証

```bash
sudo tailscale up
```

---

## トラブルシューティング

| 症状 | 対処 |
|------|------|
| KDE が起動しない / 画面が黒い | VirtualBox の 3D アクセラレーションを OFF にする。VMSVGA を選択 |
| OpenGL エラーが出る | `LIBGL_ALWAYS_SOFTWARE = "1"` が `hosts/vbox/default.nix` に設定されているか確認 |
| `nixos-install` が失敗する | `flake.nix` の `vbox` エントリが正しいか、`hardware-configuration.nix` がコピーされているか確認 |
| `Existing file '~/.config/...' would be clobbered` | NixOS インストール後に既存の設定ファイルが残っている。`-b backup` オプションを付けて実行すると既存ファイルを `.backup` に退避してから適用できる |
| ブート後にネットワークに繋がらない | VirtualBox のネットワークアダプターが有効になっているか確認。`ip link` でインターフェースを確認 |
| 起動時に `Can't lookup blockdev` / `waiting for device /dev/disk/by-uuid/...` で止まる | `hardware-configuration.nix` に書かれた UUID が実際のディスクと一致していない。Step 6 のコピーを忘れた、またはコピー前に `nixos-install` を実行した場合に発生する。ライブ環境に戻り、Step 4 → Step 6 → Step 7 の順で再実行する |

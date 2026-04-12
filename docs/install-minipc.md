# NixOS インストール手順 — MiniPC

対象ハードウェア: **AMD Ryzen 7 8745H + Radeon 780M (RDNA 3)**

---

## 1. NixOS ISO で起動

[NixOS 公式](https://nixos.org/download) から最新の **Minimal** 版 ISO をダウンロードして USB ブートする。

> Graphical 版でも問題ないが、Minimal 版で十分。

---

## 2. パーティション作成 & フォーマット

```bash
# ディスク確認（NVMe の場合は /dev/nvme0n1）
lsblk
```

```bash
# パーティション設定（EFI 構成）
sudo fdisk /dev/nvme0n1
#   /dev/nvme0n1p1 → EFI System Partition (512MB)
#   /dev/nvme0n1p2 → Linux filesystem (残り全部)

# フォーマット
sudo mkfs.fat -F 32 /dev/nvme0n1p1
sudo mkfs.ext4 /dev/nvme0n1p2

# マウント
sudo mount /dev/nvme0n1p2 /mnt
sudo mkdir -p /mnt/boot
sudo mount /dev/nvme0n1p1 /mnt/boot
```

---

## 3. ハードウェア設定の生成

```bash
sudo nixos-generate-config --root /mnt
```

`/mnt/etc/nixos/hardware-configuration.nix` が生成される。

---

## 4. dotfiles のクローン

```bash
nix-shell -p git

git clone https://github.com/<owner>/<repo> /mnt/home/kaka/dotfiles-nixos
```

---

## 5. ホスト設定を作成

```bash
mkdir -p /mnt/home/kaka/dotfiles-nixos/hosts/minipc

# 生成したハードウェア設定をコピー
cp /mnt/etc/nixos/hardware-configuration.nix \
   /mnt/home/kaka/dotfiles-nixos/hosts/minipc/
```

`hosts/minipc/default.nix` を作成する。`hosts/vbox/default.nix` をベースに以下を変更:

- `environment.variables.LIBGL_ALWAYS_SOFTWARE = "1"` を**削除**（VM 専用の設定）
- `inputs.xremap.nixosModules.default` は**そのまま**（CapsLock→Ctrl）
- デスクトップ環境は**そのまま** GNOME
- 以下を**追加**:

```nix
# AMD CPU マイクロコードアップデート
hardware.cpu.amd.updateMicrocode = true;

# AMD GPU ドライバー（Radeon 780M / RDNA 3）
services.xserver.videoDrivers = ["amdgpu"];

# ハードウェアアクセラレーション
hardware.graphics = {
  enable = true;
  enable32Bit = true;
  extraPackages = with pkgs; [
    amdvlk
  ];
};

# Vulkan は Mesa の RADV を優先（安定性が高い）
environment.variables.AMD_VULKAN_ICD = "RADV";
```

---

## 6. flake.nix にホスト設定を追加

`flake.nix` の `nixosConfigurations` に追記する:

```nix
nixosConfigurations = {
  minipc = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    modules = [ ./hosts/minipc/default.nix ];
    specialArgs = { inherit inputs; };
  };
  vbox = ...; # 既存の設定
};
```

---

## 7. NixOS をインストール

```bash
cd /mnt/home/kaka/dotfiles-nixos
sudo nixos-install --flake .#minipc --root /mnt
sudo reboot
```

---

## 8. 再起動後: Home Manager の適用

```bash
cd ~/dotfiles-nixos
home-manager switch --flake .#myHome

# home-manager コマンドがない場合
nix run home-manager/master -- switch --flake .#myHome
```

ユーザーパスワードを設定していない場合:

```bash
passwd kaka
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
| 画面が映らない / GPU 認識されない | `lspci \| grep VGA` でデバイス確認。`amdgpu` モジュールが読まれているか `lsmod` で確認 |
| `nixos-install` が失敗する | flake.nix の `minipc` エントリが正しく追記されているか確認 |
| ブート後に GNOME が起動しない | `journalctl -b -p err` でエラーを確認 |

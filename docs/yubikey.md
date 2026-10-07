# YubiKey / PAM U2F

`hosts/common/yubikey.nix` は、`sudo`、`login`、および `kde` 向けに PAM U2F を設定します。
実際の U2F マッピングファイルは、ユーザー名、キーハンドル／認証情報 ID、
公開鍵などの認証メタデータが含まれているため、この公開リポジトリでは管理されていません。

## インストール中に設定する

NixOS インストール後、再起動する前にライブ環境で `pam_u2f` を一時的に利用して
マッピングを生成し、インストール先の `/mnt/etc/security/u2f_keys` に配置します。

```bash
nix-shell -p pam_u2f --run 'pamu2fcfg -u kaka -o pam://dotfiles-nixos > /tmp/u2f_keys'
install -Dm600 -o root -g root /tmp/u2f_keys /mnt/etc/security/u2f_keys
```

プロンプトが表示されたら YubiKey にタッチしてください。

## インストール後に設定する

すでに起動済みの環境で設定する場合は、同じオリジンを使用してマッピングを生成します。

```bash
pamu2fcfg -u kaka -o pam://dotfiles-nixos > u2f_keys
```

NixOS の設定では `/etc/security/u2f_keys` からマッピングを読み込みます。

```bash
sudo install -Dm600 -o root -g root u2f_keys /etc/security/u2f_keys
```

## サンプル

期待される形式やコマンドについては、`hosts/common/yubikey/u2f_keys.example` を参照してください。

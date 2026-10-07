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

## pamu2fcfgコマンド解説

YubiKeyなどのFIDO2/U2F対応セキュリティキーをログインや sudo の二要素認証（2FA）として利用するための設定ファイルを生成するコマンド

以下オプション

- pamu2fcfg
  - セキュリティキー（FIDO2/U2F対応キー）から認証用の公開鍵などの情報を読み取り、PAM（Linuxの認証システム）が理解できる形式の文字列を出力する。
- -u kaka
  - 設定行の先頭に付与するユーザー名を kaka に指定。これにより、ユーザー kaka がログインする際の鍵として紐付けられる。
- -o pam://dotfiles-nixos
  - オリジン（識別子）を pam://dotfiles-nixos に固定する。
	- これを指定しない場合、自動的にそのPCの現在のホスト名（pam://現在のホスト名）が使われる。しかし、NixOSなどの環境でホスト名が変わったり、DHCPで一時的なホスト名が割り当てられたりすると、認証が通らなくなる。このように明示的に固定することで、ホスト名変更による締め出しを防げる（特にドットファイルで環境を管理している場合に有効）。
- "> u2f_keys"
  - コマンドの出力結果（生成された設定用の文字列）を、カレントディレクトリの u2f_keys という名前のファイルに書き込んで保存（または上書き）する。

### 2本目登録
  - pamu2fcfg -n >> ~/.config/Yubico/u2f_keys
  - -n, --nouser	ユーザー名を含めず、鍵の識別子と公開鍵のみを出力する（バックアップキー追加時に便利）
    - ">"ではなく">>"にしないと上書きしてしまうため注意

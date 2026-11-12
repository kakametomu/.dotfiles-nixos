# YubiKey / PAM U2F

`hosts/common/yubikey.nix` で YubiKey を使った 2 要素認証 (パスワード + タッチ) を設定する。
このページは、鍵の登録から有効化、動作確認、SSH 鍵、復旧までの手順をまとめたもの。

## 目次

1. [概要](#概要)
2. [用意するもの](#用意するもの)
3. [YubiKey 本体の準備](#yubikey-本体の準備)
4. [手順 A: 起動済みの環境で有効化する](#手順-a-起動済みの環境で有効化する)
5. [手順 B: NixOS インストール中に設定する](#手順-b-nixos-インストール中に設定する)
6. [2 本目 (バックアップキー) を登録する](#2-本目-バックアップキー-を登録する)
7. [動作確認](#動作確認)
8. [SSH で FIDO2 鍵を使う](#ssh-で-fido2-鍵を使う)
9. [鍵の入れ替え・削除・紛失時](#鍵の入れ替え削除紛失時)
10. [締め出されたときの復旧](#締め出されたときの復旧)
11. [トラブルシューティング](#トラブルシューティング)
12. [pamu2fcfg コマンド解説](#pamu2fcfg-コマンド解説)

## 概要

| 項目 | 内容 |
| --- | --- |
| 設定モジュール | `hosts/common/yubikey.nix` |
| マッピングファイル | `/etc/security/u2f_keys` (リポジトリ管理外) |
| origin | `pam://dotfiles-nixos` (全ホスト共通の固定値) |
| 導入されるコマンド | `ykman`、`pamu2fcfg`、`fido2-token` など |

モジュールを有効にしたときの PAM サービスごとの挙動:

| PAM サービス | 対象 | control | 挙動 |
| --- | --- | --- | --- |
| `sudo` | `sudo` | `required` | パスワード + タッチの両方が必要 |
| `login` | TTY ログイン、SDDM ログイン | `required` | 同上 |
| `kde` | KDE の画面ロック解除 | `required` | 同上 |
| 上記以外 (`su`、`polkit-1` など) | | `sufficient` | タッチだけで通る。失敗時はパスワードにフォールバック |

注意点:

- **現在このモジュールは無効**。`hosts/common/default.nix` で `./yubikey.nix` がコメントアウトされている。
- `required` のサービスは、`/etc/security/u2f_keys` が無い、または自分の行が無いと
  **認証に必ず失敗する**。必ず「鍵を登録 → モジュールを有効化」の順で進めること。
- `security.pam.u2f.enable = true` は全 PAM サービスに U2F を追加し、個別指定の無いサービスは
  nixpkgs の既定値 `sufficient` になる。つまり `su` や polkit の認証ダイアログは
  YubiKey のタッチだけで通る。これも 2 要素にしたい場合は、該当サービスに
  `security.pam.services.<名前>.u2f.control = "required";` を追加する。
- SSH ログインには影響しない (`PasswordAuthentication` / `KbdInteractiveAuthentication` が
  無効で、公開鍵認証は PAM の auth を通らないため)。
- マッピングファイルにはユーザー名、キーハンドル、公開鍵が含まれるため、公開リポジトリには置かない。

## 用意するもの

- FIDO2 / U2F 対応の YubiKey。**2 本を強く推奨** (常用 + バックアップ)。
  1 本だけだと、紛失・故障時に `sudo` もログインもできなくなる。
- `kaka` ユーザーのパスワード (2 要素のうちの 1 つとして引き続き必要)。
- 復旧用の NixOS インストール USB (万一の締め出しに備えて手元に置いておく)。

## YubiKey 本体の準備

モジュールが無効な状態でも、一時シェルでコマンドを使える。

```bash
nix-shell -p yubikey-manager libfido2 pam_u2f
```

認識されているか確認する:

```bash
lsusb | grep -i yubi
```

```bash
ykman info
```

```bash
fido2-token -L
```

FIDO2 PIN を設定する。PAM U2F のタッチ認証だけなら必須ではないが、
SSH の常駐鍵 (resident key) を使う場合は必要になる。

```bash
ykman fido access change-pin
```

- PIN を 8 回連続で間違えると FIDO2 機能がロックされ、リセット (全 FIDO 資格情報の消去) が必要になる。
- `ykman info` が失敗する場合は `pcscd` が動いていない可能性がある
  ([トラブルシューティング](#トラブルシューティング)を参照)。

## 手順 A: 起動済みの環境で有効化する

締め出しを避けるため、順番を守ること。

### 1. root シェルを開いたままにする

別のターミナルで root シェルを開き、作業が終わるまで閉じない。
設定を誤っても、このシェルから元に戻せる。

```bash
sudo -s
```

### 2. マッピングを生成する

YubiKey を挿して実行し、LED が点滅したらタッチする。

```bash
nix-shell -p pam_u2f --run 'pamu2fcfg -u kaka -o pam://dotfiles-nixos > u2f_keys'
```

### 3. 2 本目を追記する (推奨)

1 本目を抜いて 2 本目を挿し、同じファイルに追記する。`>` ではなく `>>` を使うこと。

```bash
nix-shell -p pam_u2f --run 'pamu2fcfg -n -o pam://dotfiles-nixos >> u2f_keys'
```

### 4. 内容を確認して配置する

`kaka:` で始まる **1 行** になっていることを確認する (鍵が 2 本なら `:` 区切りで 2 つ並ぶ)。

```bash
cat u2f_keys
```

```bash
sudo install -Dm600 -o root -g root u2f_keys /etc/security/u2f_keys
```

配置後、作業用のファイルは消してよい。

```bash
rm u2f_keys
```

### 5. モジュールを有効にする

`hosts/common/default.nix` のコメントアウトを外す。

```nix
    ./yubikey.nix
```

### 6. まず `test` で反映する

`nixos-rebuild test` は現在の起動中だけ反映し、ブートエントリには登録しない。
問題があっても再起動すれば元の設定に戻る。

```bash
sudo nixos-rebuild test --flake .#minipc
```

### 7. 動作確認する

**新しいターミナル**で[動作確認](#動作確認)の項目を試す。手順 1 の root シェルはまだ閉じない。

### 8. 問題なければ `switch` で確定する

```bash
sudo nixos-rebuild switch --flake .#minipc
```

うまくいかなかった場合は、手順 1 の root シェルで `./yubikey.nix` を再びコメントアウトして
`nixos-rebuild switch` するか、そのまま再起動する。

## 手順 B: NixOS インストール中に設定する

`nixos-install` の完了後、再起動する前にライブ環境でマッピングを生成し、
インストール先 (`/mnt`) に配置する。

```bash
nix-shell -p pam_u2f --run 'pamu2fcfg -u kaka -o pam://dotfiles-nixos > /tmp/u2f_keys'
```

2 本目がある場合は差し替えて追記する。

```bash
nix-shell -p pam_u2f --run 'pamu2fcfg -n -o pam://dotfiles-nixos >> /tmp/u2f_keys'
```

```bash
install -Dm600 -o root -g root /tmp/u2f_keys /mnt/etc/security/u2f_keys
```

- VirtualBox では、先に YubiKey を VM へ USB パススルーしておく。
- モジュールが無効のままインストールする場合、この手順は後回しにして手順 A で設定してもよい。

## 2 本目 (バックアップキー) を登録する

すでに `/etc/security/u2f_keys` がある環境に鍵を追加する場合。追加したい YubiKey を挿して実行する。

```bash
pamu2fcfg -n -o pam://dotfiles-nixos | sudo tee -a /etc/security/u2f_keys > /dev/null
```

- `-n` はユーザー名を付けず `:<keyHandle>,<publicKey>,...` の形で出力する。
  `pamu2fcfg` の出力は末尾に改行が無いため、追記すると既存の `kaka:...` 行の後ろにつながる。
- `-o pam://dotfiles-nixos` を 1 本目と同じにすること。省略するとホスト名ベースの origin で
  登録され、その鍵では認証できない。
- `tee -a` (追記) を使う。`tee` だけだと上書きして 1 本目が消える。

追記後に 1 行になっているか確認し、**追加した鍵だけを挿した状態で**動作確認する。

```bash
sudo cat /etc/security/u2f_keys
```

ファイルの形式:

```text
kaka:<keyHandle1>,<publicKey1>,<coseType>,<options>:<keyHandle2>,<publicKey2>,<coseType>,<options>
```

## 動作確認

各項目で「パスワード入力 → `Please touch the FIDO authenticator.` の表示 → タッチ」の流れになる
(順番は前後することがある)。

| 確認項目 | 方法 | 期待する結果 |
| --- | --- | --- |
| sudo | `sudo -k && sudo true` | パスワードとタッチの両方を求められる |
| sudo (鍵なし) | YubiKey を抜いて `sudo -k && sudo true` | 失敗する |
| 画面ロック | `Meta + L` でロックして解除 | パスワードとタッチで解除できる |
| TTY ログイン | `Ctrl + Alt + F3` でログイン | パスワードとタッチでログインできる |
| SDDM ログイン | ログアウトして再ログイン | パスワードとタッチでログインできる |
| バックアップキー | 2 本目だけ挿して `sudo -k && sudo true` | 成功する |

`sudo -k` は sudo の認証キャッシュを破棄する。付けないとキャッシュで通ってしまい確認にならない。

画面ロックの確認は、TTY ログインができることを確かめてから行うと安全
(解除できなくなった場合の対処は[締め出されたときの復旧](#締め出されたときの復旧)を参照)。

## SSH で FIDO2 鍵を使う

`yubikey.nix` は FIDO2 デバイスの udev ルールも入れるので、`ed25519-sk` 形式の SSH 鍵を使える。
秘密鍵の本体は YubiKey 内にあり、ディスク上のファイルは「鍵ハンドル」だけになる。

### 鍵を作る

```bash
ssh-keygen -t ed25519-sk -O resident -O verify-required -O application=ssh:kaka -C "kaka@yubikey-1"
```

| オプション | 意味 |
| --- | --- |
| `-t ed25519-sk` | FIDO2 セキュリティキーを使う Ed25519 鍵 |
| `-O resident` | 鍵ハンドルを YubiKey 内にも保存する (常駐鍵)。別の PC でも取り出せる。FIDO2 PIN が必要 |
| `-O verify-required` | 使用のたびに PIN + タッチを要求する (サーバー側 OpenSSH 8.3 以降) |
| `-O application=ssh:kaka` | YubiKey 内での識別名。`ssh:` で始める必要がある |
| `-C` | コメント。どの YubiKey の鍵か分かる名前にしておく |

`~/.ssh/id_ed25519_sk` と `~/.ssh/id_ed25519_sk.pub` ができる。
バックアップキーでも同じ手順で別の鍵を作り、両方の公開鍵を接続先に登録しておく。

### 公開鍵を登録する

- このリポジトリのホストに入る場合は、`hosts/common/user.nix` の
  `openssh.authorizedKeys.keys` に `.pub` の内容を追加して `nixos-rebuild switch` する。
- GitHub は Settings → SSH and GPG keys に追加する。

### 別の PC で常駐鍵を取り出す

YubiKey を挿して実行すると、カレントディレクトリに `id_ed25519_sk_rk_*` が書き出される。

```bash
cd ~/.ssh && ssh-keygen -K
```

### YubiKey 内の常駐鍵を確認・削除する

```bash
ykman fido credentials list
```

```bash
ykman fido credentials delete <credential-id>
```

## 鍵の入れ替え・削除・紛失時

`/etc/security/u2f_keys` は 1 ユーザー 1 行で、鍵は `:` 区切りで並んでいる。

- **追加**: [2 本目を登録する](#2-本目-バックアップキー-を登録する)の手順で追記する。
- **削除**: `sudoedit /etc/security/u2f_keys` で該当する `:<keyHandle>,<publicKey>,...` の
  ブロックを消す。どのブロックがどの鍵か分からない場合は、残したい鍵だけで作り直すほうが確実。
- **作り直し**: 手順 A の 2〜4 をやり直して上書きする。
- **紛失した場合**: バックアップキーでログインし、紛失した鍵のブロックを削除する。
  あわせて SSH の `authorized_keys` や GitHub などの Web サービスからも紛失した鍵を外す。

編集中は root シェルを別に開いておき、保存後に `sudo -k && sudo true` で確認する。

## 締め出されたときの復旧

### 画面ロックだけ解除できない

`Ctrl + Alt + F3` で TTY に切り替えてログインし、セッションのロックを解除する。

```bash
loginctl list-sessions
```

```bash
loginctl unlock-session <セッション ID>
```

### sudo / ログインができない (以前の世代に戻す)

モジュールを有効にする前の世代が残っていれば、それで起動するのが最も簡単。

1. 再起動し、ブートメニューで YubiKey を有効にする前の世代を選ぶ。
2. 起動したら `/etc/security/u2f_keys` を修正するか、`./yubikey.nix` をコメントアウトして
   `sudo nixos-rebuild switch --flake .#<ホスト名>` する。

### 以前の世代が無い (ライブ USB から直す)

1. NixOS インストール USB で起動し、インストール時と同じようにルートを `/mnt` にマウントする
   (手順は各ホストの `docs/install-*.md` を参照)。
2. 手元に登録済みの YubiKey がある場合は、マッピングを作り直して配置する。

   ```bash
   nix-shell -p pam_u2f --run 'pamu2fcfg -u kaka -o pam://dotfiles-nixos > /tmp/u2f_keys'
   ```

   ```bash
   install -Dm600 -o root -g root /tmp/u2f_keys /mnt/etc/security/u2f_keys
   ```

3. YubiKey が無い場合は、リポジトリ側で `./yubikey.nix` をコメントアウトして再インストールする。

   ```bash
   nixos-install --flake /mnt/home/kaka/dotfiles-nixos#<ホスト名> --root /mnt
   ```

## トラブルシューティング

### タッチを求められずに失敗する

- `/etc/security/u2f_keys` が存在し、`kaka:` で始まる行があるか確認する。

  ```bash
  sudo cat /etc/security/u2f_keys
  ```

- 行が途中で改行されていないか確認する (1 ユーザー 1 行)。
- 登録時の origin が `pam://dotfiles-nixos` だったか確認する。`-o` を付け忘れた鍵は使えないので登録し直す。
- YubiKey が認識されているか `fido2-token -L` で確認する。

### 原因が分からない

`yubikey.nix` の `security.pam.u2f.settings` に一時的に `debug = true;` を追加して反映すると、
認証時に詳細なログが表示される。調査が終わったら外す。

```bash
journalctl -b | grep -i u2f
```

### 画面ロックだけ解除できない

KDE の画面ロックはユーザー権限で PAM を実行するため、root 所有・`600` のマッピングファイルを
読めずに失敗する可能性がある。その場合は読み取り権限を付ける
(ファイルの中身はキーハンドルと公開鍵で、秘密鍵は含まれない)。

```bash
sudo chmod 644 /etc/security/u2f_keys
```

### `ykman` がデバイスを見つけられない

```bash
systemctl status pcscd.socket
```

```bash
sudo systemctl restart pcscd
```

### 一般ユーザーで `pamu2fcfg` / `ssh-keygen` が失敗する

モジュール有効化前は FIDO2 デバイスの udev ルール (`libfido2`) が入っていないため、
`/dev/hidraw*` にアクセスできないことがある。`sudo` を付けて実行するか、モジュール有効化後に行う。
有効化直後は YubiKey を挿し直すとルールが適用される。

### VirtualBox で認識されない

VM のメニュー「デバイス → USB」で YubiKey にチェックを入れてパススルーする。
ホスト側ユーザーが `vboxusers` グループに入っている必要がある。

## pamu2fcfg コマンド解説

YubiKey などの FIDO2 / U2F 対応セキュリティキーを、ログインや `sudo` の 2 要素認証に使うための
マッピング行を生成するコマンド。

```bash
pamu2fcfg -u kaka -o pam://dotfiles-nixos > u2f_keys
```

- `pamu2fcfg`
  - セキュリティキーに資格情報を作らせ、キーハンドルと公開鍵を PAM (`pam_u2f`) が読める形式で出力する。
- `-u kaka`
  - 行の先頭に付けるユーザー名。この鍵がユーザー `kaka` の認証に使われる。
- `-o pam://dotfiles-nixos`
  - origin (識別子) を固定する。
  - 省略すると `pam://<現在のホスト名>` になる。ホスト名が変わると認証できなくなり、
    `main` / `minipc` / `vbox` で同じファイルを使い回すこともできない。
    `yubikey.nix` の `origin` と必ず一致させる。
- `> u2f_keys`
  - 出力をカレントディレクトリの `u2f_keys` に保存 (上書き) する。

そのほかのオプション:

| オプション | 意味 |
| --- | --- |
| `-n`, `--nouser` | ユーザー名を付けずに出力する。既存の行へ鍵を追記するときに使う |
| `-N`, `--pin-verification` | 認証時に FIDO2 PIN も要求する鍵として登録する |
| `-V`, `--user-verification` | 認証時にユーザー検証 (PIN や生体認証) を要求する |
| `-P`, `--no-user-presence` | タッチ不要の鍵として登録する (非推奨) |
| `-r`, `--resident` | 常駐鍵として登録する |

期待される形式のサンプルは `hosts/common/yubikey/u2f_keys.example` を参照。

# YubiKey / PAM U2F

`hosts/common/yubikey.nix` で、YubiKey によるパスワードレス認証を設定する。
このページは、鍵の登録から有効化、動作確認、SSH 鍵、Bitwarden、復旧までの手順をまとめたもの。

## 目次

1. [概要](#概要)
2. [用意するもの](#用意するもの)
3. [YubiKey 本体の準備](#yubikey-本体の準備)
4. [手順 A: 起動済みの環境で有効化する](#手順-a-起動済みの環境で有効化する)
5. [手順 B: NixOS インストール中に設定する](#手順-b-nixos-インストール中に設定する)
6. [鍵を追加する](#鍵を追加する)
7. [動作確認](#動作確認)
8. [SSH で FIDO2 鍵を使う](#ssh-で-fido2-鍵を使う)
9. [Bitwarden で使う](#bitwarden-で使う)
10. [鍵の入れ替え・削除・紛失時](#鍵の入れ替え削除紛失時)
11. [うまく認証できないときの復旧](#うまく認証できないときの復旧)
12. [トラブルシューティング](#トラブルシューティング)
13. [pamu2fcfg コマンド解説](#pamu2fcfg-コマンド解説)

## 概要

想定している鍵の構成:

| 鍵 | 役割 | 認証時に必要なもの | 登録時のオプション |
| --- | --- | --- | --- |
| YubiKey Bio | メイン (普段使い) | 指紋 | `-V` |
| タッチ式 YubiKey | バックアップ | FIDO2 PIN + タッチ | `-N` |
| (鍵なし) | フォールバック | パスワード | — |

どちらの鍵も「鍵を持っている」+「指紋または PIN」の 2 要素になるため、パスワード入力は省ける。

| 項目 | 内容 |
| --- | --- |
| 設定モジュール | `hosts/common/yubikey.nix` |
| マッピングファイル | `/etc/security/u2f_keys` (リポジトリ管理外) |
| origin | `pam://dotfiles-nixos` (全ホスト共通の固定値) |
| PAM の control | `sufficient` (鍵で通ればパスワード不要、通らなければパスワード) |
| 導入されるコマンド | `ykman`、`pamu2fcfg`、`fido2-token` など |

対象になる認証: `sudo`、TTY ログイン、SDDM ログイン、KDE の画面ロック解除、
およびそのほかの PAM サービス (`su`、polkit の認証ダイアログなど)。

注意点:

- **現在このモジュールは無効**。`hosts/common/default.nix` で `./yubikey.nix` がコメントアウトされている。
- **指紋 / PIN の要否は鍵ごとに登録時のオプションで決まる**。`-V` も `-N` も付けずに登録した鍵は
  タッチだけで通ってしまう (拾った人がそのまま `sudo` できる) ので、必ずどちらかを付ける。
- `yubikey.nix` 側で `userverification = 1` を全体に設定しないこと。指紋センサーの無い
  バックアップキーが無視されて使えなくなる。
- **パスワードだけでも通る**。`sufficient` は鍵の認証に失敗するとパスワードにフォールバックする。
  鍵を無くしても締め出されない代わりに、パスワードの強度は引き続き重要。
  パスワードも必須にしたい場合は、該当サービスの `control` を `"required"` にする
  (その場合は鍵が無いと認証できなくなる)。
- SSH ログインには影響しない (`PasswordAuthentication` / `KbdInteractiveAuthentication` が
  無効で、公開鍵認証は PAM の auth を通らないため)。
- マッピングファイルにはユーザー名、キーハンドル、公開鍵が含まれるため、公開リポジトリには置かない。

## 用意するもの

- YubiKey Bio (メイン) とタッチ式の YubiKey (バックアップ)。
- それぞれの FIDO2 PIN (このあと設定する)。2 本で同じ PIN にしてもよい。
- `kaka` ユーザーのパスワード (フォールバックとして引き続き使う)。

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

### FIDO2 PIN を設定する (2 本とも)

Bio は指紋登録の前に PIN が必須。バックアップキーは PIN そのものが認証要素になる。
鍵を 1 本ずつ挿して実行する。

```bash
ykman fido access change-pin
```

PIN を 8 回連続で間違えると FIDO2 機能がロックされ、リセット (全 FIDO 資格情報の消去) が必要になる。

### 指紋を登録する (Bio のみ)

```bash
ykman fido fingerprints add right-index
```

LED の点滅に合わせて、同じ指を数回センサーに当てる。
読み取りに失敗したときのために、別の指も登録しておくとよい。

```bash
ykman fido fingerprints add left-index
```

```bash
ykman fido fingerprints list
```

指紋が 3 回連続で一致しないと指紋認証がブロックされ、PIN を使う操作
(例: `ykman fido fingerprints list`) を行うまで解除されない。

## 手順 A: 起動済みの環境で有効化する

### 1. Bio を登録する

Bio を挿して実行し、LED が点滅したら登録済みの指を当てる。

```bash
nix-shell -p pam_u2f --run 'pamu2fcfg -u kaka -o pam://dotfiles-nixos -V > u2f_keys'
```

### 2. バックアップキーを追記する

Bio を抜いてバックアップキーを挿し、同じファイルに追記する。`>` ではなく `>>` を使うこと。
PIN を聞かれたら入力し、LED が点滅したらタッチする。

```bash
nix-shell -p pam_u2f --run 'pamu2fcfg -n -o pam://dotfiles-nixos -N >> u2f_keys'
```

### 3. 内容を確認して配置する

`kaka:` で始まる **1 行** に、`:` 区切りで鍵が 2 つ並んでいることを確認する。
1 つ目の末尾に `+verification`、2 つ目の末尾に `+pin` が含まれていれば、オプションが効いている。

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

### 4. モジュールを有効にする

`hosts/common/default.nix` のコメントアウトを外す。

```nix
    ./yubikey.nix
```

### 5. まず `test` で反映する

`nixos-rebuild test` は現在の起動中だけ反映し、ブートエントリには登録しない。
問題があっても再起動すれば元の設定に戻る。

```bash
sudo nixos-rebuild test --flake .#minipc
```

### 6. 動作確認する

**新しいターミナル**で[動作確認](#動作確認)の項目を試す。

### 7. 問題なければ `switch` で確定する

```bash
sudo nixos-rebuild switch --flake .#minipc
```

## 手順 B: NixOS インストール中に設定する

`nixos-install` の完了後、再起動する前にライブ環境でマッピングを生成し、
インストール先 (`/mnt`) に配置する。PIN 設定と指紋登録が済んでいる鍵を使うこと。

Bio を挿して:

```bash
nix-shell -p pam_u2f --run 'pamu2fcfg -u kaka -o pam://dotfiles-nixos -V > /tmp/u2f_keys'
```

バックアップキーに差し替えて:

```bash
nix-shell -p pam_u2f --run 'pamu2fcfg -n -o pam://dotfiles-nixos -N >> /tmp/u2f_keys'
```

```bash
install -Dm600 -o root -g root /tmp/u2f_keys /mnt/etc/security/u2f_keys
```

- VirtualBox では、先に YubiKey を VM へ USB パススルーしておく。
- マッピングが無くてもパスワードでログインできるので、この手順は後回しにして
  手順 A で設定してもよい。

## 鍵を追加する

すでに `/etc/security/u2f_keys` がある環境に鍵を追加する場合。追加したい YubiKey を挿して実行する。

指紋で認証する鍵 (Bio):

```bash
pamu2fcfg -n -o pam://dotfiles-nixos -V | sudo tee -a /etc/security/u2f_keys > /dev/null
```

PIN + タッチで認証する鍵:

```bash
pamu2fcfg -n -o pam://dotfiles-nixos -N | sudo tee -a /etc/security/u2f_keys > /dev/null
```

- `-n` はユーザー名を付けず `:<keyHandle>,<publicKey>,...` の形で出力する。
  `pamu2fcfg` の出力は末尾に改行が無いため、追記すると既存の `kaka:...` 行の後ろにつながる。
- `-o pam://dotfiles-nixos` をほかの鍵と同じにすること。省略するとホスト名ベースの origin で
  登録され、その鍵では認証できない。
- `tee -a` (追記) を使う。`tee` だけだと上書きして既存の鍵が消える。

追記後に 1 行になっているか確認し、**追加した鍵だけを挿した状態で**動作確認する。

```bash
sudo cat /etc/security/u2f_keys
```

ファイルの形式:

```text
kaka:<keyHandle1>,<publicKey1>,<coseType>,<options>:<keyHandle2>,<publicKey2>,<coseType>,<options>
```

## 動作確認

| 確認項目 | 方法 | 期待する結果 |
| --- | --- | --- |
| sudo (Bio) | Bio を挿して `sudo -k && sudo true` | 指紋だけで通る。パスワードは聞かれない |
| sudo (Bio、未登録の指) | 登録していない指を当てる | 鍵では通らず、パスワードを聞かれる |
| sudo (バックアップ) | バックアップキーだけ挿して `sudo -k && sudo true` | PIN 入力 + タッチで通る |
| sudo (鍵なし) | 鍵を抜いて `sudo -k && sudo true` | パスワードを聞かれ、パスワードで通る |
| 画面ロック | `Meta + L` でロックして解除 | 鍵で解除できる |
| TTY ログイン | `Ctrl + Alt + F3` でログイン | ユーザー名入力後、鍵でログインできる |
| SDDM ログイン | ログアウトして再ログイン | 鍵でログインできる |

- `sudo -k` は sudo の認証キャッシュを破棄する。付けないとキャッシュで通ってしまい確認にならない。
- 「未登録の指」の確認は重要。これで通ってしまう場合は `-V` が効いていないので登録し直す。
  指紋を 3 回間違えるとブロックされるので、試すのは 1 回にしておく。
- SDDM と画面ロックはパスワード欄が先に表示される。パスワード欄を空のまま Enter を押すと
  鍵の認証に進む想定だが、実機での挙動は未確認。
- 鍵を挿したままパスワードで認証したいときは、鍵を抜くか、鍵の認証が失敗するのを待つ。

## SSH で FIDO2 鍵を使う

`yubikey.nix` は FIDO2 デバイスの udev ルールも入れるので、`ed25519-sk` 形式の SSH 鍵を使える。
秘密鍵の本体は YubiKey 内にあり、ディスク上のファイルは「鍵ハンドル」だけになる。

### 鍵を作る

```bash
ssh-keygen -t ed25519-sk -O resident -O verify-required -O application=ssh:kaka -C "kaka@yubikey-bio"
```

| オプション | 意味 |
| --- | --- |
| `-t ed25519-sk` | FIDO2 セキュリティキーを使う Ed25519 鍵 |
| `-O resident` | 鍵ハンドルを YubiKey 内にも保存する (常駐鍵)。別の PC でも取り出せる。FIDO2 PIN が必要 |
| `-O verify-required` | 使用のたびに本人確認 (Bio は指紋、タッチ式は PIN + タッチ) を要求する。サーバー側 OpenSSH 8.3 以降 |
| `-O application=ssh:kaka` | YubiKey 内での識別名。`ssh:` で始める必要がある |
| `-C` | コメント。どの YubiKey の鍵か分かる名前にしておく |

`~/.ssh/id_ed25519_sk` と `~/.ssh/id_ed25519_sk.pub` ができる。
バックアップキーでも同じ手順で別の鍵を作り (`-f ~/.ssh/id_ed25519_sk_backup` などで別名にする)、
両方の公開鍵を接続先に登録しておく。

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

## Bitwarden で使う

Bitwarden には YubiKey を使う場面が 3 つある。以下は公式ヘルプなどの調査結果で、実機では未確認。

| 用途 | マスターパスワード | 対応クライアント |
| --- | --- | --- |
| 2 段階ログイン (FIDO2 WebAuthn) | 必要 (パスワード + 鍵) | Web、ブラウザ拡張、デスクトップ、モバイル |
| パスキーでログイン | PRF 対応なら不要 | Web、Chromium 系ブラウザの拡張 |
| デスクトップアプリのロック解除 | 不要 (ログイン済みの保管庫の解除のみ) | デスクトップ (polkit 経由) |

### 2 段階ログイン

1. Web 保管庫の「設定 → セキュリティ → 2 段階ログイン」を開く。
2. 「パスキー (FIDO2 WebAuthn)」の「管理」から Bio を登録する。
3. 同じ画面でバックアップキーも登録する。
4. **リカバリーコードを控える**。鍵をすべて無くしたときに 2 段階ログインを解除する唯一の手段。

無料プランでも利用でき、鍵は 5 本まで (Premium は 10 本まで) 登録できる。

### パスキーでログイン

Web 保管庫の「設定 → セキュリティ → マスターパスワード」付近にある「パスキーでログイン」から登録する。

- ブラウザと鍵の両方が PRF に対応していれば「保管庫の暗号化に使用」を有効にでき、
  マスターパスワードなしで復号までできる。非対応の場合はログイン後にマスターパスワードが必要。
- Chromium 系ブラウザ (Chrome、Brave、Vivaldi、Chromium) を使う。
- YubiKey 5 は PRF 対応と明記されているが、Bio の PRF 対応は未確認。
  登録時に「保管庫の暗号化に使用」を選べるかで判断する。

### デスクトップアプリのロック解除

Linux 版デスクトップアプリの「システム認証でロック解除」は polkit を使い、polkit は PAM に委譲する。
`yubikey.nix` を有効にすると polkit の認証も YubiKey で通るため、Bitwarden の解除にも使える見込み。

- このリポジトリは Flatpak 版 (`com.bitwarden.desktop`) を使っている。Flatpak 版は
  polkit ポリシーの手動インストールが必要で、NixOS での導入方法は未調査。
- Flatpak 版でブラウザ拡張の解除まで連携できるかは、情報源によって食い違っている。

## 鍵の入れ替え・削除・紛失時

`/etc/security/u2f_keys` は 1 ユーザー 1 行で、鍵は `:` 区切りで並んでいる。

- **追加**: [鍵を追加する](#鍵を追加する)の手順で追記する。
- **削除**: `sudoedit /etc/security/u2f_keys` で該当する `:<keyHandle>,<publicKey>,...` の
  ブロックを消す。末尾が `+verification` のものが Bio、`+pin` のものがバックアップキー。
- **作り直し**: 手順 A の 1〜3 をやり直して上書きする。
- **紛失した場合**: 残った鍵かパスワードでログインし、紛失した鍵のブロックを削除する。
  あわせて SSH の `authorized_keys`、GitHub、Bitwarden などからも紛失した鍵を外す。

## うまく認証できないときの復旧

`sufficient` 構成なので、鍵で通らなくても**パスワードで認証できる**。
まず鍵を抜いてパスワードで入り、原因を調べる。

### Bio の指紋がブロックされた

3 回連続で一致しないとブロックされる。PIN を使う操作を行うと解除される。

```bash
ykman fido fingerprints list
```

### 画面ロックを解除できない

`Ctrl + Alt + F3` で TTY に切り替えてログインし、セッションのロックを解除する。

```bash
loginctl list-sessions
```

```bash
loginctl unlock-session <セッション ID>
```

### 設定変更後にログインできなくなった

1. 再起動し、ブートメニューで変更前の世代を選んで起動する。
2. `./yubikey.nix` をコメントアウトして `sudo nixos-rebuild switch --flake .#<ホスト名>` する。

以前の世代も使えない場合は、NixOS インストール USB で起動してルートを `/mnt` にマウントし
(手順は各ホストの `docs/install-*.md` を参照)、リポジトリ側でモジュールを無効にして再インストールする。

```bash
nixos-install --flake /mnt/home/kaka/dotfiles-nixos#<ホスト名> --root /mnt
```

## トラブルシューティング

### 鍵を挿しているのにパスワードを聞かれる

- `/etc/security/u2f_keys` が存在し、`kaka:` で始まる行があるか確認する。

  ```bash
  sudo cat /etc/security/u2f_keys
  ```

- 行が途中で改行されていないか確認する (1 ユーザー 1 行)。
- 登録時の origin が `pam://dotfiles-nixos` だったか確認する。`-o` を付け忘れた鍵は使えないので登録し直す。
- YubiKey が認識されているか `fido2-token -L` で確認する。
- Bio の場合、指紋がブロックされていないか確認する (上記の復旧手順を参照)。

### 原因が分からない

`yubikey.nix` の `security.pam.u2f.settings` に一時的に `debug = true;` を追加して反映すると、
認証時に詳細なログが表示される。調査が終わったら外す。

```bash
journalctl -b | grep -i u2f
```

### 画面ロックだけ鍵で解除できない

KDE の画面ロックはユーザー権限で PAM を実行するため、root 所有・`600` のマッピングファイルを
読めずに鍵の認証が失敗する可能性がある。その場合は読み取り権限を付ける
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

YubiKey などの FIDO2 / U2F 対応セキュリティキーを PAM の認証に使うための
マッピング行を生成するコマンド。

```bash
pamu2fcfg -u kaka -o pam://dotfiles-nixos -V > u2f_keys
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
- `-V`
  - 認証時にユーザー検証 (Bio の指紋) を必須にする。出力の末尾に `+verification` が付く。
- `> u2f_keys`
  - 出力をカレントディレクトリの `u2f_keys` に保存 (上書き) する。

そのほかのオプション:

| オプション | 意味 |
| --- | --- |
| `-n`, `--nouser` | ユーザー名を付けずに出力する。既存の行へ鍵を追記するときに使う |
| `-N`, `--pin-verification` | 認証時に FIDO2 PIN を必須にする。指紋センサーの無い鍵で使う |
| `-V`, `--user-verification` | 認証時にユーザー検証 (指紋など) を必須にする |
| `-P`, `--no-user-presence` | タッチ不要の鍵として登録する (非推奨) |
| `-r`, `--resident` | 常駐鍵として登録する |

期待される形式のサンプルは `hosts/common/yubikey/u2f_keys.example` を参照。

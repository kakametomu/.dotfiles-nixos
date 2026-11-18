# YubiKey / PAM U2F

`hosts/common/yubikey.nix` で、YubiKey による認証を設定する。
ログイン (SDDM / TTY) はパスワード + 鍵の 2 要素、`sudo` や画面ロック解除は鍵だけで通る。
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
12. [最初からやり直す](#最初からやり直す)
13. [トラブルシューティング](#トラブルシューティング)
14. [コマンド解説](#コマンド解説)

## 概要

想定している鍵の構成:

| 鍵 | 役割 | 認証時に必要なもの | 登録時のオプション |
| --- | --- | --- | --- |
| YubiKey Bio | メイン (普段使い) | 指紋 | `-V` |
| タッチ式 YubiKey | バックアップ | FIDO2 PIN + タッチ | `-N` |
| (鍵なし) | `sudo` などのフォールバック | パスワード | — |

どちらの鍵も「鍵を持っている」+「指紋または PIN」の 2 要素になる。

認証の種類ごとの動作:

| 認証 | PAM サービス | control | 必要なもの | 鍵が無いとき |
| --- | --- | --- | --- | --- |
| SDDM ログイン / TTY ログイン | `login` | `required` | パスワード + 鍵 | ログインできない |
| `sudo` | `sudo` | `sufficient` | 鍵 (通らなければパスワード) | パスワードで通る |
| KDE の画面ロック解除 | `kde` | `sufficient` | 鍵 (通らなければパスワード) | パスワードで通る |
| `su`、polkit の認証ダイアログなど | 各サービス | `sufficient` (nixpkgs の既定値) | 鍵 (通らなければパスワード) | パスワードで通る |

ログインだけ `required` にしているのは、KDE ウォレットを自動で開くため。
`sufficient` だと鍵で通った時点で認証が終わり、入力したパスワードが KDE ウォレット (`pam_kwallet5`) に
渡らないので、ログイン後にウォレットのパスワードを聞かれる。
経緯は [調査ログ](ai-logs/2026-11-18-kwallet-prompt-after-yubikey.md) を参照。

| 項目 | 内容 |
| --- | --- |
| 設定モジュール | `hosts/common/yubikey.nix` |
| 対象ホスト | `main`、`minipc` (各ホストの `default.nix` で読み込む)。`vbox` は検証用のため使わない |
| マッピングファイル | `/etc/security/u2f_keys` (リポジトリ管理外) |
| origin | `pam://dotfiles-nixos` (全ホスト共通の固定値) |
| PAM の control | `login` は `required`、それ以外は `sufficient` (上の表を参照) |
| 導入されるコマンド | `ykman`、`pamu2fcfg`、`fido2-token` など |

注意点:

- **`/etc/security/u2f_keys` が無いとログインできない**。SDDM だけでなく TTY からも入れなくなる。
  新しくインストールするときは、再起動の前に必ず配置する ([手順 B](#手順-b-nixos-インストール中に設定する))。
- **鍵が無いとログインできない**。2 本とも失った場合は[復旧手順](#設定変更後にログインできなくなった)を参照。
- **指紋 / PIN の要否は鍵ごとに登録時のオプションで決まる**。`-V` も `-N` も付けずに登録した鍵は
  タッチだけで通ってしまう (拾った人がそのまま `sudo` できる) ので、必ずどちらかを付ける。
- `yubikey.nix` 側で `userverification = 1` を全体に設定しないこと。指紋センサーの無い
  バックアップキーが無視されて使えなくなる。
- **`sudo` などはパスワードだけでも通る**。`sufficient` は鍵の認証に失敗するとパスワードにフォールバックする。
  パスワードの強度は引き続き重要。
- SSH ログインには影響しない (`PasswordAuthentication` / `KbdInteractiveAuthentication` が
  無効で、公開鍵認証は PAM の auth を通らないため)。
- マッピングファイルにはユーザー名、キーハンドル、公開鍵が含まれるため、公開リポジトリには置かない。

## 用意するもの

- YubiKey Bio (メイン) とタッチ式の YubiKey (バックアップ)。
- それぞれの FIDO2 PIN (このあと設定する)。2 本で同じ PIN にしてもよい。
- `kaka` ユーザーのパスワード (ログイン時に鍵と一緒に使う。`sudo` などのフォールバックにもなる)。

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

### 4. モジュールを読み込む

使うホストの `hosts/<ホスト名>/default.nix` で読み込む (`main` と `minipc` は読み込み済み)。

```nix
    ../../hosts/common/yubikey.nix
```

**必ず 1〜3 で `/etc/security/u2f_keys` を配置してから反映すること。**
配置前に反映すると、ログインに必要な鍵の登録が無いため、ログインできなくなる。

### 5. まず `test` で反映する

`nixos-rebuild test` は現在の起動中だけ反映し、ブートエントリには登録しない。
問題があっても再起動すれば元の設定に戻る。

```bash
sudo nixos-rebuild test --flake .#minipc
```

### 6. 動作確認する

**デスクトップにログインしたまま**、新しいターミナルと TTY で[動作確認](#動作確認)の項目を試す。
ログアウトや再起動はしないこと (`test` の設定のままログイン画面に戻ると、失敗したときに入れなくなる。
その場合は再起動すれば元の設定に戻る)。

### 7. 問題なければ `switch` で確定する

```bash
sudo nixos-rebuild switch --flake .#minipc
```

## 手順 B: NixOS インストール中に設定する

`main` と `minipc` はインストール直後からこのモジュールが有効なので、**この手順は必須**。
`/mnt/etc/security/u2f_keys` が無いまま再起動すると、SDDM からも TTY からもログインできない。

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

内容を確認する。`kaka:` で始まる 1 行に、`+verification` と `+pin` の鍵が 2 つ並んでいればよい。

```bash
cat /mnt/etc/security/u2f_keys
```

- 鍵を 1 本しか登録しないと、その鍵を失ったときにログインできなくなる。必ず 2 本とも登録する。
- `vbox` はこのモジュールを読み込まないので、この手順は不要。

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
| TTY ログイン (Bio) | `Ctrl + Alt + F3` でユーザー名、パスワードを入力 | 続けて指紋を求められ、ログインできる |
| TTY ログイン (バックアップ) | バックアップキーだけ挿して同上 | 続けて PIN + タッチを求められ、ログインできる |
| TTY ログイン (鍵なし) | 鍵を抜いて同上 | パスワードが正しくてもログインできない |
| TTY ログイン (パスワード誤り) | 鍵を挿して誤ったパスワードを入力 | 鍵で応えてもログインできない |
| SDDM ログイン | 再起動してパスワードを入力し、鍵で応える | ログインでき、KDE ウォレットのパスワードを聞かれない |

- `sudo -k` は sudo の認証キャッシュを破棄する。付けないとキャッシュで通ってしまい確認にならない。
- 「未登録の指」の確認は重要。これで通ってしまう場合は `-V` が効いていないので登録し直す。
  指紋を 3 回間違えるとブロックされるので、試すのは 1 回にしておく。
- TTY と SDDM のログインは `switch` の前 (`test` の段階) に TTY で確認する。SDDM は再起動後に確認する。
- SDDM ではパスワードを入力して Enter を押したあと、鍵に指紋 (Bio) または PIN + タッチで応える。
  パスワード欄を空のまま Enter を押してもログインできない。
- 画面ロックはパスワード欄が先に表示される。パスワード欄を空のまま Enter を押すと
  鍵の認証に進む想定だが、実機での挙動は未確認。
- `sudo` などで鍵を挿したままパスワードで認証したいときは、鍵を抜くか、鍵の認証が失敗するのを待つ。

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

Bitwarden で YubiKey を使う場面は 3 つあり、それぞれ守るものが違う。
以下は公式ヘルプとソースコードの調査結果に基づく。実機では未確認で、
メニュー名は Bitwarden のバージョンや表示言語によって異なることがある。

| 用途 | 何を守るか | マスターパスワード | 対応クライアント |
| --- | --- | --- | --- |
| 2 段階ログイン | 新しい端末からのログイン | 必要 (パスワード + 鍵) | ほぼすべてのアプリ |
| パスキーでログイン | 同上 (パスワードの代わり) | 条件を満たせば不要 | Web、Chromium 系ブラウザの拡張 |
| システム認証でロック解除 | ログイン済みの保管庫のロック | 不要 | デスクトップアプリ、連携したブラウザ拡張 |

### おすすめの構成

普段はマスターパスワードを打たずに済ませ、鍵を無くしても入れる状態を保つ構成。

| 場面 | 使うもの |
| --- | --- |
| 普段のロック解除 (デスクトップアプリ) | システム認証 → Bio の指紋 |
| 普段のロック解除 (ブラウザ拡張) | デスクトップアプリ連携、または拡張の PIN |
| 新しい端末やブラウザでのログイン | パスキー (Bio)、またはマスターパスワード + 2 段階ログイン |
| Bio が使えないとき | マスターパスワード + バックアップキー |
| 鍵が 2 本とも使えないとき | マスターパスワード + リカバリーコード |

守ること:

- **マスターパスワードは引き続き必須**。どの方式を使っても、最後の手段として残る。
  普段打たなくなると忘れやすいので、紙に書いて保管するなどしておく。
- **リカバリーコードを必ず控える**。保管場所は Bitwarden の外 (紙など) にする。
- 保管庫のタイムアウト時の動作は「ロック」にする。「ログアウト」にすると、
  毎回マスターパスワードかパスキーでのログインが必要になる。

設定は次の順に進める。

### 1. 2 段階ログインに鍵を登録する

マスターパスワードが漏れても、鍵が無ければログインできないようにする設定。
Web 保管庫 (`https://vault.bitwarden.com`) で行う。

1. 「設定 (Settings) → セキュリティ (Security) → 2 段階ログイン (Two-step login)」を開く。
2. 「パスキー (Passkey / FIDO2 WebAuthn)」の「管理 (Manage)」を押し、マスターパスワードを入力する。
3. 鍵に名前を付ける (例: `yubikey-bio`)。
4. Bio を挿して「キーを読み取る (Read key)」を押し、ブラウザの指示に従って指紋を当てる。
5. 「保存 (Save)」を押す。「有効 (Enabled)」と表示されれば登録できている。
6. 同じ画面で、バックアップキーも別の名前 (例: `yubikey-backup`) で登録する。
7. 2 段階ログインの画面で「リカバリーコードを表示 (View recovery code)」を押し、コードを控える。

登録後の確認:

1. **Web 保管庫のタブは開いたままにする** (失敗したときに設定を直せるようにするため)。
2. 別のブラウザかプライベートウィンドウでログインし、鍵を求められて通ることを確認する。
3. バックアップキーでも同じように確認する。
4. 問題なければ、ほかの端末のアプリを一度ログアウトしてログインし直す
   (ログイン済みのアプリには、次回ログインまで 2 段階ログインが適用されない)。

補足:

- 無料プランでも利用でき、鍵は 5 本まで (Premium は 10 本まで) 登録できる。
- リカバリーコードは 2 段階ログインを解除するためのもので、マスターパスワードの代わりにはならない。
- 鍵に対応していないアプリを使う場合に備えて、認証アプリ (TOTP) を併せて有効にしておくこともできる。

### 2. パスキーでログインできるようにする

マスターパスワードの代わりに、鍵だけでログインする設定。
Web 版と Chromium 系ブラウザ (Chrome、Brave、Vivaldi、Chromium) の拡張機能で使える。

1. Web 保管庫の「設定 (Settings) → セキュリティ (Security) → マスターパスワード (Master password)」を開く。
2. 「パスキーでログイン (Log in with passkey)」の「有効にする (Turn on)」または
   「新しいパスキー (New passkey)」を押し、マスターパスワードを入力する。
3. Bio を挿し、ブラウザの指示に従って PIN の入力または指紋の読み取りを行う。
4. パスキーに名前を付ける。
5. 「保管庫の暗号化に使用 (Use for vault encryption)」が選べる場合はチェックを入れる。
6. 「有効にする (Turn on)」を押す。

「保管庫の暗号化に使用」について:

- チェックできた場合、パスキーだけでログインから保管庫の復号まで完了し、
  マスターパスワードは不要になる。
- 選べない、または登録後に「暗号化非対応」と表示される場合は、パスキーでログインしたあとに
  マスターパスワードの入力が必要になる。
- これには、ブラウザと鍵の両方が PRF という拡張機能に対応している必要がある。
  公式ヘルプが対応例として挙げているのは YubiKey 5 で、Bio については公式の記載を確認できていない
  (コミュニティには Bio で使えたという報告がある)。実際に登録して確かめること。

補足:

- パスキーは YubiKey 内に常駐鍵として保存され、保存枠を 1 つ使う。
  登録したものは `ykman fido credentials list` で確認できる。
- ログイン用のパスキーは 5 個まで登録できる。バックアップキーも登録しておくとよい。
- ログイン画面では「パスキーでログイン (Log in with passkey)」を選ぶ。
- 2 段階ログインの登録とは別物で、同じ鍵を両方に登録できる。

### 3. デスクトップアプリをシステム認証でロック解除する

ロックされた保管庫を、マスターパスワードの代わりに OS の認証で解除する設定。
Linux 版は polkit を使い、polkit は PAM に委譲する。`yubikey.nix` を有効にしていれば
polkit の認証も YubiKey で通るので、Bio の指紋で Bitwarden を解除できる。

前提:

- `hosts/common/yubikey.nix` が有効で、`sudo` を鍵で通せる状態になっている。
- polkit ポリシーが入っている。このリポジトリは Flatpak 版 (`com.bitwarden.desktop`) を使っており、
  Flatpak 版はアプリ側でポリシーを自動セットアップできないため、
  `hosts/common/flatpak.nix` でポリシーをインストールしている。

ポリシーが読み込まれているか確認する:

```bash
pkaction --action-id com.bitwarden.Bitwarden.unlock --verbose
```

アプリ側の設定:

1. デスクトップアプリにマスターパスワード (またはパスキー) でログインする。
2. 「ファイル (File) → 設定 (Settings) → セキュリティ (Security)」を開く。
3. 「システム認証でロック解除 (Unlock with system authentication)」にチェックを入れる。
4. 認証ダイアログが出るので、Bio に指紋を当てる。
5. 「保管庫のタイムアウト時の動作」を「ロック」にする。

確認:

1. `Ctrl + L` で保管庫をロックする。
2. ロック画面の「システム認証でロック解除」を押す。
3. 認証ダイアログで指紋を当て、保管庫が開くことを確認する。

補足:

- アプリを起動した直後の最初の解除にマスターパスワードを求める設定が有効になっていることがある。
  同じ設定画面で切り替えられる。
- チェックを入れてもすぐ外れてしまう場合は、ポリシーが読み込まれていない。
  上の `pkaction` で確認し、`nixos-rebuild switch` 後に再ログインしてから試す。
- 認証ダイアログにパスワード欄だけが出る場合は、鍵を挿した状態でしばらく待つか、
  空のまま Enter を押すと鍵の認証に進む想定 (実機未確認)。
- 鍵が無いときは、認証ダイアログに Linux のパスワードを入力しても解除できる。
  つまり Bitwarden のロックの強さは、Linux のログインパスワードと同じになる。

### 4. ブラウザ拡張のロック解除

拡張機能のロック解除には 2 つの方法がある。

**PIN で解除する (確実)**

1. 拡張機能の「設定 (Settings) → アカウントセキュリティ (Account security)」を開く。
2. 「PIN でロック解除 (Unlock with PIN)」にチェックを入れ、PIN を決める。
3. 「ブラウザ再起動時にマスターパスワードを要求する」は、好みで外す。

**デスクトップアプリ連携で解除する**

デスクトップアプリのシステム認証 (= YubiKey) で拡張機能も解除する方法。

1. デスクトップアプリの「設定 → アプリ設定」で「ブラウザ連携を許可 (Allow browser integration)」に
   チェックを入れる。
2. 拡張機能の「設定 → アカウントセキュリティ」で「生体認証でロック解除 (Unlock with biometrics)」に
   チェックを入れる。
3. デスクトップアプリを起動したままにしておく (連携中は起動している必要がある)。

Flatpak 版でのブラウザ連携は、バージョンによって対応状況が異なり、情報源の間でも食い違いがある。
うまく連携できない場合は PIN での解除を使う。
連携を重視するなら、Flatpak をやめて nixpkgs の `bitwarden-desktop` に切り替える方法もある
(polkit ポリシーとブラウザ連携用のプログラムがパッケージに含まれている)。
その場合はデータの保存場所が変わるため、再ログインが必要になる。

### うまくいかないとき

| 症状 | 確認すること |
| --- | --- |
| Web で鍵を読み取れない | ブラウザが YubiKey を認識しているか。Flatpak 版のブラウザは USB 機器に届かないことがある |
| 2 段階ログインで締め出された | ログイン画面で「リカバリーコードを使用」を選び、2 段階ログインを解除する |
| パスキーでログイン後にパスワードを聞かれる | 「保管庫の暗号化に使用」が有効になっていない (PRF 非対応) |
| システム認証のチェックがすぐ外れる | polkit ポリシーが読み込まれているか (`pkaction` で確認) |
| 認証ダイアログが出ない | polkit エージェントが動いているか (KDE では標準で動いている) |
| YubiKey を初期化した | 2 段階ログインとパスキーの登録が無効になる。古い登録を削除して登録し直す |

## 鍵の入れ替え・削除・紛失時

`/etc/security/u2f_keys` は 1 ユーザー 1 行で、鍵は `:` 区切りで並んでいる。

- **追加**: [鍵を追加する](#鍵を追加する)の手順で追記する。
- **削除**: `sudoedit /etc/security/u2f_keys` で該当する `:<keyHandle>,<publicKey>,...` の
  ブロックを消す。末尾が `+verification` のものが Bio、`+pin` のものがバックアップキー。
- **作り直し**: 手順 A の 1〜3 をやり直して上書きする。
- **紛失した場合**: 残った鍵とパスワードでログインし、紛失した鍵のブロックを削除する。
  あわせて SSH の `authorized_keys`、GitHub、Bitwarden などからも紛失した鍵を外す。

## うまく認証できないときの復旧

ログイン (`login`) は `required` なので、鍵が通らないとログインできない。
ログイン済みであれば、`sudo` と画面ロックは `sufficient` なので鍵を抜いてパスワードで通せる。
状態が分からなくなった場合は[最初からやり直す](#最初からやり直す)を参照。

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

`u2f_keys` が無い・壊れている、鍵を 2 本とも失った、などでログインできない場合。

1. 再起動し、ブートメニューで変更前の世代を選んで起動する。
2. `hosts/<ホスト名>/default.nix` の `../../hosts/common/yubikey.nix` をコメントアウトして
   `sudo nixos-rebuild switch --flake .#<ホスト名>` する。
   `u2f_keys` を直すだけなら、[手順 A](#手順-a-起動済みの環境で有効化する) の 1〜3 で作り直してもよい。

古い世代はガベージコレクションで消えることがある。

以前の世代も使えない場合は、NixOS インストール USB で起動してルートを `/mnt` にマウントし
(手順は各ホストの `docs/install-*.md` を参照)、リポジトリ側でモジュールを無効にして再インストールする。

```bash
nixos-install --flake /mnt/home/kaka/dotfiles-nixos#<ホスト名> --root /mnt
```

## 最初からやり直す

登録や有効化の途中で失敗して状態が分からなくなったときに、まっさらな状態へ戻してやり直す手順。
やり直しの間も、`sudo` は**パスワードで通る** (`sufficient`)。
ログインは鍵が必要 (`required`) なので、**作業が終わるまでログアウトや再起動をしない**こと。

### どこからやり直すか

全部を消す必要があるとは限らない。失敗した場所に応じて、必要なところから戻る。

| 状況 | 戻る場所 | YubiKey の初期化 |
| --- | --- | --- |
| `u2f_keys` の中身がおかしい (改行、origin 違い、`-V` / `-N` の付け忘れ) | [1. システム側を元に戻す](#1-システム側を元に戻す) | 不要 |
| 指紋の読み取りが悪い、登録する指を変えたい | [指紋だけ登録し直す](#指紋だけ登録し直す) | 不要 |
| PIN を変えたい (現在の PIN は分かる) | `ykman fido access change-pin` | 不要 |
| PIN を忘れた、PIN を 8 回間違えてロックされた | [2. YubiKey を初期化する](#2-yubikey-を初期化する) | 必要 |
| 何がどう登録されているか分からない、完全にやり直したい | 1 から順に全部 | 必要 |

### 1. システム側を元に戻す

パスワードで `sudo` できることを先に確認する。

```bash
sudo -k && sudo true
```

先にモジュールを無効に戻す。`hosts/<ホスト名>/default.nix` で読み込みをコメントアウトして反映する。
マッピングファイルを先に消すと、反映するまでの間ログインできなくなるので順番を守る。

```nix
    # ../../hosts/common/yubikey.nix
```

```bash
sudo nixos-rebuild switch --flake .#minipc
```

マッピングファイルを削除する。

```bash
sudo rm /etc/security/u2f_keys
```

作りかけの `u2f_keys` がカレントディレクトリや `/tmp` に残っていれば、それも消す。

これでシステムは YubiKey 導入前の状態 (パスワードのみ) に戻る。
`u2f_keys` の作り直しだけが目的なら、ここから[手順 A](#手順-a-起動済みの環境で有効化する)に進む。

### 2. YubiKey を初期化する

**実行前に必ず確認すること。** FIDO の初期化は取り消せず、その鍵の FIDO 関連データがすべて消える。

- FIDO2 PIN と登録済みの指紋
- PAM 用の資格情報 (`u2f_keys` に登録した内容は無効になる)
- SSH の常駐鍵 (`ed25519-sk`)。ディスク上の `~/.ssh/id_ed25519_sk*` も使えなくなる
- Bitwarden、GitHub などの Web サービスに登録したパスキーと 2 段階認証

Web サービスにその鍵を登録済みの場合は、**初期化の前に**もう 1 本の鍵かリカバリーコードで
ログインできることを確かめておく。2 本を同時に初期化しないこと。

初期化したい鍵**だけ**を挿して実行する。

```bash
nix-shell -p yubikey-manager --run 'ykman fido reset'
```

- 確認に `y` と答えたあと、指示に従って鍵を抜き差しし、LED が点滅したらタッチする。
- 挿し直してから数秒以内にタッチする必要がある。間に合わなかった場合はもう一度実行する。

初期化されたことを確認する (PIN が未設定と表示される)。

```bash
nix-shell -p yubikey-manager --run 'ykman fido info'
```

バックアップキーも初期化する場合は、1 本目の再設定が終わってから同じ手順を行う。

### 3. 鍵に関連する古い情報を片付ける

初期化した鍵を登録していた場所から、古い情報を削除する。

- SSH: 古い鍵ファイル (`~/.ssh/id_ed25519_sk*`) を消し、`hosts/common/user.nix` の
  `openssh.authorizedKeys.keys` と GitHub の SSH keys から該当する公開鍵を外す。
- Bitwarden: 「2 段階ログイン」と「パスキーでログイン」から該当する鍵を削除する。
- そのほか、その鍵を登録していた Web サービスからも削除する。

### 4. 最初から設定し直す

次の順に進める。

1. [YubiKey 本体の準備](#yubikey-本体の準備): PIN の設定、Bio の指紋登録
2. [手順 A](#手順-a-起動済みの環境で有効化する): `u2f_keys` の作成、モジュールの有効化、`test` → 動作確認 → `switch`
3. [SSH で FIDO2 鍵を使う](#ssh-で-fido2-鍵を使う): 必要なら鍵を作り直して公開鍵を登録する
4. [Bitwarden で使う](#bitwarden-で使う): 鍵を登録し直す

### 指紋だけ登録し直す

YubiKey を初期化せずに、指紋だけを入れ替える。PIN の入力が必要。

```bash
ykman fido fingerprints list
```

```bash
ykman fido fingerprints delete <ID>
```

```bash
ykman fido fingerprints add right-index
```

指紋を入れ替えても PAM の登録 (`u2f_keys`) はそのまま使える。

## トラブルシューティング

### ログイン後に KDE ウォレットのパスワードを聞かれる

`login` の `u2f.control` が `sufficient` になっていると起きる (鍵で認証が終わり、パスワードがウォレットに渡らない)。
`hosts/common/yubikey.nix` で `login.u2f.control = "required";` になっているか確認する。
詳しくは [調査ログ](ai-logs/2026-11-18-kwallet-prompt-after-yubikey.md) を参照。

### 鍵を挿しているのに鍵で認証できない

`sudo` で鍵を挿しているのにパスワードを聞かれる、ログインで鍵に応えても通らない場合。

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

## コマンド解説

このページに出てくるコマンドを、道具ごとにまとめて解説する。

### nix-shell (一時的にコマンドを使う)

```bash
nix-shell -p yubikey-manager libfido2 pam_u2f
```

- `nix-shell -p <パッケージ...>`
  - 指定したパッケージが使えるシェルを一時的に起動する。システムにはインストールされず、
    `exit` で抜けると元に戻る。`yubikey.nix` を有効にする前でもコマンドを使うために利用する。
- `yubikey-manager` は `ykman`、`libfido2` は `fido2-token`、`pam_u2f` は `pamu2fcfg` を含む。

```bash
nix-shell -p pam_u2f --run 'pamu2fcfg -u kaka -o pam://dotfiles-nixos -V > u2f_keys'
```

- `--run '<コマンド>'`
  - シェルを起動せず、その環境でコマンドを 1 つだけ実行して終了する。
  - `>` や `>>` も引用符の中に入れているので、リダイレクトまで含めて実行される。

### YubiKey の確認 (lsusb / ykman info / fido2-token)

```bash
lsusb | grep -i yubi
```

- `lsusb` は接続中の USB 機器を一覧表示する。
- `| grep -i yubi` で、大文字小文字を区別せず `yubi` を含む行だけに絞る。
  何も表示されなければ、OS が YubiKey を認識していない。

```bash
ykman info
```

- YubiKey の機種、ファームウェアのバージョン、シリアル番号、有効な機能 (FIDO2、U2F など) を表示する。

```bash
ykman fido info
```

- FIDO 機能の状態を表示する。PIN が設定済みか、PIN の残り試行回数、指紋の登録状況などが分かる。

```bash
fido2-token -L
```

- 接続中の FIDO2 デバイスを一覧表示する (`-L` は list)。
  `/dev/hidraw*` のパスと機種名が出れば、FIDO2 デバイスとしてアクセスできている。

### PIN と指紋の管理 (ykman fido)

```bash
ykman fido access change-pin
```

- FIDO2 PIN を設定または変更する。未設定なら新しい PIN を、設定済みなら現在の PIN と新しい PIN を聞かれる。
- PIN は YubiKey 本体に保存され、PC 側には残らない。

```bash
ykman fido fingerprints add right-index
```

- Bio に指紋を登録する。`right-index` は自分で付ける名前で、どの指か分かるものにする。
- PIN を入力したあと、同じ指を数回センサーに当てて読み取らせる。

```bash
ykman fido fingerprints list
```

- 登録済みの指紋を、ID と名前の一覧で表示する。PIN の入力が必要。
- PIN を使う操作なので、指紋認証のブロックを解除する目的でも使える。

```bash
ykman fido fingerprints delete <ID>
```

- 指定した指紋を削除する。`<ID>` は `list` で表示されたものを指定する。

### YubiKey 内の資格情報の管理 (ykman fido)

```bash
ykman fido credentials list
```

- YubiKey 内に保存されている常駐鍵 (パスキー、SSH の常駐鍵など) を一覧表示する。PIN の入力が必要。
- `pamu2fcfg` で登録した PAM 用の資格情報は常駐鍵ではないため、ここには表示されない。

```bash
ykman fido credentials delete <credential-id>
```

- 指定した常駐鍵を YubiKey から削除する。`<credential-id>` は `list` で表示されたものを指定する。

```bash
ykman fido reset
```

- FIDO 機能を工場出荷状態に戻す。PIN、指紋、すべての資格情報が消え、取り消せない。
- 誤操作防止のため、実行後に鍵を抜き差しし、数秒以内にタッチする必要がある。
- 詳細は[最初からやり直す](#最初からやり直す)を参照。

### マッピングの生成 (pamu2fcfg)

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

```bash
pamu2fcfg -n -o pam://dotfiles-nixos -N >> u2f_keys
```

- `-n`
  - ユーザー名を付けず、`:<keyHandle>,<publicKey>,...` の形で出力する。既存の行の後ろにつなげるために使う。
- `-N`
  - 認証時に FIDO2 PIN を必須にする。出力の末尾に `+pin` が付く。指紋センサーの無い鍵で使う。
- `>> u2f_keys`
  - 出力をファイルの末尾に追記する。`>` にすると上書きされ、先に登録した鍵が消える。

```bash
pamu2fcfg -n -o pam://dotfiles-nixos -N | sudo tee -a /etc/security/u2f_keys > /dev/null
```

- `| sudo tee -a <ファイル>`
  - `pamu2fcfg` の出力を root 権限でファイルに追記する (`-a` は append)。
  - `sudo pamu2fcfg ... >> /etc/security/u2f_keys` と書くと、リダイレクトは一般ユーザーの権限で
    行われるため失敗する。そのため `tee` を `sudo` で実行する。
- `> /dev/null`
  - `tee` は受け取った内容を画面にも出力するので、それを捨てる。

オプション一覧:

| オプション | 意味 |
| --- | --- |
| `-u`, `--username` | 行の先頭に付けるユーザー名 |
| `-o`, `--origin` | origin (識別子)。PAM 側の設定と一致させる |
| `-n`, `--nouser` | ユーザー名を付けずに出力する。既存の行へ鍵を追記するときに使う |
| `-N`, `--pin-verification` | 認証時に FIDO2 PIN を必須にする。指紋センサーの無い鍵で使う |
| `-V`, `--user-verification` | 認証時にユーザー検証 (指紋など) を必須にする |
| `-P`, `--no-user-presence` | タッチ不要の鍵として登録する (非推奨) |
| `-r`, `--resident` | 常駐鍵として登録する |

期待される形式のサンプルは `hosts/common/yubikey/u2f_keys.example` を参照。

### マッピングファイルの配置と確認 (install / cat / rm / chmod)

```bash
sudo install -Dm600 -o root -g root u2f_keys /etc/security/u2f_keys
```

- `install` は、コピーと同時に権限と所有者を設定するコマンド。
- `-D`
  - コピー先のディレクトリ (`/etc/security`) が無ければ作成する。
- `-m600`
  - 権限を `600` (所有者だけが読み書きできる) にする。
- `-o root -g root`
  - 所有者とグループを `root` にする。
- インストール中の手順ではコピー先が `/mnt/etc/security/u2f_keys` になる。
  ライブ環境ではすでに root なので `sudo` は付けない。

```bash
cat u2f_keys
```

```bash
sudo cat /etc/security/u2f_keys
```

- ファイルの内容を表示する。配置後のファイルは root しか読めないので `sudo` が必要。

```bash
rm u2f_keys
```

```bash
sudo rm /etc/security/u2f_keys
```

- ファイルを削除する。前者は作業用のファイル、後者は配置済みのマッピングファイルを消す。
  後者を消すと、`sudo` などはパスワードだけになり、**ログインはできなくなる** (`login` が `required` のため)。
  消す前にモジュールを無効にしておくこと。

```bash
sudo chmod 644 /etc/security/u2f_keys
```

- 権限を `644` (所有者は読み書き、ほかのユーザーは読み取りのみ) に変える。
  ユーザー権限で動く画面ロックからファイルを読めるようにするために使う。

### 認証の確認 (sudo)

```bash
sudo -k && sudo true
```

- `sudo -k`
  - sudo の認証キャッシュを破棄する。直前に `sudo` を使っていても、次回は必ず認証を求められる。
- `&&`
  - 前のコマンドが成功したら次のコマンドを実行する。
- `sudo true`
  - 何もしないコマンド `true` を root 権限で実行する。認証が通るかどうかだけを確かめられる。

`sudoedit /etc/security/u2f_keys` は、root 権限が必要なファイルを自分のエディタで安全に編集するコマンド。
一時コピーを編集し、保存時に元のファイルへ書き戻す。

### 設定の反映 (nixos-rebuild / nixos-install)

```bash
sudo nixos-rebuild test --flake .#minipc
```

- `test`
  - 設定をビルドして現在のシステムに反映するが、ブートエントリには登録しない。
    再起動すると反映前の設定に戻るので、試すのに向いている。
- `--flake .#minipc`
  - カレントディレクトリの flake にある `minipc` の構成を使う。ホストに合わせて `vbox` などに読み替える。

```bash
sudo nixos-rebuild switch --flake .#minipc
```

- `switch`
  - 設定を反映し、次回以降の起動でも使われるようにブートエントリに登録する。

```bash
nixos-install --flake /mnt/home/kaka/dotfiles-nixos#<ホスト名> --root /mnt
```

- ライブ USB から、`/mnt` にマウントしたシステムへ NixOS をインストール (または再インストール) する。
- `--root /mnt`
  - インストール先のルートディレクトリを指定する。

### SSH 鍵 (ssh-keygen)

```bash
ssh-keygen -t ed25519-sk -O resident -O verify-required -O application=ssh:kaka -C "kaka@yubikey-bio"
```

- YubiKey を使う SSH 鍵を作成する。各オプションの意味は
  [SSH で FIDO2 鍵を使う](#ssh-で-fido2-鍵を使う)の表を参照。

```bash
cd ~/.ssh && ssh-keygen -K
```

- `cd ~/.ssh`
  - 鍵ファイルの置き場所に移動する。`ssh-keygen -K` はカレントディレクトリに書き出すため。
- `ssh-keygen -K`
  - YubiKey 内の常駐鍵を読み出し、`id_ed25519_sk_rk_*` という鍵ファイルとして保存する。PIN の入力が必要。

### セッションの操作 (loginctl)

```bash
loginctl list-sessions
```

- ログイン中のセッションを一覧表示する。左端の番号がセッション ID。
  ロックされたデスクトップのセッションは、`seat0` に属しているものを探す。

```bash
loginctl unlock-session <セッション ID>
```

- 指定したセッションの画面ロックを解除する。TTY からデスクトップのロックを外すときに使う。

### ログとサービス (journalctl / systemctl)

```bash
journalctl -b | grep -i u2f
```

- `journalctl -b`
  - 今回の起動以降のシステムログを表示する。
- `| grep -i u2f`
  - `u2f` を含む行だけに絞る。`debug = true;` を設定していると、`pam_u2f` の詳細なログが出る。

```bash
systemctl status pcscd.socket
```

- `pcscd` (スマートカード用のサービス) の待ち受け状態を表示する。`ykman` の一部の機能が利用する。

```bash
sudo systemctl restart pcscd
```

- `pcscd` を再起動する。`ykman` が YubiKey を見つけられないときに試す。

### polkit の確認 (pkaction)

```bash
pkaction --action-id com.bitwarden.Bitwarden.unlock --verbose
```

- `pkaction` は polkit に登録されているアクション (認証が必要な操作の定義) を表示する。
- `--action-id <ID>`
  - 指定したアクションだけを表示する。登録されていなければエラーになる。
- `--verbose`
  - 説明文や、誰に認証を求めるか (`auth_self` は実行したユーザー自身) まで表示する。

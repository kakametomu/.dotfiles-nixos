# YubiKey 有効化後に KDE ウォレットのパスワードを聞かれる問題の調査メモ

YubiKey によるログイン(`hosts/common/yubikey.nix`)を有効にしてから、SDDM でログインした後に
KDE ウォレットのパスワード入力を求められるようになった。その原因調査と、対処方針を決めた記録。

## 症状

- 起動後、SDDM でパスワードを入力してログインしている。
- それでもログイン後に KDE ウォレットのパスワードを求められる。
- YubiKey を有効化する前は発生していなかった。

## 原因

PAM の認証順序の問題。YubiKey(`pam_u2f`)で認証が通った時点で認証処理が打ち切られ、
入力したパスワードが `pam_kwallet5` に渡らない。

### SDDM の PAM スタック

SDDM 自身の `sddm` サービスは `auth substack login` で処理を `login` サービスに委譲している
(nixpkgs `nixos/modules/services/display-managers/sddm.nix`)。
Plasma 6 は `login` に `kwallet` を有効化している(`nixos/modules/services/desktop-managers/plasma6.nix`)。

nixpkgs(`nixos/modules/security/pam.nix`)が組み立てる `login` の auth ルールは次の順になる。

| 順 | モジュール | control | 役割 |
|---|---|---|---|
| 1 | `pam_u2f` | `sufficient` | YubiKey 認証(`yubikey.nix` の `login.u2f.control`) |
| 2 | `pam_unix`(unix-early) | `optional` | パスワードを受け取る |
| 3 | `pam_kwallet5` | `optional` | パスワードを控え、セッション開始時にウォレットを解錠する |
| 4 | `pam_unix` | `sufficient` | パスワードを照合する |

`sufficient` は成功するとそこで認証を終える。鍵を挿したままログインすると 1 で通ってしまい、
2〜4 が実行されない。`pam_kwallet5` はパスワードを受け取れず、ウォレットが開かないまま残る。

YubiKey 導入前は 1 が無く、パスワードが常に 3 まで届いていたため問題にならなかった。

### 切り分け方法(実機)

鍵を抜いた状態で再起動し、パスワードでログインする。ウォレットのパスワードを聞かれなければこの原因で確定。

## 対処案の比較

ウォレットはログインパスワードで暗号化されているため、鍵だけでログインした場合に自動解錠する方法は無い。

| 案 | 起動時のログイン | ウォレット | 鍵が無いとき |
|---|---|---|---|
| `login` の U2F を無効化 | パスワードのみ | 自動で開く | パスワードで入れる |
| `login` を `required` にする | パスワード + 鍵 | 自動で開く | ログインできない |
| ウォレットのパスワードを空にする | 鍵のみ可 | 自動で開く | パスワードで入れる(ウォレットは平文保存) |
| 現状維持(起動時は鍵を抜く運用) | 鍵のみ可 | 鍵を挿したままだと開かない | パスワードで入れる |

### `required` にした場合の挙動

`required` は成功しても認証を打ち切らず、次のルールへ進む。失敗した場合も最後まで進んだうえで全体を失敗にする。

- 鍵とパスワードの両方が通ったときだけログインできる。
- パスワードが必ず `pam_kwallet5` に届くので、ウォレットは自動で開く。
- SDDM ではパスワードを入力して Enter、続けて鍵に指紋(Bio)または PIN + タッチ(バックアップキー)で応える。
  パスワード欄を空のまま Enter で済ませる使い方はできなくなる。
- sudo と画面ロック(`kde`)は `sufficient` のままなので、鍵だけで通る。
  画面ロック解除時はウォレットが開いたままなので影響はない。

## 決定

`login` を `required` にする(パスワード + 鍵の 2 要素でログイン)。

### 判断材料(ユーザーの前提条件)

- YubiKey は 2 本(Bio + バックアップ)ある。
- OS の設定は GitHub にある。
- データは Google Drive と Nextcloud にある。
- パスワードはクラウド型のパスワードマネージャーで管理している。

### 検討した注意点と結論

| 注意点 | 内容 | 結論 |
|---|---|---|
| 鍵 2 本を同時に失う | パスワードマネージャーや GitHub などにも同じ鍵を使っていると連鎖的に締め出される | 各サービスに認証アプリでのログイン経路を残しているので問題なし |
| vbox への影響 | vbox も `hosts/common` を読み込むため、`required` にすると VM で鍵が必要になる | vbox は検証用でセキュリティは不要。vbox では YubiKey を設定しない方針 |
| 再インストール時の `u2f_keys` | `/etc/security/u2f_keys` はリポジトリ管理外。作り忘れると SDDM / TTY ともにログインできない | 許容できるリスク。インストール手順に必須と明記する |
| ディスク暗号化 | LUKS が無いため、ライブ USB から起動すればディスクは読める。`required` で守れるのはログイン画面だけ | 現時点で暗号化は不要。ライブ USB から設定を直せる逃げ道にもなる |
| TTY / root | TTY も `login` を使うので鍵が必要。root は `u2f_keys` に無いため TTY からログイン不可 | 緊急モードは `sulogin` で PAM の `login` を通らないため、root パスワードで入れる |
| 古い世代 | 起動メニューの古い世代は逃げ道になるが、GC で消えると使えない | 留意事項 |
| FIDO PIN | 8 回間違えるとロックされ、初期化と再登録が必要 | 留意事項 |

## 今後の作業

1. [x] `login.u2f.control` を `required` にする(main / minipc)。
2. [x] vbox では YubiKey の設定(`yubikey.nix`)を読み込まないようにする。
   `hosts/common/default.nix` から外し、`hosts/main/default.nix` と `hosts/minipc/default.nix` で読み込む形にした。
3. [x] `docs/yubikey.md` に今回の構成(ログインはパスワード + 鍵、sudo と画面ロックは鍵のみ)を反映する。
4. [x] `docs/install-main.md` と `docs/install-minipc.md` に、初回起動前の `u2f_keys` 配置を必須ステップとして明記する。
   `docs/install-vbox.md` からは YubiKey の手順を削除した。
5. [ ] 実機(minipc)で下記の確認手順を行う。

### 評価結果(実機適用前)

`nix eval` で生成される PAM 設定を確認した。

- minipc の `login`: `pam_u2f` が `required` になり、その後ろに `pam_unix`(unix-early)→ `pam_kwallet5` → `pam_unix` が続く。
- minipc の `sudo` / `kde`: `pam_u2f` は `sufficient` のまま。
- minipc の `sddm`: `auth substack login` のまま(上記の `login` が効く)。
- vbox: `login` / `sudo` / `kde` のいずれにも `pam_u2f` が無い。

### 適用時の確認手順

`switch` ではなく `test` で適用し、起動メニューの既定を変えずに確認する(再起動すれば元に戻る)。

```bash
sudo nixos-rebuild test --flake .#minipc
```

デスクトップにログインしたまま、TTY(Ctrl+Alt+F3)で次を確認する。

- Bio + パスワードでログインできる
- バックアップキー(PIN + タッチ)+ パスワードでログインできる
- 鍵なしではログインできない

確認後に `switch` で確定し、再起動して SDDM からログインし、ウォレットのパスワードを聞かれないことを確かめる。

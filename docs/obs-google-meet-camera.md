# OBS / Google Meet カメラ構成

MiniPC の FHD Camera を OBS の仮想カメラ経由で Google Meet に渡すための構成メモ。

## なぜブリッジが必要か

このカメラは `/dev/video2` として見えるが、V4L2 から直接読み出すと黒フレームになったり、対応フレームレートを誤認したりすることがある。Chrome、Google Meet、OBS からカメラを直接開くとこの問題の影響を受ける。

そこで、ffmpeg でカメラの MJPEG 映像を読み出し、30fps の YUYV 映像に変換して v4l2loopback に書き込む。アプリケーションからは、安定した仮想デバイスとして見える。

## 映像の流れ

```text
FHD Camera (/dev/video2)
  ↓ MJPEG, 1280x720, 30fps
ffmpeg の低遅延変換
  ↓ YUYV
FHD Camera (Virtual) (/dev/video0)
  ↓ OBS の「meet用」ソース
OBS Virtual Camera (/dev/video10)
  ↓ Google Meet
```

`/dev/video0` と `/dev/video10` は v4l2loopback が作る仮想デバイスである。`/dev/video0` は物理カメラの安定化用、`/dev/video10` は OBS が Meet に出力するために使う。

## NixOS に含まれる設定

設定は [hosts/minipc/default.nix](../hosts/minipc/default.nix) にある。

- `v4l2loopback` を `/dev/video0` と `/dev/video10` の2台として作成する
- `/dev/video0` を `FHD Camera (Virtual)`、`/dev/video10` を `OBS Virtual Camera` として登録する
- ffmpeg で `/dev/video2` を 1280x720、30fps、MJPEG 入力として読む
- `nobuffer`、`low_delay`、小さいキューを使い、遅延とフレームの滞留を抑える
- 出力を YUYV に変換し、`/dev/video0` へ書き込む
- サービスは自動起動しない。カメラを使うときだけ手動で起動する

自動起動にしない理由は、OBS と Meet を閉じてもブリッジがカメラを掴み続ける状態を避けるためである。必要なときだけ起動すれば、カメラの使用状態も分かりやすい。

## 初回または設定変更後

リポジトリの変更をシステムへ反映する。

```bash
cd ~/dotfiles-nixos
sudo nixos-rebuild switch --flake .#minipc
```

`sudo` のパスワード入力が必要なため、これは通常の端末から実行する。

## 使用開始

```bash
systemctl --user start camera-pipewire-bridge
```

その後、次の順番で確認する。

1. OBS を起動する
2. シーン「meet用」の映像が表示されることを確認する
3. OBS の「仮想カメラ開始」を押す
4. Google Meet を開く。カメラ一覧に出ない場合は Meet をリロードする
5. カメラとして「OBS Virtual Camera」を選択する

OBS の「meet用」ソースは `/dev/video0` を入力にする。Meet が選ぶのは OBS が出力する `/dev/video10` である。

## 使用終了

まず OBS の仮想カメラを停止して OBS を閉じ、その後ブリッジを停止する。

```bash
systemctl --user stop camera-pipewire-bridge
```

ブリッジを停止しない限り、OBS や Meet を閉じても ffmpeg が物理カメラを使用し続ける。現在一時的に起動している旧テスト用サービスが残っている場合は、次も停止する。

```bash
systemctl --user stop camera-v4l2-ffmpeg-bridge
```

## 状態確認

```bash
systemctl --user status camera-pipewire-bridge
v4l2-ctl --list-devices
v4l2-ctl -d /dev/video0 --get-parm
```

サービスが `active (running)` で、`/dev/video0` が 30fps になっていれば、ブリッジは動作している。映像が黒い場合は、まずブリッジを再起動してから OBS の映像を確認する。

```bash
systemctl --user restart camera-pipewire-bridge
```


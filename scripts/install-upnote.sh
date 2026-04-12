#!/usr/bin/env bash
# UpNoteのAppImageをインストール

set -e

INSTALL_DIR="$HOME/.local/bin"
APPIMAGE_PATH="$INSTALL_DIR/UpNote.AppImage"
DESKTOP_FILE="$HOME/.local/share/applications/upnote.desktop"
DOWNLOAD_URL="https://download.getupnote.com/app/UpNote.AppImage"

mkdir -p "$INSTALL_DIR"
mkdir -p "$HOME/.local/share/applications"

echo "UpNote AppImage をダウンロード中..."
curl -L "$DOWNLOAD_URL" -o "$APPIMAGE_PATH"
chmod +x "$APPIMAGE_PATH"

echo ".desktop ファイルを作成中..."
cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Name=UpNote
Exec=appimage-run $APPIMAGE_PATH
Icon=upnote
Type=Application
Categories=Office;TextEditor;
EOF

echo "インストール完了: $APPIMAGE_PATH"
echo "アプリメニューから UpNote を起動できます"
echo ""
echo "注意: appimage-run が必要です。未インストールの場合は NixOS 設定に追加してください。"

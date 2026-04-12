-- Pull in the wezterm API
local wezterm = require("wezterm")

-- This will hold the configuration.
local config = wezterm.config_builder()

-- leader設定・同時押しでは反応しない個別押しにする必要がある
config.leader = { key = 'Space', mods = 'CTRL', timeout_milliseconds = 2000 }

-- キーバインド設定を外部ファイルから読み込み
config.keys = require("config.keybinds").keys

-- カラースキーム設定(https://wezterm.org/colorschemes/index.html)
-- config.color_scheme = "Solarized (dark) (terminal.sexy)"
-- config.color_scheme = 'Catppuccin Frappe'
config.color_scheme = 'nord'

-- 透明度設定
config.window_background_opacity = 0.95
-- テキスト背景の透明度設定（デフォルトは1.0）
config.text_background_opacity = 0.85

-- ウィンドウ装飾の設定（タイトルバーのみ非表示）
config.window_decorations = "RESIZE"

-- タブが1つだけのときにタブバーを非表示にする設定
config.hide_tab_bar_if_only_one_tab = false

config.font = wezterm.font_with_fallback({
	-- "JetBrains Mono",
	-- "Hack Nerd Font",
    "CaskaydiaMono Nerd Font"
})

-- フォントサイズを指定
config.font_size = 12.0

return config
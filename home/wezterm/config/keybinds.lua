local wezterm = require 'wezterm'
local act = wezterm.action

return {
  keys = {
    -- 水平分割 (上下に分割): LEADER + -
    { key = '-', mods = 'LEADER', action = act.SplitVertical { domain = 'CurrentPaneDomain' } },
    -- 垂直分割 (左右に分割): LEADER + | (Shift + \)
    { key = '\\', mods = 'LEADER', action = act.SplitHorizontal { domain = 'CurrentPaneDomain' } },

    -- ペインの移動 (h, j, k, l は Vim の操作に対応)
    -- 左へ移動: LEADER + h
    { key = 'h', mods = 'LEADER', action = act.ActivatePaneDirection 'Left' },
    -- 下へ移動: LEADER + j
    { key = 'j', mods = 'LEADER', action = act.ActivatePaneDirection 'Down' },
    -- 上へ移動: LEADER + k
    { key = 'k', mods = 'LEADER', action = act.ActivatePaneDirection 'Up' },
    -- 右へ移動: LEADER + l
    { key = 'l', mods = 'LEADER', action = act.ActivatePaneDirection 'Right' },

    -- 現在のペインを閉じる: LEADER + x
    { key = 'x', mods = 'LEADER', action = act.CloseCurrentPane { confirm = true } },

    -- 新しいタブを開く: LEADER + t
    { key = 't', mods = 'LEADER', action = act.SpawnTab 'CurrentPaneDomain' },
    -- タブを閉じる: LEADER + w
    { key = 'w', mods = 'LEADER', action = act.CloseCurrentTab { confirm = true } },
  },
}
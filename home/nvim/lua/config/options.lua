-- オプションは lazy.nvim の起動前に自動的に読み込まれます
-- 常に設定されるデフォルトオプション: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- 追加オプションはここに記述してください

-- 以下オプションをは下記記事を参照した
-- https://zenn.dev/kawarimidoll/books/6064bf6f193b51/viewer/efdd0c

-- クリップボード同期
-- vim.opt.clipboard:append('unnamedplus,unnamed')

vim.opt.number = true
vim.opt.cursorline = true

-- インデントをスペース2つにする
vim.opt.expandtab = true
vim.opt.shiftround = true
vim.opt.shiftwidth = 2
vim.opt.softtabstop = 2
vim.opt.tabstop = 2
-- カーソルが画面端に達する3行手前でスクロールを行う設定
vim.opt.scrolloff = 3

-- サインカラムを常に固定して表示させる
vim.opt.signcolumn = "yes"

-- ウィンドウの枠線設定
vim.opt.winborder = 'rounded'
-- 以下は、hとlで行の端に到達したとき、行端を越えて次の行へ移動する設定です。
vim.opt.whichwrap = 'b,s,h,l,<,>,[,],~'

-- init.luaを開くIniLua関数を定義
vim.api.nvim_create_user_command(
    'InitLua',
    function()
        vim.cmd.edit(vim.fn.stdpath('config') .. '/init.lua')
    end,
    { desc = 'Open init.lua' }
)

-- この設定ファイル用のaugroup
local augroup = vim.api.nvim_create_augroup('init.lua', {})
-- 内部augroupを使用するためのラッパー関数
local function create_autocmd(event, opts)
    vim.api.nvim_create_autocmd(event, vim.tbl_extend('force', {
        group = augroup,
    }, opts))
end
-- https://vim-jp.org/vim-users-jp/2011/02/20/Hack-202.html
create_autocmd('BufWritePre', {
    pattern = '*',
    callback = function(event)
        local dir = vim.fs.dirname(event.file)
        local force = vim.v.cmdbang == 1
        if vim.fn.isdirectory(dir) == 0
            and (force or vim.fn.confirm('"' .. dir .. '" does not exist. Create?', "&Yes\n&No") == 1) then
            vim.fn.mkdir(vim.fn.iconv(dir, vim.opt.encoding:get(), vim.opt.termencoding:get()), 'p')
        end
    end,
    -- desc = "ファイル保存用の自動ディレクトリ作成"
    desc = 'Auto mkdir to save file'
})

-- abbreviation only for ex-command
-- 元のコマンドのみに適用される略称
local function abbrev_excmd(lhs, rhs, opts)
    vim.keymap.set('ca', lhs, function()
        return vim.fn.getcmdtype() == ':' and rhs or lhs
    end, vim.tbl_extend('force', { expr = true }, opts))
end

-- qwが自動でwqに直される
abbrev_excmd('qw', 'wq', { desc = 'fix typo' })

-- lua関数の出力を表示する際にはlua =というコマンドを使うのですが、
-- =がホームポジションから遠くて入力しづらいと感じる場合、より入力しやすい文字列、
-- 一例としてlupを短縮入力に設定することで、lupでlua =を代用できます（lua printのイメージ）。
-- abbrev_excmd('lup', 'lua =', { desc = 'lua print' })

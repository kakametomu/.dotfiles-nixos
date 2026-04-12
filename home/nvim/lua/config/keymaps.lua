-- キーマップは VeryLazy イベントで自動的に読み込まれます
-- 常に設定されるデフォルトのキーマップ: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- 追加のキーマップはここに記述してください

-- keymap設定

-- ペースト時にカーソルがペースト範囲の末尾へ移動するようになります
vim.keymap.set('n', 'p', 'p`]', { desc = 'Paste and move to the end' })
vim.keymap.set('n', 'P', 'P`]', { desc = 'Paste and move to the end' })

-- ビジュアルモードのペースト機能はpでペーストするとレジスタがペースト範囲に置き換わり、Pではこれが発生しません。
-- 以下のように設定すると、この挙動を入れ替えることができます。
vim.keymap.set('x', 'p', 'P', { desc = 'Paste without change register' })
vim.keymap.set('x', 'P', 'p', { desc = 'Paste with change register' })

-- デフォルトではdでカットすると無名レジスタに値を保存するため、直前にコピーしていた値を上書きしてしまいします。
-- そこで、_（ブラックホールレジスタ：ここに入れられた値は読み出すことはできず捨てられる）を使用するアイデアがあります。
-- 以下のように指定すると、xをレジスタの値を変えない削除オペレータとして使うことができます。
vim.keymap.set({ 'n', 'x' }, 'x', '"_d', { desc = 'Delete using blackhole register' })
vim.keymap.set('n', 'X', '"_D', { desc = 'Delete using blackhole register' })
vim.keymap.set('o', 'x', 'd', { desc = 'Delete using x' })

-- コマンドラインモードでemacs風のキーバインドを使ってコマンドを編集できるようになります。
vim.keymap.set('c', '<c-b>', '<left>', { desc = 'Emacs like left' })
vim.keymap.set('c', '<c-f>', '<right>', { desc = 'Emacs like right' })
vim.keymap.set('c', '<c-a>', '<home>', { desc = 'Emacs like home' })
vim.keymap.set('c', '<c-e>', '<end>', { desc = 'Emacs like end' })
vim.keymap.set('c', '<c-h>', '<bs>', { desc = 'Emacs like bs' })
vim.keymap.set('c', '<c-d>', '<del>', { desc = 'Emacs like del' })

-- <space>;のキーコンビネーションで直前のコマンドを再実行することができるようになります。
vim.keymap.set('n', '<space>;', '@:', { desc = 'Re-run the last command' })

-- <space>wのキーコンビネーションで保存を実行することができる。
vim.keymap.set('n', '<space>w', '<cmd>write<cr>', { desc = 'Write' })

-- soのキーコンビネーションで現在開いている.luaのファイルを読み込みます。
-- 範囲選択した状態で使うと、選択された範囲のみを読み込みます。
-- oilにキーマップ
vim.keymap.set({ 'n', 'x' }, 'so', ':source<cr>', { silent = true, desc = 'Source current script' })

-- <space>eで:Exのキーマップ LazyVimとの競合のためオフ
-- vim.keymap.set('n', '<space>e', '<cmd>Ex<cr>', { silent = true, desc = 'Source current script' })
vim.keymap.set("n", "<space>e", "<CMD>Oil<CR>", { desc = "Open parent directory" })
-- jjでEscのキーマップ
vim.keymap.set('i', 'jj', '<Esc>', { silent = true, desc = 'Source current script' })
-- システムクリップボードにコピー
vim.keymap.set({ 'n', 'v' }, '<leader>y', '"+y')
-- システムクリップボードに切り取り
vim.keymap.set({ 'n', 'v' }, '<leader>d', '"+d')

-- コマンドラインモードで補完中かどうかでキーを自動で切り替えるキーマップです。
-- <c-p>と<up>はどちらも過去のコマンド履歴を呼び出す機能がありますが、
-- 挙動が微妙に異なるので、このようにマッピングすると使いやすくなります。
vim.keymap.set('c', '<c-n>', function()
    return vim.fn.wildmenumode() == 1 and '<c-n>' or '<down>'
end, { expr = true, desc = 'Select next' })
vim.keymap.set('c', '<c-p>', function()
    return vim.fn.wildmenumode() == 1 and '<c-p>' or '<up>'
end, { expr = true, desc = 'Select previous' })

-- <space>qのキーコンビネーションでウィンドウを閉じることができるようになります。
-- ただし、開いているタブがあればそれを閉じます
vim.keymap.set('n', '<space>q', function()
    if not pcall(vim.cmd.tabclose) then
        vim.cmd.quit()
    end
end, { desc = 'Quit current tab or window' })

-- 「終了コマンドの:qを間違えてq:と打ってしまうとコマンドラインウィンドウが開いてしまう」と説明しましたが、以下の設定で無効化できます。
vim.keymap.set('n', 'q:', '<nop>', { desc = 'Disable cmdwin' })

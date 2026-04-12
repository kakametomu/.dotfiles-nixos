return {
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
    config = function()
      require("catppuccin").setup {
        transparent_background = true, -- ここで透過を有効にする
      }
      -- カラースキームを適用
      vim.cmd.colorscheme "catppuccin"
    end,
  },
}

-- return {
--   {
--     "craftzdog/solarized-osaka.nvim",
--     lazy = false,
--     priority = 1000,
--     config = function()
--       require("solarized-osaka").setup {
--         transparent = true, -- ここで透過を有効にする
--       },
--       vim.cmd.colorscheme 'solarized-osaka'
--     end,
--   },
-- }

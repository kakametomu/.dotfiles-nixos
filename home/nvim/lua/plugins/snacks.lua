return {
  {
    "folke/snacks.nvim",
    priority = 1000,
    lazy = false,
    ---@type snacks.Config
    opts = {
      bigfile = { enabled = true },
      dashboard = { enabled = true },
      indent = { enabled = true },
      input = { enabled = true },
      notifier = { enabled = true },
      picker = { enabled = true },
      quickfile = { enabled = true },
      scroll = { enabled = true },
      statuscolumn = { enabled = true },
      words = { enabled = true },
    },
    keys = {
      { "<leader>sg", function() Snacks.picker.grep() end, desc = "Grep (Project)" },
      { "<leader>sw", mode = { "n", "x" }, function() Snacks.picker.grep_word() end, desc = "Grep Word Under Cursor" },
    },
  },
}

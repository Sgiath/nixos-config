require "nvchad.mappings"

map("n", "<leader>fm", function()
  require("conform").format()
end, { desc = "File Format with conform" })

-- Obsidian notes
map("n", "<leader>fn", ":ObsidianQuickSwitch<CR>", { desc = "Search Obsidian" })

local map = vim.keymap.set

map("n", ";", ":", { desc = "CMD enter command mode" })
map("v", ";", ":", { desc = "CMD enter command mode" })

map("i", "jk", "<ESC>", { desc = "Escape insert mode" })

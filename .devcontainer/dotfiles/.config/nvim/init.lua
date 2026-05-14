local is_container = vim.fn.filereadable("/.dockerenv") == 1

-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

-- Make sure to setup `mapleader` and `maplocalleader` before
-- loading lazy.nvim so that mappings are correct.
-- This is also a good place to setup other settings (vim.opt)
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- Setup lazy.nvim
require("lazy").setup({
  spec = {
    {
      "akinsho/toggleterm.nvim",
      cond = not vim.g.vscode,
      keys = {
        { "<C-t>", "<cmd>ToggleTerm<cr>", mode = { "n", "t" } },
      },
      opts = {
        open_mapping = [[<C-t>]],
        direction = "float",
      },
    },
    {
      "nvim-neo-tree/neo-tree.nvim",
      cond = not vim.g.vscode,
      dependencies = {
        "nvim-lua/plenary.nvim",
        "nvim-tree/nvim-web-devicons",
        "MunifTanjim/nui.nvim",
      },
      keys = {
        { "<leader>e", "<cmd>Neotree toggle<cr>" },
      },
      opts = {
        filesystem = {
          filtered_items = {
            visible = true,
            hide_dotfiles = false,
            hide_gitignored = false,
          },
        },
      },
    },
    {
      "nvim-telescope/telescope.nvim",
      cond = not vim.g.vscode,
      dependencies = { "nvim-lua/plenary.nvim" },
      keys = {
        { "<leader>ff", "<cmd>Telescope find_files<cr>" },
        { "<leader>fg", "<cmd>Telescope live_grep<cr>" },
        { "<leader>fb", "<cmd>Telescope buffers<cr>" },
        { "<leader>fh", "<cmd>Telescope help_tags<cr>" },
      },
    },
    {
      "neovim-treesitter/nvim-treesitter",
      cond = not vim.g.vscode,
      build = ":TSUpdate",
      dependencies = { "neovim-treesitter/treesitter-parser-registry" },
      opts = {
        ensure_installed = { "markdown", "markdown_inline" },
        highlight = { enable = true },
      },
      config = function(_, opts)
        require("nvim-treesitter").setup(opts)
      end,
    },
    {
      "MeanderingProgrammer/render-markdown.nvim",
      cond = not vim.g.vscode,
      dependencies = { "neovim-treesitter/nvim-treesitter", "nvim-tree/nvim-web-devicons" },
      ft = { "markdown" },
      opts = {},
    },
    {
      "iamcco/markdown-preview.nvim",
      cond = not vim.g.vscode and not is_container,
      build = "cd app && npm install",
      ft = { "markdown" },
      keys = {
        { "<leader>mp", "<cmd>MarkdownPreviewToggle<cr>", desc = "Markdown Preview" },
      },
    },
  },
  -- Configure any other settings here. See the documentation for more details.
  -- colorscheme that will be used when installing plugins.
  install = { colorscheme = { "habamax" } },
  -- automatically check for plugin updates
  checker = { enabled = true },
})

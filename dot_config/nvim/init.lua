-- Managed by chezmoi. Ported from the nixvim config in the nixos flake:
-- catppuccin + lualine + treesitter, and nothing else. Kept deliberately small
-- -- it exists so nwa and mca share an editor without nix-darwin, and it is
-- meant to be cheap to throw away if this becomes a helix config.

-- lazy.nvim bootstrap ------------------------------------------------------
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none", "--branch=stable",
    "https://github.com/folke/lazy.nvim.git", lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000, -- colorscheme must load before anything that reads highlights
    config = function()
      vim.cmd.colorscheme("catppuccin")
    end,
  },

  {
    "nvim-lualine/lualine.nvim",
    opts = {},
  },

  {
    "nvim-treesitter/nvim-treesitter",
    -- Pinned to master on purpose: the `main` branch is the rewrite and has a
    -- different setup API, so leaving this unpinned would break on the next
    -- default-branch change.
    branch = "master",
    build = ":TSUpdate",
    main = "nvim-treesitter.configs",
    opts = {
      auto_install = true,
      highlight = { enable = true },
      indent = { enable = true },
      -- The nixvim config set `folding.enable = false`. Neovim's default
      -- foldmethod is already "manual", so there is nothing to turn off --
      -- noted so the omission reads as deliberate rather than lost.
    },
  },
})

-- Parsers are compiled on demand, so treesitter needs a C compiler present:
-- Xcode command line tools on macOS, gcc on nwa.

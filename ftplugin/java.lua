-- ftplugin/java.lua
--
-- Java (and Spring Boot) projects are driven entirely by `nvim-jdtls` here,
-- not by the generic `servers` table / `vim.lsp.enable()` loop in init.lua.
-- jdtls needs things a plain lspconfig-style entry can't express well:
--   - a per-project `--data` workspace dir (sharing one workspace across
--     unrelated Java repos corrupts jdtls' index/cache)
--   - extra `init_options.bundles` (here: the Spring Boot Tools jars from
--     spring-boot.nvim)
--
-- IMPORTANT: keep `jdtls` OUT of the `servers` table in init.lua. If both
-- that generic path and this file try to start jdtls for the same buffer,
-- you end up with two competing jdtls clients attached at once.

local jdtls = require 'jdtls'

local root_markers = { '.git', 'mvnw', 'gradlew', 'pom.xml', 'build.gradle', 'build.gradle.kts' }
local root_dir = require('jdtls.setup').find_root(root_markers)
if not root_dir then
  -- No project markers found (e.g. a loose scratch/practice .java file with
  -- no pom.xml/build.gradle/.git). Fall back to the file's own directory so
  -- jdtls still attaches and gives you completion/diagnostics/hover, just
  -- without cross-file project awareness.
  root_dir = vim.fs.dirname(vim.api.nvim_buf_get_name(0))
  vim.notify('jdtls: no project root markers found, falling back to file directory: ' .. root_dir, vim.log.levels.WARN)
end

-- Give each project its own jdtls workspace, keyed by root path (not just
-- basename) so two different checkouts named e.g. "backend" never collide.
local workspace_dir = vim.fn.stdpath 'data' .. '/site/java/workspace/' .. vim.fn.sha256(root_dir):sub(1, 12)

local bundles = {}
local has_spring_boot, spring_boot = pcall(require, 'spring_boot')
if has_spring_boot then vim.list_extend(bundles, spring_boot.java_extensions()) end

---@type jdtls.Settings
local config = {
  cmd = { 'jdtls', '-data', workspace_dir },
  root_dir = root_dir,
  init_options = {
    bundles = bundles,
  },
  on_attach = function(_, bufnr)
    if has_spring_boot then spring_boot.init_lsp_commands() end

    local map = function(keys, func, desc, mode)
      vim.keymap.set(mode or 'n', keys, func, { buffer = bufnr, desc = 'Java: ' .. desc })
    end
    map('<leader>co', jdtls.organize_imports, '[C]ode [O]rganize Imports')
    map('<leader>ev', jdtls.extract_variable, '[E]xtract [V]ariable')
    map('<leader>ev', function() jdtls.extract_variable(true) end, '[E]xtract [V]ariable', 'v')
    map('<leader>em', function() jdtls.extract_method(true) end, '[E]xtract [M]ethod', 'v')

    -- Only wire up debugging if nvim-dap is actually loaded (it's disabled
    -- by default in this config; see `kickstart.plugins.debug`).
    local has_dap = pcall(require, 'dap')
    if has_dap then
      jdtls.setup_dap { hotcodereplace = 'auto' }
      require('jdtls.dap').setup_dap_main_class_configs()
    end
  end,
}

jdtls.start_or_attach(config)

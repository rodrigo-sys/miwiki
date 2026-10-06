--[[
 * miwiki - follow or create wikilink pages on <CR>
 * License: GPLv3
]]

if vim.g.loaded_miwiki == 1 then
	return
end
vim.g.loaded_miwiki = 1

local miwiki = require('miwiki')

vim.api.nvim_create_user_command('MiwikiMove', miwiki.move_to_note, {
	range = true,
	nargs = '?',
	complete = miwiki.complete_notes,
	desc = 'Move selected content to a note',
})

vim.api.nvim_create_user_command('MiwikiVault', miwiki.choose_vault, {
	nargs = '?',
	complete = miwiki.complete_vaults,
	desc = 'Open or choose a vault',
})

vim.api.nvim_create_user_command('MiwikiVaultNew', miwiki.create_vault, {
	nargs = '?',
	desc = 'Create a new vault in default dir',
})

vim.api.nvim_create_user_command('MiwikiVaultInit', miwiki.init_cwd_vault, {
	nargs = '?',
	desc = 'Initialize vault in working dir',
})

vim.keymap.set('n', '<leader>nv', miwiki.choose_vault, {
	desc = 'miwiki: choose vault',
})

vim.keymap.set('n', '<leader>nn', miwiki.create_vault, {
	desc = 'miwiki: new vault in default dir',
})

vim.keymap.set('n', '<leader>ni', miwiki.init_cwd_vault, {
	desc = 'miwiki: init vault in working dir',
})



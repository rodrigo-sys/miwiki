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


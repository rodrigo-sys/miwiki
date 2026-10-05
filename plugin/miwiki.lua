--[[
 * miwiki - follow or create wikilink pages on <CR>
 * License: GPLv3
]]

if vim.g.loaded_miwiki == 1 then
	return
end
vim.g.loaded_miwiki = 1

local miwiki = require('miwiki')

vim.api.nvim_create_user_command('MiwikiMove', function(opts)
	miwiki.move_to_note(opts)
end, {
	range = true,
	nargs = '?',
	desc = 'Move selected content to a new note',
})

vim.api.nvim_create_user_command('MiwikiExtract', function(opts)
	miwiki.move_to_note(opts)
end, {
	range = true,
	nargs = '?',
	desc = 'Extract selected content to a new note',
})

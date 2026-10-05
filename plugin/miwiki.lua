--[[
 * miwiki - follow or create wikilink pages on <CR>
 * License: GPLv3
]]

if vim.g.loaded_miwiki == 1 then
	return
end
vim.g.loaded_miwiki = 1

local miwiki = require('miwiki')

local function complete_notes(arg_lead)
	return miwiki.complete_notes(arg_lead)
end

vim.api.nvim_create_user_command('MiwikiMove', function(opts)
	miwiki.move_to_note(opts)
end, {
	range = true,
	nargs = '?',
	complete = complete_notes,
	desc = 'Move selected content to a note',
})

vim.api.nvim_create_user_command('MiwikiExtract', function(opts)
	miwiki.move_to_note(opts)
end, {
	range = true,
	nargs = '?',
	complete = complete_notes,
	desc = 'Extract selected content to a note',
})

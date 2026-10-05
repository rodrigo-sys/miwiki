--[[
 * miwiki - follow or create wikilink pages on <CR>
 * License: GPLv3
]]

if vim.g.loaded_miwiki == 1 then
	return
end
vim.g.loaded_miwiki = 1

require('miwiki')

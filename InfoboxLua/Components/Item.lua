require( 'strict' )

local util = require( 'Module:InfoboxLua/Util' )
local types = require( 'Module:InfoboxLua/Types' )

local p = {}


--- Renders an infobox item.
---
--- @param data table
--- @return mw.html|nil
function p.getHtml( data )
	--- Sometimes modules short-circuit the infobox data and don't return a content string.
	--- If that's the case, we don't want to render anything.
	if not util.isNonEmptyString( data.content ) then
		return nil
	end

	--- @type ItemComponentData
	local item = util.validateAndConstruct( data, types.ItemComponentDataSchema )


	local root = mw.html.create( 'div' )
	root:addClass( 't-infobox-item' )

	if item.class then
		root:addClass( item.class )
	end

	if util.isNonEmptyString( item.label ) then
		root:tag( 'div' )
			:addClass( 't-infobox-item-label' )
			:wikitext( item.label )
			:done()
	end

	root:tag( 'div' )
		:addClass( 't-infobox-item-content' )
		:wikitext( item.content )
		:done()

	return root
end

return p

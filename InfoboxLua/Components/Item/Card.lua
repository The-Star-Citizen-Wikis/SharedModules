require( 'strict' )

local util = require( 'Module:InfoboxLua/Util' )
local types = require( 'Module:InfoboxLua/Types' )
local itemComponent = require( 'Module:InfoboxLua/Components/Item' )

local p = {}

--- @param items ItemComponentData[]
--- @return mw.html
local function getItemsHtml( items )
	local html = mw.html.create( 'div' ):addClass( 't-infobox-item-card-items' )

	for _, item in ipairs( items ) do
		local item = itemComponent.getHtml( item )

		if item then
			html:node( item )
		end
	end

	return html
end

--- @param data ItemCardComponentData
--- @return string|nil
local function getContentHtml( data )
	local html = mw.html.create()

	if util.isNonEmptyString( data.label ) then
		html:tag( 'div' ):addClass( 't-infobox-item-card-label' ):wikitext( data.label )
	end

	if util.isNonEmptyString( data.content ) then
		html:tag( 'div' ):addClass( 't-infobox-item-card-content' ):wikitext( data.content )
	end

	if type( data.items ) == 'table' then
		html:node( getItemsHtml( data.items ) )
	end

	return tostring( html )
end

--- @param data table
--- @return ItemComponentData|nil
function p.getItemComponentData( data )
	if not data then
		return nil
	end

	--- @type ItemCardComponentData
	local itemCard = util.validateAndConstruct( data, types.ItemCardComponentDataSchema )

	if not itemCard then
		return nil
	end

	return {
		class = 't-infobox-item-card',
		content = getContentHtml( data ),
	}
end

return p

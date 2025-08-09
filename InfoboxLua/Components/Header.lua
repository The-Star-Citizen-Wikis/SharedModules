require( 'strict' )

local util = require( 'Module:InfoboxLua/Util' )
local types = require( 'Module:InfoboxLua/Types' )

-- TODO: Move config somewhere else
local PLACEHOLDER_IMAGE = 'Placeholderv2.png';
local IMAGE_SIZE = 400;

local p = {}


--- @param image string
--- @return mw.html
local function getImageHtml( image )
	local root = mw.html.create( 'div' )
	root:addClass( 't-infobox-image' )
	root:wikitext( string.format( '[[File:%s|%dpx]]', image or PLACEHOLDER_IMAGE, IMAGE_SIZE ) )

	return root
end

--- @param title string
--- @param subtitle string
--- @return mw.html
local function getHeaderBottomHtml( title, subtitle )
	local root = mw.html.create( 'div' )
	root:addClass( 't-infobox-header-bottom' )
	root:tag( 'div' )
		:addClass( 't-infobox-title' )
		:wikitext( title )
		:done()

	if util.isNonEmptyString( subtitle ) then
		root:tag( 'div' )
			:addClass( 't-infobox-subtitle' )
			:wikitext( subtitle )
			:done()
	end

	return root
end

--- Renders an infobox header.
---
--- @param data table
--- @return mw.html|nil
function p.getHtml( data )
	--- @type HeaderComponentData|nil
	local header = util.validateAndConstruct( data, types.HeaderComponentDataSchema )

	if not header then
		return nil
	end

	local root = mw.html.create( 'div' )
	root:addClass( 't-infobox-header' )

	root:node( getImageHtml( header.image ) )
	root:node( getHeaderBottomHtml( header.title, header.subtitle ) )

	return root
end

return p

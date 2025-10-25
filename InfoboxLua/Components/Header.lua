require( 'strict' )

local tabber = mw.ext.tabber
local util = require( 'Module:InfoboxLua/Util' )
local types = require( 'Module:InfoboxLua/Types' )

local p = {}


--- @param image ImageComponentData|string
--- @return mw.html
local function getImageHtml( image )
	if type( image ) == 'string' then
		image = { src = image }
	end

	local imageData = util.validateAndConstruct( image, types.ImageComponentDataSchema )

	local root = mw.html.create( 'div' )
	root:addClass( 't-infobox-image-container' )

	root:tag( 'div' )
		:addClass( 't-infobox-image' )
		:wikitext( string.format( '[[File:%s|%dpx|class=%s]]', imageData.src, imageData.size, imageData.class or '' ) )
		:done()

	if util.isNonEmptyString( imageData.overlay ) then
		root:tag( 'div' )
			:addClass( 't-infobox-image-overlay' )
			:wikitext( imageData.overlay )
			:done()
	end

	if util.isNonEmptyString( imageData.caption ) then
		root:tag( 'div' )
			:addClass( 't-infobox-image-caption' )
			:wikitext( imageData.caption )
			:done()
	end

	return root
end

--- @param images ImageComponentData[]
--- @return mw.html
local function getImagesHtml( images )
	local root = mw.html.create( 'div' )
	root:addClass( 't-infobox-images' )

	local tabberData = {}

	for i, image in ipairs( images ) do
		if util.validateAndConstruct( image, types.ImageComponentDataSchema ) then
			table.insert( tabberData, {
				label = image.label or tostring( i ),
				content = tostring( getImageHtml( image ) )
			} )
		end
	end

	if tabberData ~= {} then
		root:node( tabber.render( tabberData ) )
	end

	return root
end

--- @param title string
--- @return mw.html
local function getHeaderTitleHtml( title )
	local root = mw.html.create( 'div' )
	root:addClass( 't-infobox-title' )
	root:wikitext( title )
	return root
end

--- @param subtitle string
--- @return mw.html
local function getHeaderSubtitleHtml( subtitle )
	local root = mw.html.create( 'div' )
	root:addClass( 't-infobox-subtitle' )
	root:wikitext( subtitle )
	return root
end

--- @param title string
--- @param subtitle string
--- @return mw.html
local function getHeaderContentHtml( title, subtitle )
	local root = mw.html.create( 'div' )
	root:addClass( 't-infobox-header-content' )
	root:node( getHeaderTitleHtml( title ) )

	if util.isNonEmptyString( subtitle ) then
		root:node( getHeaderSubtitleHtml( subtitle ) )
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

	if type( header.images ) == 'table' then
		root:node( getImagesHtml( header.images ) )
	elseif type( header.image ) == 'table' then
		root:node( getImageHtml( header.image ) )
	end

	root:node( getHeaderContentHtml( header.title, header.subtitle ) )

	return root
end

return p

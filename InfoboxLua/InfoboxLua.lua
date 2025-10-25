require( 'strict' )

local PLACEHOLDER_IMAGE = 'Placeholderv2.png'
local PLACEHOLDER_IMAGE_SIZE = 400
local INFOBOX_WIDTH = 400

local headerComponent = require( 'Module:InfoboxLua/Components/Header' )
local sectionComponent = require( 'Module:InfoboxLua/Components/Section' )

--- @class InfoboxLuaData
--- @field class string|nil An additional HTML class for the infobox's container. Optional.
--- @field css table<string, string>|nil Additional CSS rules for the infobox. Optional.
--- @field title string The title of the infobox.
--- @field subtitle string|nil The subtitle of the infobox. Optional.
--- @field image ImageComponentData|string|nil The image of the infobox. Optional.
--- @field images table<ImageComponentData>|nil The images of the infobox. Optional.
--- @field sections table<SectionComponentData>|nil The sections of the infobox. Optional.

local p = {}

--- Get the image data
---
--- @param image string|ImageComponentData
--- @return ImageComponentData
local function getImageData( image )
	local imageData = {}

	if type( image ) == 'string' then
		imageData.src = image
	end

	if type( image ) == 'table' then
		imageData = image
	end

	if type( imageData.size ) ~= 'number' then
		imageData.size = INFOBOX_WIDTH
	end

	-- No image source, use placeholder
	if type( imageData.src ) ~= 'string' then
		imageData.src = PLACEHOLDER_IMAGE
		imageData.size = PLACEHOLDER_IMAGE_SIZE
	end

	return imageData
end


--- @param data InfoboxLuaData
--- @return HeaderComponentData
local function getHeaderData( data )
	local image = getImageData( data.image )

	return {
		title = data.title,
		subtitle = data.subtitle or nil,
		image = image,
		images = data.images or nil
	}
end

--- @param data InfoboxLuaData
--- @return mw.html
local function getContentHtml( data )
	local root = mw.html.create( 'div' )
	root:addClass( 't-infobox-content' )

	root:node( headerComponent.getHtml( getHeaderData( data ) ) )

	for _, section in ipairs( data.sections ) do
		local sectionHtml = sectionComponent.getHtml( section )
		if sectionHtml then
			root:node( sectionHtml )
		end
	end

	return root
end

--- @param data InfoboxLuaData
--- @return mw.html
local function getInfoboxHtml( data )
	local root = mw.html.create( 'div' )
	root:addClass( 't-infobox floatright' )
		:addClass( data.class )
		:css( 'max-width', INFOBOX_WIDTH .. 'px' )
		:node( getContentHtml( data ) )

	if type( data.css ) == 'table' then
		for cssProperty, cssValue in pairs( data.css ) do
			root:css( cssProperty, cssValue )
		end
	end

	return root
end

--- @param data InfoboxLuaData
--- @return mw.html
function p.render( data )
	local html = getInfoboxHtml( data )
	local styles = mw.getCurrentFrame():extensionTag {
		name = 'templatestyles', args = { src = 'Module:InfoboxLua/styles.css' }
	}

	return styles .. tostring( html )
end

function p.test()
	local data = mw.loadJsonData( 'Module:InfoboxLua/testData.json' )
	local html = p.render( data )

	mw.logObject( data )
	mw.logObject( html )

	return html
end

return p

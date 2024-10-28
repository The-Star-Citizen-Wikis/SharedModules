--- Module:Dimensions
--- Used to display an isometric cube showing the dimensions of an object
---
--- TODO: Add i18n
--- TODO: Brush up isometric functions for more generic use cases
--- TODO: Don't hardcode --container-size, it should be based on the current container
require( 'strict' )

local p = {}

local i18n = require( 'Module:i18n' ):new()
local lang = mw.getContentLanguage()

--- Wrapper function for Module:i18n.translate
---
--- @param key string The translation key
--- @return string If the key was not found, the key is returned
local function t( key )
	return i18n:translate( key )
end


--- Get the text HTML object
---
--- @param data table
--- @return mw.html
local function getTextHTML( data )
	if not data.label and not data.value then return end
	local html = mw.html.create( 'div' )
		:addClass( 'template-dimensions-box-text' )

	if data.variant then
		html:addClass( 'template-dimensions-box-text-' .. data.variant )
	end

	if data.label then
		html:tag( 'div' )
			:addClass( 'template-dimensions-label' )
			:wikitext( data.label )
			:done()
	end

	if data.value then
		html:tag( 'div' )
			:addClass( 'template-dimensions-data' )
			:wikitext( data.value )
			:done()
	end

	return html
end


--- Get the object HTML object
---
--- @param data table
--- @return mw.html
local function getObjectHTML( data )
	local html = mw.html.create( 'div' )
		:addClass( 'template-dimensions-object' )
		:css( {
			[ '--object-length' ] = data.length.number,
			[ '--object-width' ] = data.width.number,
			[ '--object-height' ] = data.height.number,
		} )

	local isometric = html:tag( 'div' )
		:addClass( 'template-dimensions-isometric' )
		:css( {
			[ 'transform-style' ] = 'preserve-3d',
			[ 'grid-template-areas' ] = "'layer'"
		} )

	-- Top layer
	isometric:tag( 'div' )
		:addClass( 'template-dimensions-layer template-dimensions-layer-top' )
		:css( 'transform-style', 'preserve-3d' )
		:tag( 'div' )
		:addClass( 'template-dimensions-box-faces' )
		:css( 'transform-style', 'preserve-3d' )
		:tag( 'div' )
		:addClass( 'template-dimensions-box-face template-dimensions-box-face-top' )
		:done()
		:tag( 'div' )
		:addClass( 'template-dimensions-box-face template-dimensions-box-face-front' )
		:done()
		:tag( 'div' )
		:addClass( 'template-dimensions-box-face template-dimensions-box-face-right' )
		:done()
		:done()
		:node( getTextHTML( {
			label = data.height.label,
			value = data.height.value,
			variant = 'y'
		} ) )
		:node( getTextHTML( {
			label = data.mass.label,
			value = data.mass.value,
			variant = 'z'
		} ) )
		:done()

	-- Bottom layer
	isometric:tag( 'div' )
		:addClass( 'template-dimensions-layer template-dimensions-layer-bottom' )
		:css( 'transform-style', 'preserve-3d' )
		--- Create a human-sized object for reference
		--- FIXME: Figure out how to do a box properly, haven't done trigonometry in ages...
		:tag( 'div' )
		:addClass( 'template-dimensions-reference template-dimensions-box-faces' )
		:attr( 'title', 'Human for reference' )
		:css( 'transform-style', 'preserve-3d' )
		:tag( 'div' )
		:addClass( 'template-dimensions-box-face template-dimensions-box-face-top' )
		:done()
		:tag( 'div' )
		:addClass( 'template-dimensions-box-face template-dimensions-box-face-front' )
		:done()
	--:tag( 'div' )
	--    :addClass( 'template-dimensions-box-face template-dimensions-box-face-right' )
	--    :done()
		:done()
		:node( getTextHTML( {
			label = data.length.label,
			value = data.length.value,
			variant = 'z'
		} ) )
		:node( getTextHTML( {
			label = data.width.label,
			value = data.width.value,
			variant = 'x'
		} ) )
		:done()

	return html
end


--- Get the output HTML object
---
--- @param data table
--- @return mw.html
local function getOutputHTML( data )
	local html = mw.html.create( 'div' )
		:addClass( 'template-dimensions' )
		:node( getObjectHTML( data ) )
	return html
end

--- Return string containing the number with separator and unit
---
--- @param arg string|number|nil
--- @param unit string
--- @param altArg string|number|nil
--- @return string|nil
local function getDimensionsValue( arg, unit, altArg )
	if not arg or not unit then return end
	local num = tonumber( arg )
	if not num then return end

	local value = string.format( '%s %s', lang:formatNum( num ), unit )
	if not altArg or arg == altArg then
		return value
	end

	local altValue = getDimensionsValue( altArg, unit )
	if not altValue then
		return value
	end
	return string.format(
		'%s <span class="template-dimensions-data-subtle">(%s)</span>',
		value,
		altValue
	)
end


--- Format arguments into data used by HTML functions
---
--- @param args table
--- @return table|nil
local function getDimensionsData( args )
	local lengthNum = tonumber( args.length )
	local widthNum = tonumber( args.width )
	local heightNum = tonumber( args.height )

	if not lengthNum or not widthNum or not heightNum then return end
	-- TODO: Make this cleaner by using another table to map the units?
	local lengthValue = getDimensionsValue( args.length, 'm', args.lengthAlt )
	local widthValue = getDimensionsValue( args.width, 'm', args.widthAlt )
	local heightValue = getDimensionsValue( args.height, 'm', args.heightAlt )

	-- TODO: Perhaps this can be done in a loop
	local data = {
		length = {
			number = lengthNum,
			label = t( 'label_Length' ),
			value = lengthValue
		},
		width = {
			number = widthNum,
			label = t( 'label_Width' ),
			value = widthValue
		},
		height = {
			number = heightNum,
			label = t( 'label_Height' ),
			value = heightValue
		},
		mass = {
			label = t( 'label_Mass' ),
			value = getDimensionsValue( args.mass, 'kg' ) or '-'
		}
	}

	return data
end


--- Lua entry point
---
--- @param args table
--- @param frame table
--- @return string|nil
function p._main( args, frame )
	if not args.length or not args.width or not args.height then return end
	-- Frame object can be missing if function is invoked from Lua
	frame = frame or mw.getCurrentFrame()

	local data = getDimensionsData( args )
	if not data then return end
	return tostring( getOutputHTML( data ) ) .. frame:extensionTag {
		name = 'templatestyles', args = { src = 'Module:Dimensions/styles.css' }
	}
end

--- Wikitext entry point
---
--- @return string|nil
function p.main( frame )
	local args = require( 'Module:Arguments' ).getArgs( frame )
	return p._main( args, frame )
end

return p

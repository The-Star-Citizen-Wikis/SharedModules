require( 'strict' )

local headerComponent = require( 'Module:InfoboxNeueMkII/Components/Header' )
local sectionComponent = require( 'Module:InfoboxNeueMkII/Components/Section' )

local p = {}


--- @param data table
--- @return mw.html
local function getContentHtml( data )
	local root = mw.html.create( 'div' )
	root:addClass( 't-infobox-content' )

	root:node( headerComponent.getHtml( {
		title = data.title,
		subtitle = data.subtitle,
		image = data.image
	} ) )

	for _, section in ipairs( data.sections ) do
		local sectionHtml = sectionComponent.getHtml( section )
		if sectionHtml then
			root:node( sectionHtml )
		end
	end

	return root
end

--- @param data table
--- @return mw.html
local function renderInfobox( data )
	local root = mw.html.create( 'div' )
	root:addClass( 't-infobox floatright' )
		:node( getContentHtml( data ) )

	return root
end

function p.test()
	local data = mw.loadJsonData( 'Module:InfoboxNeueMkII/testData.json' )
	local html = renderInfobox( data )
	local styles = mw.getCurrentFrame():extensionTag {
		name = 'templatestyles', args = { src = 'Module:InfoboxNeueMkII/styles.css' }
	}

	mw.logObject( html )

	return styles .. tostring( html )
end

return p

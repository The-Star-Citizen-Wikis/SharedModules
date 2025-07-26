require( 'strict' )

local sectionComponent = require( 'Module:InfoboxNeueMkII/Components/Section' )

local p = {}

local function renderInfobox( data )
	local root = mw.html.create( 'div' )
	root:addClass( 't-infobox floatright' )

	for _, section in ipairs( data.sections ) do
		local sectionHtml = sectionComponent.getHtml( section )
		if sectionHtml then
			root:node( sectionHtml )
		end
	end

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

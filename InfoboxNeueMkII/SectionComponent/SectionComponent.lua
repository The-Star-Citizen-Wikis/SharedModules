require( 'strict' )

local tabber = mw.ext.tabber
local util = require( 'Module:InfoboxNeueMkII/Util' )
local types = require( 'Module:InfoboxNeueMkII/Types' )
local itemComponent = require( 'Module:InfoboxNeueMkII/ItemComponent' )

local p = {}


--- @param section SectionComponentData
--- @return mw.html
local function getItemsHtml( section )
	local root = mw.html.create( 'div' )
	root:addClass( 't-infobox-section-items' )

	if section.columns and section.columns > 1 then
		root:css( '--infobox-section-columns', tostring( section.columns ) )
	end
	for _, itemData in ipairs( section.items ) do
		local itemHtml = itemComponent.getHtml( itemData )
		if itemHtml then
			root:node( itemHtml )
		end
	end

	return root
end

--- @param section SectionComponentData
--- @return mw.html
local function getSubSectionsHtml( section )
	local root = mw.html.create( 'div' )
	root:addClass( 't-infobox-section-subsections' )

	local tabberData = {}

	for _, subSectionData in ipairs( section.sections ) do
		local label = subSectionData.label

		if not util.isNonEmptyString( label ) then
			error( 'Label is required for subsection' )
		end

		local content = tostring( p.getHtml( subSectionData, true ) )

		table.insert( tabberData, {
			label = label,
			content = content
		} )
	end

	if tabberData ~= {} then
		root:node( tabber.render( tabberData ) )
	end

	return root
end

--- Renders an infobox section.
---
--- @param data table
--- @param isSubSection boolean|nil
--- @return mw.html|nil
function p.getHtml( data, isSubSection )
	--- @type SectionComponentData|nil
	local section = util.validateAndConstruct( data, types.SectionComponentDataSchema )

	if not section then
		return nil
	end

	local root = mw.html.create( 'div' )
	root:addClass( 't-infobox-section' )

	if util.isNonEmptyString( section.class ) then
		root:addClass( section.class )
	end

	if util.isNonEmptyString( section.content ) then
		root:wikitext( section.content )
	end

	if util.isNonEmptyString( section.label ) and isSubSection ~= true then
		root:tag( 'div' )
			:addClass( 't-infobox-section-label' )
			:wikitext( section.label )
			:done()
	end

	if type( section.items ) == 'table' then
		root:node( getItemsHtml( section ) )
	end

	if type( section.sections ) == 'table' then
		root:node( getSubSectionsHtml( section ) )
	end

	return root
end

return p

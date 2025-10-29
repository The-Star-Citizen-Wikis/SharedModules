require( 'strict' )

local tabber = mw.ext.tabber
local util = require( 'Module:InfoboxLua/Util' )
local types = require( 'Module:InfoboxLua/Types' )
local itemComponent = require( 'Module:InfoboxLua/Components/Item' )
local collapsibleComponent = require( 'Module:InfoboxLua/Components/Collapsible' )

local p = {}

--- @param label string
--- @return mw.html
local function getLabelHtml( label )
	local html = mw.html.create( 'div' )
	html:addClass( 't-infobox-section-label' )
	html:wikitext( label )
	return html
end

--- @param section SectionComponentData
--- @return mw.html
local function getItemsHtml( section )
	local html = mw.html.create( 'div' )
	html:addClass( 't-infobox-section-items' )

	if section.columns and section.columns > 1 then
		html:css( '--infobox-section-columns', tostring( section.columns ) )
	end
	for _, itemData in ipairs( section.items ) do
		local itemHtml = itemComponent.getHtml( itemData )
		if itemHtml then
			html:node( itemHtml )
		end
	end

	return html
end

--- @param section SectionComponentData
--- @return mw.html|nil
local function getSubSectionsHtml( section )
	local tabberData = {}

	for i, subSectionData in ipairs( section.sections ) do
		local label = subSectionData.label
		local contentHtml = p.getHtml( subSectionData, true )

		if label and contentHtml then
			table.insert( tabberData, {
				label = label,
				content = tostring( contentHtml )
			} )
		end
	end

	if tabberData == {} then
		return nil
	end

	local root = mw.html.create( 'div' )
	root:addClass( 't-infobox-section-subsections' )
	root:node( tabber.render( tabberData ) )

	return root
end

--- @param section SectionComponentData
--- @return mw.html|nil
local function getContentHtml( section )
	local html = mw.html.create()
	local isEmpty = true

	if util.isNonEmptyString( section.content ) then
		isEmpty = false
		html:wikitext( section.content )
	end

	if util.isNonEmptyTable( section.items ) then
		local itemsHtml = getItemsHtml( section )
		if itemsHtml then
			isEmpty = false
			html:node( itemsHtml )
		end
	end

	if util.isNonEmptyTable( section.sections ) then
		local subSectionsHtml = getSubSectionsHtml( section )
		if subSectionsHtml then
			isEmpty = false
			html:node( subSectionsHtml )
		end
	end

	return isEmpty and nil or html
end

--- @param class string|nil
--- @return string
local function getSectionClass( class )
	return 't-infobox-section' .. (util.isNonEmptyString( class ) and ' ' .. class or '')
end

--- @param section SectionComponentData
--- @param contentHtml mw.html|nil
--- @param isSubSection boolean|nil
--- @return mw.html
local function getSimpleSectionHtml( section, contentHtml, isSubSection )
	local html = mw.html.create( 'div' )
	html:addClass( getSectionClass( section.class ) )

	if isSubSection ~= true and util.isNonEmptyString( section.label ) then
		html:node( getLabelHtml( section.label ) )
	end

	html:node( contentHtml )

	return html
end

--- @param section SectionComponentData
--- @param contentHtml mw.html|nil
--- @return mw.html
local function getCollapsibleSectionHtml( section, contentHtml )
	return collapsibleComponent.getHtml( {
		summary = tostring( getLabelHtml( section.label ) ),
		content = tostring( contentHtml ),
		class = getSectionClass( section.class ),
		open = not section.collapsed
	} )
end

--- Returns the mw.html object of the infobox section component.
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

	local contentHtml = getContentHtml( section )

	-- Subsection can't be collapsible for now
	if section.collapsible == true and isSubSection ~= true then
		return getCollapsibleSectionHtml( section, contentHtml )
	end

	return getSimpleSectionHtml( section, contentHtml, isSubSection )
end

return p

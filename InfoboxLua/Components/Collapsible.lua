require( 'strict' )

local details -- lazyload [[Module:Details]]
local util = require( 'Module:InfoboxLua/Util' )
local types = require( 'Module:InfoboxLua/Types' )

local p = {}

--- @param content string
--- @return mw.html
local function getContentHtml( content )
	local html = mw.html.create( 'div' ):addClass( 't-infobox-collapsible-content' )
	html:wikitext( tostring( content ) )
	return html
end

--- @param summary string
--- @return mw.html
local function getButtonHtml( summary )
	local html = mw.html.create()

	html:tag( 'div' )
		:addClass( 'citizen-ui-icon mw-ui-icon-wikimedia-collapse' )
		:done()
		:wikitext( tostring( summary ) )

	return html
end

--- Returns the mw.html object of the infobox collapsible component.
---
--- @param data table
--- @return mw.html|nil
function p.getHtml( data )
	--- @type CollapsibleComponentData|nil
	local collapsible = util.validateAndConstruct( data, types.CollapsibleComponentDataSchema )

	if not collapsible then
		return nil
	end

	details = details or require( 'Module:Details' )

	local html = mw.html.create()

	local wikitext = details.getWikitext( {
		details = {
			content = tostring( getContentHtml( collapsible.content ) ),
			class = collapsible.class or '',
			open = collapsible.open ~= false -- default to open
		},
		summary = {
			content = tostring( getButtonHtml( collapsible.summary ) ),
			class = collapsible.summaryClass or ''
		}
	} )

	html:wikitext( wikitext )

	return html
end

return p

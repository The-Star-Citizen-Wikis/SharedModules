local InfoboxNeue = {}

local metatable = {}
local methodtable = {}

metatable.__index = methodtable


metatable.__tostring = function( self )
	return tostring( self:renderInfobox() )
end


--- Helper function to restore underscore from space
--- so that it does not screw up the external link wikitext syntax
--- For some reason SMW property converts underscore into space
--- mw.uri.encode can't be used on full URL
local function restoreUnderscore( s )
	return s:gsub( ' ', '%%5F' )
end


--- Put table values into a comma-separated list
---
--- @param self table
--- @return string
function methodtable.tableToCommaList( self )
	if type( self ) == 'table' then
		return table.concat( self, ', ' )
	else
		return self
	end
end


--- Shortcut to return the HTML of the infobox message component as string
---
--- @param data table {title, desc)
--- @return string html
function methodtable.renderMessage( self, data, noInsert )
	local item = self:renderSection( { content = self:renderItem( { data = data.title, desc = data.desc } ) } )

	if not noInsert then
		table.insert( self.entries, item )
	end

	return item
end


--- Return the HTML of the infobox image component as string
---
--- @param filename string
--- @return string html
function methodtable.renderImage( self, filename )
	if type( filename ) ~= 'string' and self.config.displayPlaceholder == true then
		filename = self.config.placeholderImage
	end

	if type( filename ) ~= 'string' then
		return ''
	end

	local parts = mw.text.split( filename, ':', true )
	if #parts > 1 then
		table.remove( parts, 1 )
		filename = table.concat( parts, ':' )
	end

	local html = mw.html.create( 'div' )
		:addClass( 'infobox__image' )
		:wikitext( string.format( '[[File:%s|400px]]', filename ) )

	local item = tostring( html )

	table.insert( self.entries, item )

	return item
end


--- Return the HTML of the infobox indicator component as string
---
--- @param data table {data, desc, class)
--- @return string html
function methodtable.renderIndicator( self, data )
	if data == nil or data[ 'data' ] == nil or data[ 'data' ] == '' then return '' end

	local html = mw.html.create( 'div' ):addClass( 'infobox__indicator' )
	html:wikitext(
            self:renderItem(
			{
				[ 'data' ] = data[ 'data' ],
				[ 'desc' ] = data[ 'desc' ] or nil,
				row = true,
				spacebetween = true
			}
		)
	)

	if data[ 'class' ] then html:addClass( data[ 'class' ] ) end

	local item = tostring( html )

	table.insert( self.entries, item )

	return item
end


--- Return the HTML of the infobox header component as string
---
--- @param data table {title, subtitle)
--- @return string html
function methodtable.renderHeader( self, data )
	if data == nil or data[ 'title' ] == nil then return '' end

	if type( data ) == 'string' then
		data = {
			title = data
		}
	end

	if data == nil or data[ 'title' ] == nil then return '' end

	local html = mw.html.create( 'div' ):addClass( 'infobox__header' )

	html:tag( 'div' )
		:addClass( 'infobox__title' )
		:wikitext( data[ 'title' ] )

	if data[ 'subtitle' ] then
		html:tag( 'div' )
			-- Subtitle is always data
			:addClass( 'infobox__subtitle infobox__data' )
			:wikitext( data[ 'subtitle' ] )
	end

	local item = tostring( html )

	table.insert( self.entries, item )

	return item
end


--- Wrap the HTML into an infobox section
---
--- @param data table {title, subtitle, content, col, class}
--- @param noInsert boolean whether to insert this section into the internal table table
--- @return string html
function methodtable.renderSection( self, data, noInsert )
	noInsert = noInsert or false

	if type( data.content ) == 'table' then
		data.content = table.concat( data.content )
	end

	if data == nil or data[ 'content' ] == nil or data[ 'content' ] == '' then return '' end

	local html = mw.html.create( 'div' ):addClass( 'infobox__section' )

	if data[ 'title' ] then
		local header = html:tag( 'div' ):addClass( 'infobox__sectionHeader' )
		header:tag( 'div' )
				:addClass( 'infobox__sectionTitle' )
				:wikitext( data[ 'title' ] )
		if data[ 'subtitle' ] then
			header:tag( 'div' )
				:addClass( 'infobox__sectionSubtitle' )
				:wikitext( data[ 'subtitle' ] )
		end
	end

	local content = html:tag( 'div' )
	content:addClass( 'infobox__sectionContent')
			:wikitext( data[ 'content' ] )

	if data[ 'col' ] then content:addClass( 'infobox__grid--cols-' .. data[ 'col' ] ) end
	if data[ 'class' ] then html:addClass( data[ 'class' ] ) end

	local item = tostring( html )

	if not noInsert then
		table.insert( self.entries, item )
	end

	return item
end


--- Return the HTML of the infobox link button component as string
---
--- @param data table {label, link, page}
--- @return string html
function methodtable.renderLinkButton( self, data )
	if data == nil or data[ 'label' ] == nil or ( data[ 'link' ] == nil and data[ 'page' ] == nil ) then return '' end

	--- Render multiple linkButton when link is a table
	if type( data[ 'link' ] ) == 'table' then
		local htmls = {}

		for i, url in ipairs( data[ 'link' ] ) do
			table.insert( htmls,
				self:renderLinkButton( {
					label = string.format( '%s %d', data[ 'label' ], i ),
					link = url
				} )
			)
		end

		return table.concat( htmls )
	end

	local html = mw.html.create( 'div' ):addClass( 'infobox__linkButton' )

	if data[ 'link' ] then
		html:wikitext( string.format( '[%s %s]', restoreUnderscore( data[ 'link' ] ), data[ 'label' ] ) )
	elseif data[ 'page' ] then
		html:wikitext( string.format( '[[%s|%s]]', data[ 'page' ], data[ 'label' ] ) )
	end

	return tostring( html )
end


--- Return the HTML of the infobox footer button component as string
---
--- @param data table {icon, label, type, content}
--- @return string html
function methodtable.renderFooterButton( self, data )
	if data == nil or data[ 'label' ] == nil or data[ 'type' ] == nil or data[ 'content' ] == nil or data[ 'content' ] == '' then return '' end

	local html = mw.html.create( 'div' ):addClass( 'infobox__footer' )

	local button = html:tag( 'div' ):addClass( 'infobox__button' )
	local label = button:tag( 'div' ):addClass( 'infobox__buttonLabel' )

	if data[ 'icon' ] ~= nil then
		label:wikitext( string.format( '[[File:%s|16px|link=]]%s', data[ 'icon' ], data[ 'label' ] ) )
	else
		label:wikitext( data[ 'label' ] )
	end

	if data[ 'type' ] == 'link' then
		button:tag( 'div' )
			:addClass( 'infobox__buttonLink' )
			:wikitext( data[ 'content' ] )
	elseif data[ 'type' ] == 'popup' then
		button:tag( 'div' )
			:addClass( 'infobox__buttonCard' )
			:wikitext( data[ 'content' ] )
	end

	local item = tostring( html )

	table.insert( self.entries, item )

	return item
end

--- Return the HTML of the infobox item component as string
---
--- @param data table {label, data, desc, row, spacebetween, colspan)
--- @param content string|number optional
--- @return string html
function methodtable.renderItem( self, data, content )
	-- The arguments are not passed as a table
	-- Allows to call this as box:renderItem( 'Label', 'Data' )
	if content ~= nil then
		data = {
			label = data,
			data = content
		}
	end

	if data == nil or data[ 'data' ] == nil or data[ 'data' ] == '' then return '' end

	if self.config.removeEmpty == true and data[ 'data' ] == self.config.emptyString then
		return ''
	end

	local html = mw.html.create( 'div' ):addClass( 'infobox__item' )

	if data[ 'row' ] == true then html:addClass( 'infobox__grid--row' ) end
	if data[ 'spacebetween' ] == true then html:addClass( 'infobox__grid--space-between' ) end
	if data[ 'colspan' ] then html:addClass( 'infobox__grid--col-span-' .. data[ 'colspan' ] ) end

	local dataOrder = { 'label', 'data', 'desc' }

	for _, key in ipairs( dataOrder ) do
		if data[ key ] then
			if type( data[ key ] ) == 'table' then
				data[ key ] = table.concat( data[ key ], ', ' )
			end

			html:tag( 'div' )
				:addClass( 'infobox__' .. key )
				:wikitext( data[ key ] )
		end
	end

	return tostring( html )
end


--- Wrap the infobox HTML
---
--- @param innerHtml string inner html of the infobox
--- @param snippetText string text used in snippet in mobile view
--- @return string html infobox html with templatestyles
function methodtable.renderInfobox( self, innerHtml, snippetText )
	innerHtml = innerHtml or self.entries
	if type( innerHtml ) == 'table' then
		innerHtml = table.concat( self.entries )
	end

	local function renderSnippet()
		if snippetText == nil then snippetText = mw.title.getCurrentTitle().rootText end

		local html = mw.html.create( 'div' )

		html
			:addClass( 'infobox__snippet mw-collapsible-toggle' )
			:tag( 'div' )
				:addClass( 'citizen-ui-icon mw-ui-icon-wikimedia-collapse' )
				:done()
			:tag( 'div' )
				:addClass( 'infobox__data' )
				:wikitext( 'Quick facts:' )
				:done()
			:tag( 'div' )
				:addClass( 'infobox__desc' )
				:wikitext( snippetText )

		return tostring( html )
	end

	local html = mw.html.create( 'div' )

	html
		:addClass( 'infobox floatright mw-collapsible' )
		:wikitext( renderSnippet() )
		:tag( 'div' )
			:addClass( 'infobox__content mw-collapsible-content' )
			:wikitext( innerHtml )

	return tostring( html ) .. mw.getCurrentFrame():extensionTag{
		name = 'templatestyles', args = { src = 'Module:InfoboxNeue/styles.css' }
	}
end


--- Just an accessor for the class method
function methodtable.showDescIfDiff( s1, s2 )
	return InfoboxNeue.showDescIfDiff( s1, s2 )
end


--- Format text to show comparison as desc text if two strings are different
---
--- @param s1 string base
--- @param s2 string comparsion
--- @return string html
function InfoboxNeue.showDescIfDiff( s1, s2 )
    if s1 == nil or s2 == nil or s1 == s2 then return s1 end
    return string.format( '%s <span class="infobox__desc">(%s)</span>', s1, s2 )
end


--- New Instance
---
--- @return table InfoboxNeue
function InfoboxNeue.new( self, config )
	local baseConfig = {
		-- Flag to discard empty rows
		removeEmpty = false,
		-- Optional string which is valued as empty
		emptyString = nil,
		-- Display a placeholder image if addImage does not find an image
		displayPlaceholder = true,
		-- Placeholder Image
		placeholderImage = 'Platzhalter.webp',
	}

	for k, v in pairs( config or {} ) do
		baseConfig[ k ] = v
	end

    local instance = {
		config = baseConfig,
		entries = {}
	}

    setmetatable( instance, metatable )

    return instance
end


return InfoboxNeue

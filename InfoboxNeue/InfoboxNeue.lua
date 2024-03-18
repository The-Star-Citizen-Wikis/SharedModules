local InfoboxNeue = {}

local metatable = {}
local methodtable = {}

local libraryUtil = require( 'libraryUtil' )
local checkType = libraryUtil.checkType
local checkTypeMulti = libraryUtil.checkTypeMulti


metatable.__index = methodtable

metatable.__tostring = function( self )
	return tostring( self:renderInfobox() )
end


--- FIXME: This should go to somewhere else, like Module:Common
--- Calls TNT with the given key
---
--- @param key string The translation key
--- @return string If the key was not found in the .tab page, the key is returned
local function translate( key, ... )
	local TNT = require( 'Module:Translate' ):new()
	local success, translation = pcall( TNT.format, 'Module:InfoboxNeue/i18n.json', key or '', ... )

	if not success or translation == nil then
		return key
	end

	return translation
end


--- Helper function to restore underscore from space
--- so that it does not screw up the external link wikitext syntax
--- For some reason SMW property converts underscore into space
--- mw.uri.encode can't be used on full URL
local function restoreUnderscore( s )
	return s:gsub( ' ', '%%5F' )
end

--- Helper function to format string to number with separators
--- It is usually use to re-format raw number from SMW into more readable format
local function formatNumber( s )
	local lang = mw.getContentLanguage()
	if s == nil then
		return
	end
	
	if type( s ) ~= 'number' then
		s = tonumber( s )
	end

	if type( s ) == 'number' then
		return lang:formatNum( s )
	end

	return s
end


--- Put table values into a comma-separated list
---
--- @param data table
--- @return string
function methodtable.tableToCommaList( data )
	if type( data ) == 'table' then
		return table.concat( data, ', ' )
	else
		return data
	end
end

--- Show range if value1 and value2 are different
---
--- @param s1 string|nil
--- @param s2 string|nil
--- @return string|nil
function methodtable.formatRange( s1, s2, formatNum )
	if s1 == nil and s2 == nil then
		return
	end

	formatNum = formatNum or false;

	if formatNum then
		if s1 then
			s1 = formatNumber( s1 )
		end
		if s2 then
			s2 = formatNumber( s2 )
		end
	end

	if s1 and s2 and s1 ~= s2 then
		return s1 .. ' – ' .. s2
	end

	return s1 or s2
end

--- Append unit to the value if exists
---
--- @param s string
--- @param unit string
--- @return string|nil
function methodtable.addUnitIfExists( s, unit )
	if s == nil then
		return
	end

	return s .. ' ' .. unit
end


--- Shortcut to return the HTML of the infobox message component as string
---
--- @param data table {title, desc)
--- @return string html
function methodtable.renderMessage( self, data, noInsert )
	checkType( 'Module:InfoboxNeue.renderMessage', 1, self, 'table' )
	checkType( 'Module:InfoboxNeue.renderMessage', 2, data, 'table' )
	checkType( 'Module:InfoboxNeue.renderMessage', 3, noInsert, 'boolean', true )

	noInsert = noInsert or false

	local item = self:renderSection( { content = self:renderItem( { data = data.title, desc = data.desc } ) }, noInsert )

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
	checkType( 'Module:InfoboxNeue.renderImage', 1, self, 'table' )

	if type( filename ) ~= 'string' and self.config.displayPlaceholder == true then
		filename = self.config.placeholderImage
		-- Add tracking category for infoboxes using placeholder image
		table.insert( self.categories,
			string.format( '[[Category:%s]]', translate( 'category_infobox_using_placeholder_image' ) )
		)
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
		:wikitext( mw.ustring.format( '[[File:%s|400px]]', filename ) )

	if self.config.displayPlaceholder == true then
		local icon = mw.html.create( 'span' ):addClass( 'citizen-ui-icon mw-ui-icon-wikimedia-upload' )
		-- TODO: Point the Upload link to a specific file name
		html:tag( 'div' ):addClass( 'infobox__image-upload' )
			:wikitext( mw.ustring.format( '[[%s|%s]]', 'Special:UploadWizard', tostring( icon ) .. translate( 'LBL_upload_image' ) ) )
	end

	local item = tostring( html )

	table.insert( self.entries, item )

	return item
end


--- Return the HTML of the infobox indicator component as string
---
--- @param data table {data, desc, class)
--- @return string html
function methodtable.renderIndicator( self, data )
	checkType( 'Module:InfoboxNeue.renderIndicator', 1, self, 'table' )
	checkType( 'Module:InfoboxNeue.renderIndicator', 2, data, 'table' )

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
--- @param data table {title, subtitle, badge)
--- @return string html
function methodtable.renderHeader( self, data )
	checkType( 'Module:InfoboxNeue.renderHeader', 1, self, 'table' )
	checkTypeMulti( 'Module:InfoboxNeue.renderHeader', 2, data, { 'table', 'string' } )

	if type( data ) == 'string' then
		data = {
			title = data
		}
	end

	if data == nil or data[ 'title' ] == nil then return '' end

	local html = mw.html.create( 'div' ):addClass( 'infobox__header' )

	if data[ 'badge' ] then
		html:tag( 'div' )
			:addClass( 'infobox__item infobox__badge' )
			:wikitext( data[ 'badge' ] )
	end

	local titleItem = mw.html.create( 'div' ):addClass( 'infobox__item' )

	titleItem:tag( 'div' )
		:addClass( 'infobox__title' )
		:wikitext( data[ 'title' ] )

	if data[ 'subtitle' ] then
		titleItem:tag( 'div' )
			-- Subtitle is always data
			:addClass( 'infobox__subtitle infobox__data' )
			:wikitext( data[ 'subtitle' ] )
	end

	html:node( titleItem )

	local item = tostring( html )

	table.insert( self.entries, item )

	return item
end


--- Wrap the HTML into an infobox section
---
--- @param data table {title, subtitle, content, border, col, class}
--- @param noInsert boolean whether to insert this section into the internal table table
--- @return string html
function methodtable.renderSection( self, data, noInsert )
	checkType( 'Module:InfoboxNeue.renderSection', 1, self, 'table' )
	checkType( 'Module:InfoboxNeue.renderSection', 2, data, 'table' )
	checkType( 'Module:InfoboxNeue.renderSection', 3, noInsert, 'boolean', true )

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

	if data[ 'border' ] == false then html:addClass( 'infobox__section--noborder' ) end
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
	checkType( 'Module:InfoboxNeue.renderLinkButton', 1, self, 'table' )
	checkType( 'Module:InfoboxNeue.renderLinkButton', 2, data, 'table' )

	if data == nil or data[ 'label' ] == nil or ( data[ 'link' ] == nil and data[ 'page' ] == nil ) then return '' end

	--- Render multiple linkButton when link is a table
	if type( data[ 'link' ] ) == 'table' then
		local htmls = {}

		for i, url in ipairs( data[ 'link' ] ) do
			table.insert( htmls,
				self:renderLinkButton( {
					label = mw.ustring.format( '%s %d', data[ 'label' ], i ),
					link = url
				} )
			)
		end

		return table.concat( htmls )
	end

	local html = mw.html.create( 'div' ):addClass( 'infobox__linkButton' )

	if data[ 'link' ] then
		html:wikitext( mw.ustring.format( '[%s %s]', restoreUnderscore( data[ 'link' ] ), data[ 'label' ] ) )
	elseif data[ 'page' ] then
		html:wikitext( mw.ustring.format( '[[%s|%s]]', data[ 'page' ], data[ 'label' ] ) )
	end

	return tostring( html )
end

--- Return the HTML of the infobox footer component as string
---
--- @param data table {content, button}
--- @return string html
function methodtable.renderFooter( self, data )
	checkType( 'Module:InfoboxNeue.renderFooter', 1, self, 'table' )
	checkType( 'Module:InfoboxNeue.renderFooter', 2, data, 'table' )

	if data == nil then return '' end

    -- Checks if an input is of type 'table' or 'string' and if it is not empty
    local function isNonEmpty( input )
        return ( type( input ) == 'table' and next( input ) ~= nil ) or ( type( input ) == 'string' and #input > 0 )
    end

	local hasContent = isNonEmpty( data[ 'content' ] )
	local hasButton = isNonEmpty( data[ 'button' ] ) and isNonEmpty( data[ 'button' ][ 'content' ] ) and isNonEmpty( data[ 'button' ][ 'label' ] )

	if not hasContent and not hasButton then return '' end

	local html = mw.html.create( 'div' ):addClass( 'infobox__footer' )

	if hasContent then
		local content = data[ 'content' ]
		if type( content ) == 'table' then content = table.concat( content ) end

        html:addClass( 'infobox__footer--has-content')
        html:tag( 'div' )
            :addClass( 'infobox__section' )
            :wikitext( content )
	end

	if hasButton then
	    html:addClass( 'infobox__footer--has-button')
		local buttonData = data[ 'button' ];
		local button = html:tag( 'div' ):addClass( 'infobox__button' )
		local label = button:tag( 'div' ):addClass( 'infobox__buttonLabel' )

		if buttonData[ 'icon' ] ~= nil then
			label:wikitext( mw.ustring.format( '[[File:%s|16px|link=]]%s', buttonData[ 'icon' ], buttonData[ 'label' ] ) )
		else
			label:wikitext( buttonData[ 'label' ] )
		end

		if buttonData[ 'type' ] == 'link' then
			button:tag( 'div' )
				:addClass( 'infobox__buttonLink' )
				:wikitext( buttonData[ 'content' ] )
		elseif buttonData[ 'type' ] == 'popup' then
			button:tag( 'div' )
				:addClass( 'infobox__buttonCard' )
				:wikitext( buttonData[ 'content' ] )
		end
	end

	local item = tostring( html )

	table.insert( self.entries, item )

	return item
end


--- Return the HTML of the infobox footer button component as string
---
--- @param data table {icon, label, type, content}
--- @return string html
function methodtable.renderFooterButton( self, data )
	checkType( 'Module:InfoboxNeue.renderFooterButton', 1, self, 'table' )
	checkType( 'Module:InfoboxNeue.renderFooterButton', 2, data, 'table' )

	if data == nil then return '' end

	return self:renderFooter( { button = data } )
end


--- Return the HTML of the infobox item component as string
---
--- @param data table {label, data, desc, icon, row, spacebetween, colspan)
--- @param content string|number|nil optional
--- @return string html
function methodtable.renderItem( self, data, content )
	checkType( 'Module:InfoboxNeue.renderItem', 1, self, 'table' )
	checkTypeMulti( 'Module:InfoboxNeue.renderItem', 2, data, { 'table', 'string' } )
	checkTypeMulti( 'Module:InfoboxNeue.renderItem', 3, content, { 'string', 'number', 'nil' } )

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

	local textWrapper = html

	if data[ 'link' ] then
		html:addClass( 'infobox__itemButton' )
		html:tag( 'div' )
			:addClass( 'infobox__itemButtonLink' )
			:wikitext( mw.ustring.format( '[%s]', data[ 'link' ] ) )
	elseif data[ 'page' ] then
		html:addClass( 'infobox__itemButton' )
		html:tag( 'div' )
			:addClass( 'infobox__itemButtonLink' )
			:wikitext( mw.ustring.format( '[[%s]]', data[ 'link' ] ) )
	end

	if data[ 'icon' ] then
		html:addClass( 'infobox__item--hasIcon' )
		html:tag( 'div' )
			:addClass( 'infobox__icon' )
			:wikitext( mw.ustring.format( '[[File:%s|16px|link=]]', data[ 'icon' ] ) )
		-- Create wrapper for text to align with icon
		textWrapper = html:tag( 'div' ):addClass( 'infobox__text' )
	end

	local dataOrder = { 'label', 'data', 'desc' }

	for _, key in ipairs( dataOrder ) do
		if data[ key ] then
			if type( data[ key ] ) == 'table' then
				data[ key ] = table.concat( data[ key ], ', ' )
			end

			textWrapper:tag( 'div' )
				:addClass( 'infobox__' .. key )
				:wikitext( data[ key ] )
		end
	end

	-- Add arrow indicator as affordnance
	if data[ 'link' ] or data[ 'page' ] then
		html:tag( 'div' ):addClass( 'infobox__itemButtonArrow citizen-ui-icon mw-ui-icon-wikimedia-collapse' )
	end

	return tostring( html )
end


--- Wrap the infobox HTML
---
--- @param innerHtml string inner html of the infobox
--- @param snippetText string text used in snippet in mobile view
--- @return string html infobox html with templatestyles
function methodtable.renderInfobox( self, innerHtml, snippetText )
	checkType( 'Module:InfoboxNeue.renderInfobox', 1, self, 'table' )
	checkTypeMulti( 'Module:InfoboxNeue.renderInfobox', 2, innerHtml, { 'table', 'string', 'nil' } )
	checkType( 'Module:InfoboxNeue.renderInfobox', 3, snippetText, 'string', true )

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
				:wikitext( mw.ustring.format( '%s:', translate( 'LBL_quick_facts' ) ) )
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
	} .. table.concat( self.categories )
end


--- Just an accessor for the class method
function methodtable.showDescIfDiff( s1, s2 )
	return InfoboxNeue.showDescIfDiff( s1, s2 )
end


--- Format text to show comparison as desc text if two strings are different
---
--- @param s1 string|nil base
--- @param s2 string|nil comparsion
--- @return string|nil html
function InfoboxNeue.showDescIfDiff( s1, s2 )
    if s1 == nil or s2 == nil or s1 == s2 then return s1 end
    return mw.ustring.format( '%s <span class="infobox__desc">(%s)</span>', s1, s2 )
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
		categories = {},
		config = baseConfig,
		entries = {}
	}

    setmetatable( instance, metatable )

    return instance
end


--- Create an Infobox from args
---
--- @param frame table
--- @return string
function InfoboxNeue.fromArgs( frame )
	local instance = InfoboxNeue:new()
	local args = require( 'Module:Arguments' ).getArgs( frame )

	local sections = {
		{ content = {}, col = args[ 'col' ] or 2 }
	}

	local sectionMap = { default = 1 }

	local currentSection

	if args[ 'image' ] then
		instance:renderImage( args[ 'image' ] )
	end

	if args[ 'indicator' ] then
		instance:renderIndicator( {
			data = args[ 'indicator' ],
			desc = args[ 'indicatorDesc' ],
			class = args[ 'indicatorClass' ]
		} )
	end

	if args[ 'title' ] then
		instance:renderHeader( {
			title = args[ 'title' ],
			subtitle = args[ 'subtitle' ],
		} )
	end

	for i = 1, 50, 1 do
		if args[ 'section' .. i ] then
			currentSection = args[ 'section' .. i ]

			table.insert( sections, {
				title = currentSection,
				subtitle = args[ 'section-subtitle' .. i ],
				col = args[ 'section-col' .. i ] or args[ 'col' ] or 2,
				content = {}
			} )

			sectionMap[ currentSection ] = #sections
		end

		if args[ 'label' .. i ] and args[ 'content' .. i ] then
			table.insert( sections[ sectionMap[ ( currentSection or 'default' ) ] ].content, instance:renderItem( args[ 'label' .. i ], args[ 'content' .. i ] ) )
		end
	end

	for _, section in ipairs( sections ) do
		instance:renderSection( {
			title = section.title,
			subtitle = section.subtitle,
			col = section.col,
			content = section.content,
		} )
	end

	return instance:renderInfobox( nil, args[ 'snippet' ] )
end


return InfoboxNeue

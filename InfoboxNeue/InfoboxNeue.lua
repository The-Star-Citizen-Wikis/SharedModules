local InfoboxNeue = {}

local metatable = {}
local methodtable = {}

local libraryUtil = require( 'libraryUtil' )
local checkType = libraryUtil.checkType
local checkTypeMulti = libraryUtil.checkTypeMulti
local i18n = require( 'Module:i18n' ):new()

metatable.__index = methodtable

metatable.__tostring = function ( self )
	return tostring( self:renderInfobox() )
end


--- Wrapper function for Module:i18n.translate
---
--- @param key string The translation key
--- @return string If the key was not found, the key is returned
local function t( key )
	return i18n:translate( key )
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

-- TODO: Perhaps we should turn this into another module
local function getDetailsHTML( data, frame )
	local summary = frame:extensionTag {
		name = 'summary',
		content = data.summary.content,
		args = {
			class = data.summary.class
		}
	}
	local details = frame:extensionTag {
		name = 'details',
		content = summary .. data.details.content,
		args = {
			class = data.details.class,
			open = true
		}
	}
	return details
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

	formatNum = formatNum or false

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

	local hasPlaceholderImage = false

	if type( filename ) ~= 'string' and self.config.displayPlaceholder == true then
		hasPlaceholderImage = true
		filename = self.config.placeholderImage
		-- Add tracking category for infoboxes using placeholder image
		table.insert( self.categories,
			string.format( '[[Category:%s]]', t( 'category_infobox_using_placeholder_image' ) )
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
		:wikitext( string.format( '[[File:%s|400px]]', filename ) )

	if hasPlaceholderImage == true then
		local icon = mw.html.create( 'span' ):addClass( 'citizen-ui-icon mw-ui-icon-wikimedia-upload' )
		-- TODO: Point the Upload link to a specific file name
		html:tag( 'div' ):addClass( 'infobox__image-upload' )
			:wikitext( string.format( '[[%s|%s]]', 'Special:UploadWizard',
				tostring( icon ) .. t( 'label_upload_image' ) ) )
	end

	local item = tostring( html )

	table.insert( self.entries, item )

	return item
end

--- Return the HTML of the infobox indicator component as string
---
--- @param data table {data, class, tooltip, color)
--- @return string html
function methodtable.renderIndicator( self, data )
	checkType( 'Module:InfoboxNeue.renderIndicator', 1, self, 'table' )
	checkType( 'Module:InfoboxNeue.renderIndicator', 2, data, 'table' )

	if data == nil or data['data'] == nil or data['data'] == '' then return '' end

	local html = mw.html.create( 'div' ):addClass( 'infobox__indicators' )

	local htmlClasses = {
		'infobox__indicator'
	}

	if data['class'] then
		table.insert( htmlClasses, data['class'] )
	end

	if data['color'] then
		table.insert( htmlClasses, 'infobox__indicator--' .. data['color'] )
	end

	html:wikitext(
		self:renderItem(
			{
				['data'] = data['data'],
				['class'] = table.concat( htmlClasses, ' ' ),
				['tooltip'] = data.tooltip,
				row = true,
				spacebetween = true
			}
		)
	)

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

	if data == nil or data['title'] == nil then return '' end

	local html = mw.html.create( 'div' ):addClass( 'infobox__header' )

	if data['badge'] then
		html:tag( 'div' )
			:addClass( 'infobox__item infobox__badge' )
			:wikitext( data['badge'] )
	end

	local titleItem = mw.html.create( 'div' ):addClass( 'infobox__item' )

	titleItem:tag( 'div' )
		:addClass( 'infobox__title' )
		:wikitext( data['title'] )

	if data['subtitle'] then
		titleItem:tag( 'div' )
		-- Subtitle is always data
			:addClass( 'infobox__subtitle infobox__data' )
			:wikitext( data['subtitle'] )
	end

	html:node( titleItem )

	local item = tostring( html )

	table.insert( self.entries, item )

	return item
end

--- Wrap the HTML into an infobox section
---
--- @param data table {title, subtitle, content, border, col, class, contentClass}
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

	if data == nil or data['content'] == nil or data['content'] == '' then return '' end

	local html = mw.html.create( 'div' ):addClass( 'infobox__section' )

	if data['title'] then
		local header = html:tag( 'div' ):addClass( 'infobox__sectionHeader' )
		header:tag( 'div' )
			:addClass( 'infobox__sectionTitle' )
			:wikitext( data['title'] )
		if data['subtitle'] then
			header:tag( 'div' )
				:addClass( 'infobox__sectionSubtitle' )
				:wikitext( data['subtitle'] )
		end
	end

	local content = html:tag( 'div' )
	content:addClass( 'infobox__sectionContent' )
		:wikitext( data['content'] )

	if data['border'] == false then html:addClass( 'infobox__section--noborder' ) end
	if data['col'] then content:addClass( 'infobox__grid--cols-' .. data['col'] ) end
	if data['class'] then html:addClass( data['class'] ) end
	if data['contentClass'] then content:addClass( data['contentClass'] ) end

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

	if data == nil or data['label'] == nil or (data['link'] == nil and data['page'] == nil) then return '' end

	--- Render multiple linkButton when link is a table
	if type( data['link'] ) == 'table' then
		local htmls = {}

		for i, url in ipairs( data['link'] ) do
			table.insert( htmls,
				self:renderLinkButton( {
					label = string.format( '%s %d', data['label'], i ),
					link = url
				} )
			)
		end

		return table.concat( htmls )
	end

	local html = mw.html.create( 'div' ):addClass( 'infobox__linkButton' )

	if data['link'] then
		html:wikitext( string.format( '[%s %s]', restoreUnderscore( data['link'] ), data['label'] ) )
	elseif data['page'] then
		html:wikitext( string.format( '[[%s|%s]]', data['page'], data['label'] ) )
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
		return (type( input ) == 'table' and next( input ) ~= nil) or (type( input ) == 'string' and #input > 0)
	end

	local hasContent = isNonEmpty( data['content'] )
	local hasButton = isNonEmpty( data['button'] ) and isNonEmpty( data['button']['content'] ) and
		isNonEmpty( data['button']['label'] )

	if not hasContent and not hasButton then return '' end

	local html = mw.html.create( 'div' ):addClass( 'infobox__footer' )

	if hasContent then
		local content = data['content']
		if type( content ) == 'table' then content = table.concat( content ) end

		html:addClass( 'infobox__footer--has-content' )
		html:tag( 'div' )
			:addClass( 'infobox__section' )
			:wikitext( content )
	end

	if hasButton then
		html:addClass( 'infobox__footer--has-button' )
		local buttonData = data['button']
		local button = html:tag( 'div' ):addClass( 'infobox__button' )
		local label = button:tag( 'div' ):addClass( 'infobox__buttonLabel' )

		if buttonData['icon'] ~= nil then
			label:wikitext( string.format( '[[File:%s|16px|link=]]%s', buttonData['icon'], buttonData['label'] ) )
		else
			label:wikitext( buttonData['label'] )
		end

		if buttonData['type'] == 'link' then
			button:tag( 'div' )
				:addClass( 'infobox__buttonLink' )
				:wikitext( buttonData['content'] )
		elseif buttonData['type'] == 'popup' then
			button:tag( 'div' )
				:addClass( 'infobox__buttonCard' )
				:wikitext( buttonData['content'] )
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

--- Helper function to render icon element within an infobox item
--- @param html table The HTML builder object
--- @param icon string The icon filename
--- @return table The text wrapper element
local function renderItemIconElement( html, icon )
	html:addClass( 'infobox__item--hasIcon' )
	html:tag( 'div' )
		:addClass( 'infobox__icon' )
		:wikitext( string.format( '[[File:%s|16px|link=]]', icon ) )
		:done()
	return html:tag( 'div' ):addClass( 'infobox__text' )
end

--- Helper function to render link elements within an infobox item
--- @param html table The HTML builder object
--- @param data table The data containing link information
local function renderItemLinkElements( html, data )
	if data.link then
		html:addClass( 'infobox__itemButton' )
		html:tag( 'div' )
			:addClass( 'infobox__itemButtonLink' )
			:wikitext( string.format( '[%s]', data.link ) )
			:done()
	elseif data.page then
		html:addClass( 'infobox__itemButton' )
		html:tag( 'div' )
			:addClass( 'infobox__itemButtonLink' )
			:wikitext( string.format( '[[%s]]', data.link ) )
			:done()
	end
end

--- Helper function to render text elements within an infobox item
--- @param wrapper table The HTML wrapper element
--- @param data table The data containing text elements
local function renderItemTextElements( wrapper, data )
	local dataOrder = { 'label', 'data', 'desc' }
	for _, key in ipairs( dataOrder ) do
		if data[key] then
			if type( data[key] ) == 'table' then
				data[key] = table.concat( data[key], ', ' )
			end
			wrapper:tag( 'div' )
				:addClass( 'infobox__' .. key )
				:wikitext( data[key] )
		end
	end
end

--- Return the HTML of the infobox item component as string
--- @param data table {label, data, desc, class, tooltip, icon, row, spacebetween, colspan}
--- @param content string|number|nil optional
--- @return string html
function methodtable.renderItem( self, data, content )
	checkType( 'Module:InfoboxNeue.renderItem', 1, self, 'table' )
	checkTypeMulti( 'Module:InfoboxNeue.renderItem', 2, data, { 'table', 'string' } )
	checkTypeMulti( 'Module:InfoboxNeue.renderItem', 3, content, { 'string', 'number', 'nil' } )

	-- Handle simplified parameter format
	if content ~= nil then
		data = {
			label = data,
			data = content
		}
	end

	-- Skip empty items
	if data == nil or data.data == nil or data.data == '' then return '' end
	if self.config.removeEmpty == true and data.data == self.config.emptyString then
		return ''
	end

	-- Create base HTML structure
	local html = mw.html.create( 'div' ):addClass( 'infobox__item' )

	-- Add classes based on configuration
	if data.class then html:addClass( data.class ) end
	if data.row == true then html:addClass( 'infobox__grid--row' ) end
	if data.spacebetween == true then html:addClass( 'infobox__grid--space-between' ) end
	if data.colspan then html:addClass( 'infobox__grid--col-span-' .. data.colspan ) end

	-- Create link elements if needed
	renderItemLinkElements( html, data )

	-- Handle icon and text wrapper
	local textWrapper = data.icon and renderItemIconElement( html, data.icon ) or html

	-- Render text elements
	renderItemTextElements( textWrapper, data )

	-- Add arrow indicator for links
	if data.link or data.page then
		html:tag( 'div' )
			:addClass( 'infobox__itemButtonArrow citizen-ui-icon mw-ui-icon-wikimedia-collapse' )
			:done()
	end

	-- Linter does not like data.range.end
	if data.range then
		html:addClass( 'infobox__item--is-range' )
			:tag( 'div' )
			:addClass( 'infobox__bar' )
			:tag( 'div' )
			:addClass( 'infobox__bar-item' )
			:css( '--infobox-bar-item-range-start', data.range['start'] )
			:css( '--infobox-bar-item-range-end', data.range['end'] )
			:allDone()
	end

	-- Handle tooltip if present
	if data.tooltip then
		self.modules.FloatingUI = self.modules.FloatingUI or require( 'Module:FloatingUI' )
		html:addClass( 'infobox__item--has-tooltip' )
		return self.modules.FloatingUI.render( tostring( html ), data.tooltip )
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

	local function renderContent()
		local html = mw.html.create( 'div' )
			:addClass( 'infobox__content' )
			:wikitext( innerHtml )
		return tostring( html )
	end

	local function renderSnippet()
		if snippetText == nil then snippetText = mw.title.getCurrentTitle().text end

		local html = mw.html.create()

		html:tag( 'div' )
			:addClass( 'citizen-ui-icon mw-ui-icon-wikimedia-collapse' )
			:done()
			:tag( 'div' )
			:addClass( 'infobox__data' )
			:wikitext( string.format( '%s:', t( 'label_quick_facts' ) ) )
			:done()
			:tag( 'div' )
			:addClass( 'infobox__desc' )
			:wikitext( snippetText )

		return tostring( html )
	end

	local frame = mw.getCurrentFrame()
	local output = getDetailsHTML( {
		details = {
			class = 'infobox floatright',
			content = renderContent()
		},
		summary = {
			class = 'infobox__snippet',
			content = renderSnippet()
		}
	}, frame )

	if self.modules.FloatingUI then
		output = self.modules.FloatingUI.load( frame ) .. output
	end

	return frame:extensionTag {
		name = 'templatestyles', args = { src = 'Module:InfoboxNeue/styles.css' }
	} .. output .. table.concat( self.categories )
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
		baseConfig[k] = v
	end

	local instance = {
		categories = {},
		config = baseConfig,
		entries = {},
		modules = {
			FloatingUI = nil
		}
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
		{ content = {}, col = args['col'] or 2 }
	}

	local sectionMap = { default = 1 }

	local currentSection

	if args['image'] then
		instance:renderImage( args['image'] )
	end

	if args['indicator'] then
		instance:renderIndicator( {
			data = args['indicator'],
			class = args['indicatorClass']
		} )
	end

	if args['title'] then
		instance:renderHeader( {
			title = args['title'],
			subtitle = args['subtitle'],
		} )
	end

	for i = 1, 50, 1 do
		if args['section' .. i] then
			currentSection = args['section' .. i]

			table.insert( sections, {
				title = currentSection,
				subtitle = args['section-subtitle' .. i],
				col = args['section-col' .. i] or args['col'] or 2,
				content = {}
			} )

			sectionMap[currentSection] = #sections
		end

		if args['label' .. i] and args['content' .. i] then
			table.insert( sections[sectionMap[(currentSection or 'default')]].content,
				instance:renderItem( args['label' .. i], args['content' .. i] ) )
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

	return instance:renderInfobox( nil, args['snippet'] )
end

return InfoboxNeue

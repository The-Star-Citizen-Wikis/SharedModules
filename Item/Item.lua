require( 'strict' )

local Item = {}

local metatable = {}
local methodtable = {}

metatable.__index = methodtable

local TNT = require( 'Module:Translate' ):new()
local common = require( 'Module:Common' )
local manufacturer = require( 'Module:Manufacturer' )._manufacturer
local hatnote = require( 'Module:Hatnote' )._hatnote
local data = mw.loadJsonData( 'Module:Item/data.json' )
local config = mw.loadJsonData( 'Module:Item/config.json' )

local lang
if config.module_lang then
	lang = mw.getLanguage( config.module_lang )
else
	lang = mw.getContentLanguage()
end


--- FIXME: This should go to somewhere else, like Module:Common
--- Calls TNT with the given key
---
--- @param key string The translation key
--- @param addSuffix boolean Adds a language suffix if config.smw_multilingual_text is true
--- @return string If the key was not found in the .tab page, the key is returned
local function translate( key, addSuffix, ... )
    addSuffix = addSuffix or false
    local success, translation

    local function multilingualIfActive( input )
        if addSuffix and config.smw_multilingual_text == true then
            return string.format( '%s@%s', input, config.module_lang or mw.getContentLanguage():getCode() )
        end

        return input
    end

    if config.module_lang ~= nil then
        success, translation = pcall( TNT.formatInLanguage, config.module_lang, 'Module:Item/i18n.json', key or '', ... )
    else
        success, translation = pcall( TNT.format, 'Module:Item/i18n.json', key or '', ... )
    end

    if not success or translation == nil then
        return multilingualIfActive( key )
    end

    return multilingualIfActive( translation )
end


--- Creates the object that is used to query the SMW store
---
--- @param page string the item page containing data
--- @return table
local function makeSmwQueryObject( page )
    local langSuffix = ''
    if config.smw_multilingual_text == true then
        langSuffix = '+lang=' .. ( config.module_lang or mw.getContentLanguage():getCode() )
    end

	local query = {
		string.format( '[[%s]]', page ),
		'?Page image#-=image'
	}

	for _, queryPart in pairs( data.smw_data ) do
		local smwKey
		for key, _ in pairs( queryPart ) do
			if string.sub( key, 1, 3 ) == 'SMW' then
				smwKey = key
				break
			end
		end

		local formatString = '?%s'

		if queryPart.smw_format then
			formatString = formatString .. queryPart.smw_format
		end

		-- safeguard
		if smwKey ~= nil then
			table.insert( query, string.format( formatString, translate( smwKey ) ) )

			if queryPart.type == 'multilingual_text' then
				table.insert( query, langSuffix )
			end
		end
	end

	table.insert( query, 'limit=1' )

	return query
end


--- Request Api Data
--- Using current subpage name without item type suffix
--- @return table or nil
function methodtable.getApiDataForCurrentPage( self )
	local api = require( 'Module:Common/Api' )

	local query = self.frameArgs[ translate( 'ARG_UUID' ) ] or self.frameArgs[ translate( 'ARG_Name' ) ] or common.removeTypeSuffix(
        mw.title.getCurrentTitle().rootText,
		config.name_suffixes
    )

	local success, json = pcall( mw.text.jsonDecode, mw.ext.Apiunto.get_raw( 'v2/items/' .. query, {
		include = data.includes,
		locale = config.api_locale
	} ) )

	if not success or api.checkResponseStructure( json, true, false ) == false then return end

    self.apiData = json[ 'data' ]
    self.apiData = api.makeAccessSafe( self.apiData )

    return self.apiData
end


--- Base Properties that are shared across all items
--- @return table SMW Result
function methodtable.setSemanticProperties( self )
	local setData = {}

	--- Retrieve value(s) from the frame
	---
	--- @param datum table An entry from data.smw_data
	--- @param argKey string The key to use as an accessor to frameArgs
	--- @return string|number|table|nil
	local function getFromArgs( datum, argKey )
		local value
		-- Numbered parameters, e.g. URL1, URL2, URL3, etc.
		if datum.type == 'range' and type( datum.max ) == 'number' then
			value = {}

			for i = 1, datum.max do
				local argValue = self.frameArgs[ argKey .. i ]
				if argValue then table.insert( value, argValue ) end
			end
		-- A "simple" arg
		else
			value = self.frameArgs[ argKey ]
		end

		return value
	end

	-- Iterate through the list of SMW attributes that shall be filled
	for _, datum in ipairs( data.smw_data ) do
		-- Retrieve the SMW key and from where the data should be pulled
		local smwKey, from
		for key, get_from in pairs( datum ) do
			if string.sub( key, 1, 3 ) == 'SMW' then
				smwKey = key
				from = get_from
			end
		end

		smwKey = translate( smwKey )

		if type( from ) ~= 'table' then
			from = { from }
		end

		-- Iterate the list of data sources in order, later sources override previous ones
		-- I.e. if the list is Frame Args, API; The api will override possible values set from the frame
		for _, key in ipairs( from ) do
			local parts = mw.text.split( key, '_', true )
			local value

			-- Re-assemble keys with multiple '_'
			if #parts > 2 then
				local tmp = parts[ 1 ]
				table.remove( parts, 1 )
				parts = {
					tmp,
					table.concat( parts, '_' )
				}
			end

			mw.logObject( parts, 'Key Parts' )

			-- safeguard check if we have two parts
			if #parts == 2 then
				-- Retrieve data from frameArgs
				if parts[ 1 ] == 'ARG' then
					value = getFromArgs( datum, translate( key ) )

					-- Use EN lang as fallback for arg names that are empty
					if value == nil then
						local success, translation = pcall( TNT.formatInLanguage, 'en', 'Module:Item/i18n.json', key )
						if success then
							value = getFromArgs( datum, translation )
						end
					end
				-- Retrieve data from API
				elseif parts[ 1 ] == 'API' and self.apiData ~= nil then
					mw.logObject({
						key_access = parts[2],
						value = self.apiData:get( parts[ 2 ] )
					})

					value = self.apiData:get( parts[ 2 ] )
				end
			end

			-- Transform value based on 'format' key
			if value ~= nil then
				if type( value ) ~= 'table' then
					value = { value }
				end

				for index, val in ipairs( value ) do
					-- This should not happen
					if type( val ) == 'table' then
						val = string.format( '!ERROR! Key %s is a table value; please fix', key )
					end

					-- Format number for SMW
					if datum.type == 'number' then
						val = common.formatNum( val )
					-- Multilingual Text, add a suffix
					elseif datum.type == 'multilingual_text' and config.smw_multilingual_text == true then
						val = string.format( '%s@%s', val, config.module_lang or mw.getContentLanguage():getCode() )
					-- Num format
					elseif datum.type == 'number' then
						val = common.formatNum( val )
					-- String format
					elseif type( datum.format ) == 'string' then
						if string.find( datum.format, '%', 1, true  ) then
							val = string.format( datum.format, val )
						elseif datum.format == 'ucfirst' then
							val = lang:ucfirst( val )
						elseif datum.format == 'replace-dash' then
							val = string.gsub( val, '%-', ' ' )
						end
					end

					table.remove( value, index )
					table.insert( value, index, val )
				end

				if type( value ) == 'table' and #value == 1 then
					value = value[ 1 ]
				end

				setData[ smwKey ] = value
			end
		end
	end

	setData[ translate( 'SMW_Name' ) ] = self.frameArgs[ translate( 'ARG_Name' ) ] or common.removeTypeSuffix(
		mw.title.getCurrentTitle().rootText,
		config.name_suffixes
	)

	if type( setData[ translate( 'SMW_Manufacturer' ) ] ) == 'string' then
		local man = manufacturer( setData[ translate( 'SMW_Manufacturer' ) ] )
		if man ~= nil then man = man.name end

		setData[ translate( 'SMW_Manufacturer' ) ] = man or setData[ translate( 'SMW_Manufacturer' ) ]
		setData[ translate( 'SMW_Manufacturer' ) ] = string.format( '[[%s]]', setData[ translate( 'SMW_Manufacturer' ) ] )
	end

	-- Set properties with API data
    if self.apiData ~= nil and self.apiData.uuid ~= nil then
		--- Commodity
		local commodity = require( 'Module:Commodity' ):new()
		commodity:addShopData( self.apiData )
	end

	mw.logObject( setData, 'SET' )

	self.setData = setData

	return mw.smw.set( setData )
end


--- Queries the SMW Store
--- @return table
function methodtable.getSmwData( self )
	-- Cache multiple calls
    if self.smwData ~= nil and self.smwData[ translate( 'SMW_Name' ) ] ~= nil then
        return self.smwData
    end

	local queryName = self.frameArgs[ translate( 'ARG_SmwQueryName' ) ] or
					  self.frameArgs[ translate( 'ARG_Name' ) ] or
					  mw.title.getCurrentTitle().fullText

    local smwData = mw.smw.ask( makeSmwQueryObject( queryName ) )

    if smwData == nil or smwData[ 1 ] == nil then
		return hatnote( string.format(
				'%s[[%s]]',
				translate( 'error_no_data_text' ),
				translate( 'error_script_error_cat' )
			),
			{ icon = 'WikimediaUI-Error.svg' }
		)
    end

    self.smwData = smwData[ 1 ]

    return self.smwData
end

--- Creates the infobox
function methodtable.getInfobox( self )
	local smwData = self:getSmwData()

	local infobox = require( 'Module:InfoboxNeue' ):new( {
		placeholderImage = config.placeholder_image
	} )
	local tabber = require( 'Module:Tabber' ).renderTabber

	--- SMW Data load error
	--- Infobox data should always have Name property
	if type( smwData ) ~= 'table' then
		return infobox:renderInfobox( infobox:renderMessage( {
			title = translate( 'error_no_data_title' ),
			desc = translate( 'error_no_data_text' ),
		} ) )
	end

	local function getManufacturer()
		if smwData[ translate( 'SMW_Manufacturer' ) ] == nil then return end

		local mfu = manufacturer( smwData[ translate( 'SMW_Manufacturer' ) ] )
		if mfu == nil then return smwData[ translate( 'SMW_Manufacturer' ) ] end

		return infobox.showDescIfDiff(
			table.concat( { '[[', smwData[ translate( 'SMW_Manufacturer' ) ], '|', mfu.name , ']]' } ),
			mfu.code
		)
	end

	local function getSize()
		if smwData[ translate( 'SMW_Size' ) ] == nil then return end
		return 'S' .. smwData[ translate( 'SMW_Size' ) ]
	end

	local function getClass()
		if smwData[ translate( 'SMW_Class' ) ] == nil then return end

		local class = smwData[ translate( 'SMW_Class' ) ]
	
		if smwData[ translate( 'SMW_Grade' ) ] ~= nil then
			class = class .. ' (' .. smwData[ translate( 'SMW_Grade' ) ] .. ')'
		end

		return class
	end

	--- Other sites
	local function getOfficialSites()
		local links = {}

		for _, site in ipairs( data.official_sites ) do
			local query = smwData[ translate( site.attribute ) ]

			if query ~= nil then
				table.insert( links, infobox:renderLinkButton( {
					label = translate( site.label ),
					link = query
				} ) )
			end
		end

		return links
	end

	local function getCommunitySites()
		local links = {}

		for _, site in ipairs( data.community_sites ) do
			local query = smwData[ translate( site.data ) ]

			if query ~= nil then
				if site.data == 'SMW_ClassName' or site.data == 'SMW_UUID' then
					query = string.lower( query )
				elseif site.data == 'SMW_ShipMatrixName' then
					query = mw.uri.encode( query, 'PATH' )
				end

				if site.label == 'FleetYards' then
					query = string.lower( string.gsub( query, '%%20', '-' ) )
				end

				table.insert( links, infobox:renderLinkButton( {
					label = site.label,
					link = string.format( site.format, query )
				} ) )
			end
		end

		return links
	end


	local image = self.frameArgs[ translate( 'ARG_Image' ) ] or self.frameArgs[ 'image' ] or smwData[ 'image' ]
	infobox:renderImage( image )

	infobox:renderHeader( {
		title = smwData[ translate( 'SMW_Name' ) ],
		--- e.g. Aegis Dynamics (AEGS)
		subtitle = getManufacturer()
	} )


	--- Size, Class, Health
	infobox:renderSection( {
		content = {
			infobox:renderItem( {
				label = translate( 'LBL_Size' ),
				data = getSize(),
			} ),
			infobox:renderItem( {
				label = translate( 'LBL_Class' ),
				data = getClass(),
			} ),
			infobox:renderItem( {
				label = translate( 'LBL_Occupancy' ),
				data = smwData[ translate( 'SMW_Occupancy' ) ],
			} ),
			infobox:renderItem( {
				label = translate( 'LBL_Health' ),
				data = smwData[ translate( 'SMW_HealthPoint' ) ],
			} ),
		},
		col = 2
	} )

	--- Footer
	infobox:renderFooterButton( {
		icon = 'WikimediaUI-Globe.svg',
		label = translate( 'LBL_OtherSites' ),
		type = 'popup',
		content = infobox:renderSection( {
			content = {
				infobox:renderItem( {
					label = translate( 'LBL_OfficialSites' ),
					data = table.concat( getOfficialSites(), '' )
				} ),
				infobox:renderItem( {
					label = translate( 'LBL_CommunitySites' ),
					data = table.concat( getCommunitySites(), '' )
				} ),
			},
			class = 'infobox__section--linkButtons',
		}, true )
	} )

	return infobox:renderInfobox( nil, smwData[ translate( 'SMW_Name' ) ] )
end

--- Set the frame and load args
--- @param frame table
function methodtable.setFrame( self, frame )
	self.currentFrame = frame
	self.frameArgs = require( 'Module:Arguments' ).getArgs( frame )
end


--- Save Api Data to SMW store
function methodtable.saveApiData( self )
    self:getApiDataForCurrentPage()
    self:setSemanticProperties()
end


--- Generates debug output
function methodtable.makeDebugOutput( self )
	local debug = require( 'Module:Common/Debug' )

	self.smwData = nil
	local smwData = self:getSmwData()

	local queryName = self.frameArgs[ translate( 'ARG_SmwQueryName' ) ] or
					  self.frameArgs[ translate( 'ARG_Name' ) ] or
					  mw.title.getCurrentTitle().fullText

	return debug.collapsedDebugSections({
		{
			title = 'SMW Query',
			content = debug.convertSmwQueryObject( makeSmwQueryObject( queryName ) ),
		},
		{
			title = 'SMW Data',
			content = smwData,
			tag = 'pre',
		},
		{
			title = 'Frame Args',
			content = self.frameArgs,
			tag = 'pre',
		},
	})
end


--- New Instance
function Item.new( self )
    local instance = {
        categories = {}
    }

    setmetatable( instance, metatable )

    return instance
end


--- Load data from api.star-citizen.wiki and save it to SMW
---
--- @param frame table Invocation frame
--- @return string|nil
function Item.loadApiData( frame )
	local instance = Item:new()
	instance:setFrame( frame )
	instance:saveApiData()

	local debugOutput
	if instance.frameArgs[ 'debug' ] ~= nil then
		local debug = require( 'Module:Common/Debug' )

		debugOutput = debug.collapsedDebugSections({
			{
				title = 'SMW Set Data',
				content = mw.getCurrentFrame():callParserFunction( '#tag', { 'nowiki', mw.dumpObject( instance.setData or {} ) } ),
			},
		})
	end

	return debugOutput
end

--- Generates an infobox based on passed frame args and SMW data
---
--- @param frame table Invocation frame
--- @return string
function Item.infobox( frame )
	local instance = Item:new()
	instance:setFrame( frame )

	local debugOutput = ''
	if instance.frameArgs[ 'debug' ] ~= nil then
		debugOutput = instance:makeDebugOutput()
	end

	return tostring( instance:getInfobox() ) .. debugOutput
end

--- "Main" entry point for templates that saves the API Data and outputs the infobox
---
--- @param frame table Invocation frame
--- @return string
function Item.main( frame )
	local instance = Item:new()
	instance:setFrame( frame )
	instance:saveApiData()

	local debugOutput = ''
	if instance.frameArgs[ 'debug' ] ~= nil then
		debugOutput = instance:makeDebugOutput()
	end
end


---
function Item.test( page )
	page = page or 'Cirrus'

	local instance = Item:new()
	instance.frameArgs = {}
	instance.frameArgs[ translate( 'ARG_Name' ) ] = page

	instance:saveApiData()
end


return Item

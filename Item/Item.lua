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
	local query = {
		string.format( '[[%s]]', page ),
		'?Page image#-=image'
	}

	require( 'Module:Common/SMW' ).addSmwQueryParams(
		query,
		translate,
		config,
		data
	)

	for _, module in pairs( data.extension_modules ) do
		local success, mod = pcall( require, module )
		if success then
			mod:new():addSmwAskProperties( query )
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

	local smwCommon = require( 'Module:Common/SMW' )

	smwCommon.addSmwProperties(
		self.apiData,
		self.frameArgs,
		setData,
		translate,
		config,
		data,
		'Item'
	)

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

	for _, module in pairs( data.extension_modules ) do
		if module.type ~= nil and type( module.type ) == 'table' then
			for _, type in pairs( module.type ) do
				if setData[ translate( 'SMW_Type' ) ] == type then
					local success, mod = pcall( require, module.name )
					if success then
						mod:new( self.apiData, self.frameArgs ):addSmwProperties( setData )
					end
					break
				end
			end
		end
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
		if mfu == nil then return '[[' .. smwData[ translate( 'SMW_Manufacturer' ) ] .. ']]' end

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


	--- Type, Size, Class, Health
	infobox:renderSection( {
		content = {
			infobox:renderItem( {
				label = translate( 'LBL_Type' ),
				data = smwData[ translate( 'SMW_Type' ) ],
			} ),
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

	for _, module in pairs( data.extension_modules ) do
		local success, mod = pcall( require, module )
		if success then
			mod:new():addInfoboxData( infobox, smwData )
		end
	end

	--- Dimensions
	infobox:renderSection( {
		title = translate( 'LBL_Dimensions' ),
		content = {
			infobox:renderItem( {
				label = translate( 'LBL_Length' ),
				data = smwData[ translate( 'SMW_EntityLength' ) ],
			} ),
			infobox:renderItem( {
				label = translate( 'LBL_Width' ),
				data = smwData[ translate( 'SMW_EntityWidth' ) ],
			} ),
			infobox:renderItem( {
				label = translate( 'LBL_Height' ),
				data = smwData[ translate( 'SMW_EntityHeight' ) ],
			} )
		},
		col = 3
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

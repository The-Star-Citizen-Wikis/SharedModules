require( 'strict' )

local Faction = {}

local metatable = {}
local methodtable = {}

metatable.__index = methodtable

local i18n = require( 'Module:i18n' ):new()
local TNT = require( 'Module:Translate' ):new()
local common = require( 'Module:Common' )
local hatnote = require( 'Module:Hatnote' )._hatnote
local data = mw.loadJsonData( 'Module:Faction/data.json' )
local config = mw.loadJsonData( 'Module:Faction/config.json' )

local lang
if config.module_lang then
	lang = mw.getLanguage( config.module_lang )
else
	lang = mw.getContentLanguage()
end


--- Wrapper function for Module:i18n.translate
---
--- @param key string The translation key
--- @return string If the key was not found, the key is returned
local function t( key )
	return i18n:translate( key )
end

--- Wrapper function for Module:Translate.translate
---
--- @param key string The translation key
--- @param addSuffix boolean|nil Adds a language suffix if config.smw_multilingual_text is true
--- @return string If the key was not found in the .tab page, the key is returned
local function translate( key, addSuffix, ... )
	return TNT:translate( 'Module:Faction/i18n.json', config, key, addSuffix, {...} ) or key
end


--- Creates the object that is used to query the SMW store
---
--- @param page string the faction page containing data
--- @return table
local function makeSmwQueryObject( page )
	local query = {
		string.format( '[[%s]]', page ),
		'?Page image#-=image'
	}

	require( 'Module:Common/SMW' ).addSmwAskProperties(
		query,
		translate,
		config,
		data
	)

	table.insert( query, 'limit=1' )

	return query
end


--- Request Api Data
--- Using current subpage name without item type suffix
--- @return table|nil
function methodtable.getApiDataForCurrentPage( self )
	local api = require( 'Module:Common/Api' )

	local query = self.frameArgs[ translate( 'ARG_UUID' ) ] or self.frameArgs[ translate( 'ARG_Name' ) ] or common.removeTypeSuffix(
        mw.title.getCurrentTitle().text,
		config.name_suffixes
    )

	local success, json = pcall( mw.text.jsonDecode, mw.ext.Apiunto.get_raw( 'v2/factions/' .. query, {
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
		'Faction'
	)

	setData[ t( 'SMW_Name' ) ] = self.frameArgs[ translate( 'ARG_Name' ) ] or common.removeTypeSuffix(
		mw.title.getCurrentTitle().text,
		config.name_suffixes
	)

	--mw.logObject( setData, 'SET' )

	self.setData = setData

	return mw.smw.set( setData )
end


--- Queries the SMW Store
--- @return table
function methodtable.getSmwData( self )
	-- Use cached data if possible, SMW queries are expensive
	if self.smwData ~= nil and self.smwData[ t( 'SMW_Name' ) ] ~= nil then
        return self.smwData
    end

	local queryName = self.frameArgs[ translate( 'ARG_SmwQueryName' ) ] or
					  mw.title.getCurrentTitle().fullText

    local smwData = mw.smw.ask( makeSmwQueryObject( queryName ) )

    if smwData == nil or smwData[ 1 ] == nil then
		return hatnote( mw.ustring.format(
				'%s[[%s]]',
				t( 'message_error_no_data_text' ),
				t( 'message_error_category_script_error' )
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

	--mw.logObject( smwData, 'infoboxSmwData' )

	--- SMW Data load error
	--- Infobox data should always have Name property
	if type( smwData ) ~= 'table' then
		return infobox:renderInfobox( infobox:renderMessage( {
			title = t( 'message_error_no_infobox_data_title' ),
			desc = t( 'message_error_no_data_text' ),
		} ) )
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
					query = mw.ustring.lower( query )
				end

				table.insert( links, infobox:renderLinkButton( {
					label = site.label,
					link = mw.ustring.format( site.format, query )
				} ) )
			end
		end

		return links
	end


	local image = self.frameArgs[ translate( 'ARG_Image' ) ] or self.frameArgs[ 'image' ] or smwData[ 'image' ]
	infobox:renderImage( image )

	infobox:renderHeader( {
		title = smwData[ t( 'SMW_Name' ) ],
		subtitle = smwData[ t( 'SMW_Default_Reaction' ) ]
	} )

	--- Metadata section
	infobox:renderSection( {
		class = 'infobox__section--metadata infobox__section--hasBackground',
		content = {
			infobox:renderItem( {
				label = t( 'SMW_UUID' ),
				data = smwData[ t( 'SMW_UUID' ) ],
				row = true,
				spacebetween = true
			} ),
			infobox:renderItem( {
				label = t( 'SMW_ClassName' ),
				data = smwData[ t( 'SMW_ClassName' ) ],
				row = true,
				spacebetween = true
			} )
		}
	} )

	--- Footer
	infobox:renderFooter( {
		button = {
			icon = 'WikimediaUI-Globe.svg',
			label = t( 'label_OtherSites' ),
			type = 'popup',
			content = infobox:renderSection( {
				content = {
					infobox:renderItem( {
						label = t( 'label_OfficialSites' ),
						data = table.concat( getOfficialSites(), '' )
					} ),
					infobox:renderItem( {
						label = t( 'label_CommunitySites' ),
						data = table.concat( getCommunitySites(), '' )
					} ),
				},
				class = 'infobox__section--linkButtons',
			}, true )
		}
	} )

	return infobox:renderInfobox( nil, smwData[ t( 'SMW_Name' ) ] )
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
function Faction.new( self )
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
function Faction.loadApiData( frame )
	local instance = Faction:new()
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
function Faction.infobox( frame )
	local instance = Faction:new()
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
function Faction.main( frame )
	local instance = Faction:new()
	instance:setFrame( frame )
	instance:saveApiData()

	local debugOutput = ''
	local interwikiLinks = ''

	if instance.frameArgs[ 'debug' ] ~= nil then
		debugOutput = instance:makeDebugOutput()
	end

	local infobox = tostring( instance:getInfobox() )

	if instance.smwData ~= nil then
		interwikiLinks = common.generateInterWikiLinks( mw.title.getCurrentTitle().text )
	end

	return infobox .. debugOutput .. interwikiLinks
end


---
function Faction.test( page )
	page = page or 'XenoThreat'

	local instance = Faction:new()
	instance.frameArgs = {}
	instance.frameArgs[ translate( 'ARG_Name' ) ] = page
	instance.frameArgs[ translate( 'ARG_SmwQueryName' ) ] = page

	instance:saveApiData()
	instance:getInfobox()
end


return Faction

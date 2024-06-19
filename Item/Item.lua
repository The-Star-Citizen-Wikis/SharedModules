require( 'strict' )

local Item = {}

local metatable = {}
local methodtable = {}

metatable.__index = methodtable

local i18n = require( 'Module:i18n' ):new()
local TNT = require( 'Module:Translate' ):new()
local common = require( 'Module:Common' )
local manufacturer = require( 'Module:Manufacturer' ):new()
local hatnote = require( 'Module:Hatnote' )._hatnote
local data = mw.loadJsonData( 'Module:Item/data.json' )
local config = mw.loadJsonData( 'Module:Item/config.json' )

local lang
if config.module_lang then
	lang = mw.getLanguage( config.module_lang )
else
	lang = mw.getContentLanguage()
end

local moduleCache = {}


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
	return TNT:translate( 'Module:Item/i18n.json', config, key, addSuffix, {...} ) or key
end


--- Invokes a method on the required module, if the modules type matches targetType
--- Utilizes the moduleCache to only load modules once
---
--- @param targetType string|boolean The type to check against extension_modules.type or 'true' to run against all modules
--- @param methodName string The method to invoke
--- @param args table Arguments passed to the method
local function runModuleFN( targetType, methodName, args, returnsData )
	returnsData = returnsData or false
	for _, module in ipairs( data.extension_modules ) do
		if targetType == true or ( module.type ~= nil and type( module.type ) == 'table' ) then
			for _, type in ipairs( module.type ) do
				if module ~= nil and ( targetType == true or targetType == type ) then
					if moduleCache[ module.name ] == nil then
						local success, mod = pcall( require, module.name )
						if success then
							moduleCache[ module.name ] = mod
						end
					end
					module = moduleCache[ module.name ]

					if module ~= nil then
						local result = module[ methodName ]( unpack( args ) )
						if returnsData then
							return result
						end
					end
				end
			end
		end
	end
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

	require( 'Module:Common/SMW' ).addSmwAskProperties(
		query,
		translate,
		config,
		data
	)

	runModuleFN( true, 'addSmwAskProperties', { query } )

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

	setData[ t( 'SMW_Name' ) ] = self.frameArgs[ translate( 'ARG_Name' ) ] or common.removeTypeSuffix(
		mw.title.getCurrentTitle().text,
		config.name_suffixes
	)

	if type( setData[ t( 'SMW_Manufacturer' ) ] ) == 'string' then
		local man = manufacturer:get( setData[ t( 'SMW_Manufacturer' ) ] )
		if man ~= nil then man = man.name end

		setData[ t( 'SMW_Manufacturer' ) ] = man or setData[ t( 'SMW_Manufacturer' ) ]
		setData[ t( 'SMW_Manufacturer' ) ] = mw.ustring.format( '[[%s]]', setData[ t( 'SMW_Manufacturer' ) ] )
	end

	-- Set properties with API data
    if self.apiData ~= nil and self.apiData.uuid ~= nil then
		--- Commodity
		local commodity = require( 'Module:Commodity' ):new()
		commodity:addShopData( self.apiData )

		if self.apiData.type ~= nil and self.apiData.sub_type ~= nil then
			-- Merge subtype into type, like how the game handles it
			if self.apiData.sub_type ~= 'UNDEFINED' then
				-- SMW_Type is already set prior if self.apiData.type exists
				setData[ t( 'SMW_Type' ) ] = mw.ustring.format( '%s.%s', setData[ t( 'SMW_Type' ) ], self.apiData.sub_type )
			end

			local descData = self.apiData.description_data
			if descData ~= nil then
				for _, descObj in ipairs( descData ) do
					-- Check if there are item type localization
					if descObj.name == 'Item Type' or descObj.name == 'Type' then
						local descType = descObj.type
						-- FIXME: This only works for English, need some way to get only the English text for comparison since descType is always in English
						local itemType = translate( mw.ustring.format( 'type_%s', mw.ustring.lower( setData[ t( 'SMW_Type' ) ] ) ) )

						-- If the type in item description is different than what we compose out of type and subtype data, record it in subtype
						-- TODO: We should make a common function to sanitize strings for comaprison (e.g. lowercase, remove all the space)
						if mw.ustring.lower( descType ) ~= mw.ustring.lower( itemType ) then
							setData[ t( 'SMW_Subtype' ) ] = descType
						end
					end
				end
			end
		end
	end

	runModuleFN( setData[ t( 'SMW_Type' ) ], 'addSmwProperties', { self.apiData, self.frameArgs, setData } )

	mw.logObject( setData, '💾 [Item] Set SMW data' )

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

	mw.logObject( smwData, '⌛ [Item] Loaded infobox SMW data' )

	--- SMW Data load error
	--- Infobox data should always have Name property
	if type( smwData ) ~= 'table' then
		return infobox:renderInfobox( infobox:renderMessage( {
			title = t( 'message_error_no_infobox_data_title' ),
			desc = t( 'message_error_no_data_text' ),
		} ) )
	end

	local function getManufacturer()
		if smwData[ t( 'SMW_Manufacturer' ) ] == nil then return end

		local mfu = manufacturer:get( smwData[ t( 'SMW_Manufacturer' ) ] )
		if mfu == nil then return '[[' .. smwData[ t( 'SMW_Manufacturer' ) ] .. ']]' end

		return infobox.showDescIfDiff(
			table.concat( { '[[', smwData[ t( 'SMW_Manufacturer' ) ], '|', mfu.name , ']]' } ),
			mfu.code
		)
	end

	local function getType()
		if smwData[ t( 'SMW_Type' ) ] == nil then return end

		local itemType = t( mw.ustring.format( 'label_itemtype_%s', mw.ustring.lower( smwData[ t( 'SMW_Type' ) ] ) ) )

		if mw.ustring.find( itemType, 'label_itemtype_' ) then
			itemType = smwData[ t( 'SMW_Type' ) ]
		end

		return mw.ustring.format( '[[%s]]', itemType )
	end

	local function getSize()
		if smwData[ t( 'SMW_Size' ) ] == nil then return end
		return 'S' .. smwData[ t( 'SMW_Size' ) ]
	end

	local function getClass()
		if smwData[ t( 'SMW_Class' ) ] == nil then return end

		local classKey = mw.ustring.lower( smwData[ t( 'SMW_Class' ) ] )
		local class = translate( mw.ustring.format( 'class_%s', classKey ) )

		if smwData[ t( 'SMW_Grade' ) ] ~= nil then
			class = class .. ' (' .. smwData[ t( 'SMW_Grade' ) ] .. ')'
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
					query = mw.ustring.lower( query )
				elseif site.data == 'SMW_ShipMatrixName' then
					query = mw.uri.encode( query, 'PATH' )
				end

				if site.label == 'FleetYards' then
					query = mw.ustring.lower( mw.ustring.gsub( query, '%%20', '-' ) )
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
		--- e.g. Aegis Dynamics (AEGS)
		subtitle = getManufacturer(),
		badge = getSize()
	} )


	--- Type, Size, Class
	infobox:renderSection( {
		content = {
			infobox:renderItem( {
				label = t( 'label_Type' ),
				data = getType(),
			} ),
			infobox:renderItem( {
				label = t( 'label_Subtype' ),
				data = smwData[ t( 'SMW_Subtype' ) ],
			} ),
			infobox:renderItem( {
				label = t( 'label_Class' ),
				data = getClass(),
			} ),
			infobox:renderItem( {
				label = t( 'label_Occupancy' ),
				data = smwData[ t( 'SMW_Occupancy' ) ],
			} ),
			infobox:renderItem( {
				label = t( 'label_Inventory' ),
				data = smwData[ t( 'SMW_Inventory' ) ],
			} )
		},
		col = 2
	} )

	local pageIdentifier = self.frameArgs[ translate( 'ARG_SmwQueryName' ) ] or mw.title.getCurrentTitle().fullText
	runModuleFN( smwData[ t( 'SMW_Type' ) ], 'addInfoboxData', { infobox, smwData, pageIdentifier } )

	--- Dimensions
	infobox:renderSection( {
		title = t( 'label_Dimensions' ),
		content = {
			infobox:renderItem( {
				label = t( 'label_Length' ),
				data = smwData[ t( 'SMW_EntityLength' ) ],
			} ),
			infobox:renderItem( {
				label = t( 'label_Width' ),
				data = smwData[ t( 'SMW_EntityWidth' ) ],
			} ),
			infobox:renderItem( {
				label = t( 'label_Height' ),
				data = smwData[ t( 'SMW_EntityHeight' ) ],
			} ),
			infobox:renderItem( {
				label = t( 'label_Mass' ),
				data = smwData[ t( 'SMW_Mass' ) ],
			} )
		},
		col = 3
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
			} ),
			infobox:renderItem( {
				label = t( 'SMW_GameBuild' ),
				data = smwData[ t( 'SMW_GameBuild' ) ],
				row = true,
				spacebetween = true
			} )
		}
	} )

	--- Actions section
	if smwData[ t( 'SMW_UUID' ) ] then
		infobox:renderSection( {
			class = 'infobox__section--actions infobox__section--hasBackground',
			content = {
				infobox:renderItem( {
					icon = 'WikimediaUI-Search.svg',
					data = translate( 'label_actions_find_item_title' ),
					desc = t( 'label_actions_find_item_text' ),
					-- FIXME: Make this configurable?
					link = 'https://finder.cstone.space/search/' .. smwData[ t( 'SMW_UUID' ) ]
				} )
			}
		} )
	end

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


--- Creates the wikitext for the Item description template
function methodtable.getDescription( self )
	local smwData = self:getSmwData()

	--- Error: No SMW Data
	if type( smwData ) ~= 'table' then
		return require( 'Module:Mbox' )._mbox(
			t( 'message_error_no_description_title' ),
			t( 'message_error_no_data_text' ),
			{ icon = 'WikimediaUI-Error.svg' }
		)
	end

	--- Error: No description SMW property
	if smwData[ t( 'SMW_Description' ) ] == nil then
		return require( 'Module:Mbox' )._mbox(
			t( 'message_error_no_description_title' ),
			t( 'message_error_no_description_text' ),
			{ icon = 'WikimediaUI-Error.svg' }
		)
	end

	return '<blockquote>' .. smwData[ t( 'SMW_Description' ) ] .. '</blockquote>'
end

--- Creates the wikitext for the Item availability template
function methodtable.getAvailability( self )
	local smwData = self:getSmwData()

	--- Error: No SMW Data
	if type( smwData ) ~= 'table' then
		return require( 'Module:Mbox' )._mbox(
			t( 'message_error_no_availability_title' ),
			t( 'message_error_no_data_text' ),
			{ icon = 'WikimediaUI-Error.svg' }
		)
	end

	local output = {}

	local uuid = smwData[ t( 'SMW_UUID' ) ]
	if uuid then 
		-- Create find item button
		local icon = mw.html.create( 'div' ):addClass( 'citizen-ui-icon mw-ui-icon-wikimedia-search' )
		local label = mw.html.create( 'div' )
		label
			:addClass( 't-finditemuif__label' )
			:tag( 'div' )
				:addClass( 't-finditemuif__title' )
				:wikitext( translate( 'label_actions_find_item_title' ) )
				:done()
			:tag( 'div' )
				:addClass( 't-finditemuif__subtitle' )
				:wikitext( t( 'label_actions_find_item_text' ) )
				:allDone()
		local chervon = mw.html.create( 'div' ):addClass( 'citizen-ui-icon mw-ui-icon-wikimedia-collapse' )
		local container = mw.html.create( 'div' )
		container
			:addClass( 't-finditemuif' )
			:wikitext( string.format(
				'[https://finder.cstone.space/search/%s %s%s%s]',
				uuid,
				tostring( icon ),
				tostring( label ),
				tostring( chervon )
			) )
		table.insert( output, tostring( container ) .. mw.getCurrentFrame():extensionTag{
			name = 'templatestyles', args = { src = 'Template:Item availability/styles.css' }
		} )
	end

	return table.concat( output )
end


--- Set the frame and load args
--- @param frame table
function methodtable.setFrame( self, frame )
	self.currentFrame = frame
	self.frameArgs = require( 'Module:Arguments' ).getArgs( frame )
end


--- Sets the main categories for this object
function methodtable.setCategories( self )
	if config.set_categories == false then
		return
	end

	local function addSubcategory( s1, s2 )
		table.insert( self.categories, mw.ustring.format( '%s (%s)', s1, s2 ) )
	end

	--- Only set category if category_type value exists
	if self.smwData[ t( 'SMW_Type' ) ] ~= nil then
		local typeCategoryKey = 'category_itemtype_' .. mw.ustring.lower( self.smwData[ t( 'SMW_Type' ) ] )
		local typeCategory = t( typeCategoryKey )

		if typeCategory ~= nil and typeCategory ~= typeCategoryKey then
			table.insert( self.categories, typeCategory ) 

			if self.smwData[ t( 'SMW_Size' ) ] ~= nil then
				addSubcategory( typeCategory, t( 'SMW_Size' ) .. ' ' .. self.smwData[ t( 'SMW_Size' ) ] )
			end

			if self.smwData[ t( 'SMW_Grade' ) ] ~= nil then
				addSubcategory( typeCategory, t( 'SMW_Grade' ) .. ' ' .. self.smwData[ t( 'SMW_Grade' ) ] )
			end

			if self.smwData[ t( 'SMW_Subtype' ) ] ~= nil then
				addSubcategory( typeCategory, self.smwData[ t( 'SMW_Subtype' ) ] )
			end

			if self.smwData[ t( 'SMW_Class' ) ] ~= nil then
				addSubcategory( typeCategory, self.smwData[ t( 'SMW_Class' ) ] )
			end
		end
	end

	if self.smwData[ t( 'SMW_Manufacturer' ) ] ~= nil then
		local manufacturer = mw.ustring.gsub( self.smwData[ t( 'SMW_Manufacturer' ) ], '%[+', '' )
		manufacturer = mw.ustring.gsub( manufacturer, '%]+', '' )

		table.insert( self.categories, manufacturer )
	else
		table.insert( self.categories, t( 'category_error_item_missing_manufacturer' ) )
	end

	if self.smwData[ t( 'SMW_UUID' ) ] == nil then
		table.insert( self.categories, t( 'category_error_item_missing_uuid' ) )
	end

	runModuleFN( self.smwData[ t( 'SMW_Type' ) ], 'addCategories', { self.categories, self.frameArgs, self.smwData } )
end


--- Sets the short description for this object
function methodtable.setShortDescription( self )
	local shortdesc = ''
	local itemType = translate( 'type_item' )

	if self.smwData[ t( 'SMW_Type' ) ] ~= nil then
		if self.smwData[ t( 'SMW_Subtype' ) ] ~= nil then
			-- TODO: Localize subtype
			itemType = self.smwData[ t( 'SMW_Subtype' ) ]
		else
			local itemTypeKey = 'label_itemtype_' .. mw.ustring.lower( self.smwData[ t( 'SMW_Type' ) ] )
			if t( itemTypeKey ) ~= nil and t( itemTypeKey ) ~= itemTypeKey then
				itemType = t( itemTypeKey )
			end
		end
		itemType = mw.ustring.lower( itemType )
	end

	shortdesc = itemType

	if self.smwData[ t( 'SMW_Class' ) ] ~= nil then
		shortdesc = mw.ustring.format( '%s %s',
			string.lower( self.smwData[ t( 'SMW_Class' ) ] ),
			shortdesc
		)
	end

	if self.smwData[ t( 'SMW_Grade' ) ] ~= nil then
		shortdesc = mw.ustring.format( t( 'shortdesc_grade' ), self.smwData[ t( 'SMW_Grade' ) ], shortdesc )
	end

	if self.smwData[ t( 'SMW_Size' ) ] ~= nil then
		shortdesc = mw.ustring.format( 'S%d %s',
			self.smwData[ t( 'SMW_Size' ) ],
			shortdesc
		)
	end

	--- Manufacturer
	if self.smwData[ t( 'SMW_Manufacturer' ) ] ~= nil and self.smwData[ t( 'SMW_Manufacturer' ) ] ~= 'Unknown manufacturer' then
		local mfuname = self.smwData[ t( 'SMW_Manufacturer' ) ]
		local man = manufacturer:get( mfuname )
		--- Use short name if possible
		if man ~= nil and man.shortname ~= nil then mfuname = man.shortname end

		shortdesc = mw.ustring.format( t( 'shortdesc_manufactured_by' ), shortdesc, mfuname )
	end

	--- Submodule override
	shortdesc = runModuleFN(
		self.smwData[ t( 'SMW_Type' ) ],
		'getShortDescription',
		{ self.frameArgs, self.smwData },
		true
	) or shortdesc

	if type( shortdesc ) == 'string' and shortdesc ~= '' then
		shortdesc = lang:ucfirst( shortdesc )
		self.currentFrame:callParserFunction( 'SHORTDESC', shortdesc )
	end
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


--- Get the wikitext valid categories for this item
function methodtable.getCategories( self )
	local mapped = {}

	for _, category in pairs( self.categories ) do
		if mw.ustring.sub( category, 1, 2 ) ~= '[[' then
			category = mw.ustring.format( '[[Category:%s]]', category )
		end

		table.insert( mapped, category )
	end

	return table.concat( mapped )
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


--- Implements the item description template
---
--- @param frame table Invocation frame
--- @return string
function Item.description( frame )
	local instance = Item:new()
	instance:setFrame( frame )
	return tostring( instance:getDescription() )
end


--- Implements the item availability template
---
--- @param frame table Invocation frame
--- @return string
function Item.availability( frame )
	local instance = Item:new()
	instance:setFrame( frame )
	return tostring( instance:getAvailability() )
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
	local interwikiLinks = ''

	if instance.frameArgs[ 'debug' ] ~= nil then
		debugOutput = instance:makeDebugOutput()
	end

	local infobox = tostring( instance:getInfobox() )

	if instance.smwData ~= nil then
		instance:setCategories()
		instance:setShortDescription()
		interwikiLinks = common.generateInterWikiLinks( mw.title.getCurrentTitle().text )
	end

	return infobox .. debugOutput .. instance:getCategories() .. interwikiLinks
end


---
function Item.test( page )
	page = page or 'Cirrus'

	local instance = Item:new()
	instance.frameArgs = {}
	instance.frameArgs[ translate( 'ARG_Name' ) ] = page
	instance.frameArgs[ translate( 'ARG_SmwQueryName' ) ] = page

	instance:saveApiData()
	instance:getInfobox()
end


return Item

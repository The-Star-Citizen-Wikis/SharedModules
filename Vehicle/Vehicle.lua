require( 'strict' )

local Vehicle = {}

local metatable = {}
local methodtable = {}

metatable.__index = methodtable

local TNT = require( 'Module:Translate' ):new()
local common = require( 'Module:Common' )
local manufacturer = require( 'Module:Manufacturer' )._manufacturer
local hatnote = require( 'Module:Hatnote' )._hatnote
local data = mw.loadJsonData( 'Module:Vehicle/data.json' )
local config = mw.loadJsonData( 'Module:Vehicle/config.json' )

local lang
if config.module_lang then
	lang = mw.getLanguage( config.module_lang )
else
	lang = mw.getContentLanguage()
end


--- Calls TNT with the given key
---
--- @param key string The translation key
--- @param addSuffix boolean|nil Adds a language suffix if config.smw_multilingual_text is true
--- @return string If the key was not found in the .tab page, the key is returned
local function translate( key, addSuffix, ... )
	return TNT:translate( 'Module:Vehicle/i18n.json', config, key, addSuffix, {...} ) or key
end


--- Check if the current vehicle is a ground vehicle
---
--- @param smwData table
--- @return boolean
local function isGroundVehicle( smwData )
	local size = smwData[ translate( 'SMW_ShipMatrixSize' ) ]

	return ( size ~= nil and size == translate( 'Vehicle' ) ) or smwData[ translate( 'SMW_ReverseSpeed' ) ] ~= nil
end


--- Creates the object that is used to query the SMW store
---
--- @param page string the vehicle page containing data
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
			if mw.ustring.sub( key, 1, 3 ) == 'SMW' then
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
			table.insert( query, mw.ustring.format( formatString, translate( smwKey ) ) )

			if queryPart.type == 'multilingual_text' then
				table.insert( query, langSuffix )
			end
		end
	end

	table.insert( query, 'limit=1' )

	return query
end


--- FIXME: This should go to somewhere else, like Module:Common
local function makeTimeReadable( t )
	if t == nil then return end

	-- Fix for german number format
	if mw.ustring.find( t, ',', 1, true ) then
		t = mw.ustring.gsub( t, ',', '.' )
	end

	if type( t ) == 'string' then
		t = tonumber( t, 10 )
	end

	t = lang:formatDuration( t * 60 )

	local regex
	if lang:getCode() == 'de' then
		regex = {
			[ '%s?[Tt]agen?' ] = 'd',
			[ '%s?[Ss]tunden?' ] = 'h',
			[ '%s?[Mm]inuten?' ] = 'm',
			[ '%s?[Ss]ekunden?' ] = 's',
			[ ','] = '',
			[ 'und%s'] = ''
		}
	else
		regex = {
			[ '%sdays*' ] = 'd',
			[ '%shours*' ] = 'h',
			[ '%sminutes*' ] = 'm',
			[ '%sseconds*' ] = 's',
			[ ','] = '',
			[ 'and%s'] = ''
		}
	end

	for pattern, replace in pairs( regex ) do
		t = mw.ustring.gsub( t, pattern, replace )
	end

	return t
end


--- FIXME: This should go to somewhere else, like Module:Common
--- TODO: Should we color code this for buff and debuff?
local function formatModifier( x )
	if x == nil then return end
	-- Fix for german number format
	if mw.ustring.find( x, ',', 1, true ) then
		x = mw.ustring.gsub( x, ',', '.' )
	end

	if type( x ) == 'string' then x = tonumber( x, 10 ) end

	local diff = x - 1
	local sign = ''
	if diff == 0 then
		--- Display 'None' instead of 0 % for better readability
		return translate( 'none' )
	elseif diff > 0 then
		--- Extra space for formatting
		sign = '+ '
	elseif diff < 0 then
		sign = '- '
	end
	return sign .. tostring( math.abs( diff ) * 100 ) .. ' %'
end


--- Request Api Data
--- Using current subpage name without vehicle type suffix
--- @return table|nil
function methodtable.getApiDataForCurrentPage( self )
	local api = require( 'Module:Common/Api' )

	local query = self.frameArgs[ translate( 'ARG_UUID' ) ] or self.frameArgs[ translate( 'ARG_Name' ) ] or common.removeTypeSuffix(
        mw.title.getCurrentTitle().rootText,
		config.name_suffixes
    )

	local success, json = pcall( mw.text.jsonDecode, mw.ext.Apiunto.get_raw( 'v2/vehicles/' .. query, {
		include = data.includes,
		locale = config.api_locale
	} ) )

	if not success or api.checkResponseStructure( json, true, false ) == false then return end

    self.apiData = json[ 'data' ]
    self.apiData = api.makeAccessSafe( self.apiData )

    return self.apiData
end


--- Base Properties that are shared across all Vehicles
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
		'Vehicle'
	)

	setData[ translate( 'SMW_Name' ) ] = self.frameArgs[ translate( 'ARG_Name' ) ] or common.removeTypeSuffix(
		mw.title.getCurrentTitle().rootText,
		config.name_suffixes
	)

	if type( setData[ translate( 'SMW_Manufacturer' ) ] ) == 'string' then
		local man = manufacturer( setData[ translate( 'SMW_Manufacturer' ) ] )
		if man ~= nil then man = man.name end

		setData[ translate( 'SMW_Manufacturer' ) ] = man or setData[ translate( 'SMW_Manufacturer' ) ]
		setData[ translate( 'SMW_Manufacturer' ) ] = mw.ustring.format( '[[%s]]', setData[ translate( 'SMW_Manufacturer' ) ] )
	end

    -- Set properties with API data
    if self.apiData ~= nil then
		-- Flight ready vehicles
		--- Override template parameter with in-game data
		if self.apiData.uuid ~= nil then
			--- Components
			if self.apiData.hardpoints ~= nil and type( self.apiData.hardpoints ) == 'table' and #self.apiData.hardpoints > 0 then
				local hardpoint = require( 'Module:VehicleHardpoint' ):new( self.frameArgs[ translate( 'ARG_name' ) ] or mw.title.getCurrentTitle().fullText )
				hardpoint:setHardPointObjects( self.apiData.hardpoints )
				hardpoint:setParts( self.apiData.parts )

				if not self.apiData.hardpoints and type( self.apiData.components ) == 'table' and #self.apiData.components > 0 then
					hardpoint:setComponents( self.apiData.components )
				end
			end

			--- Commodity
			local commodity = require( 'Module:Commodity' ):new()
			commodity:addShopData( self.apiData )
		end

		-- Loaner
		--- TODO: Handling of table/object values should be handled in Common/SMW
		if self.apiData.loaner ~= nil and type( self.apiData.loaner ) == 'table' and #self.apiData.loaner > 0 then
			local tmp = {}
			for _, loaner in ipairs( self.apiData.loaner ) do
				if loaner.name ~= nil then
					table.insert( tmp, mw.ustring.format( '[[%s]]', loaner.name ) )
				end
			end
			setData[ translate( 'SMW_LoanerVehicle' ) ] = tmp
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
		return hatnote( mw.ustring.format(
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

	local function getIndicatorClass()
		local state = smwData[ translate( 'SMW_ProductionState' ) ]
		if state == nil then return end

		local classMap = config.productionstate_map

		for _, map in pairs( classMap ) do
			if mw.ustring.match( state, translate( map.name ) ) ~= nil then
				return 'infobox__indicator--' .. map.color
			end
		end
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
		if smwData[ translate( 'SMW_Size' ) ] == nil then return smwData[ translate( 'SMW_ShipMatrixSize' ) ] end

		local codes = { 'XXS', 'XS', 'S', 'M', 'L', 'XL' }
		local size = smwData[ translate( 'SMW_Size' ) ]

		-- For uninitialized SMW properties
		if type( size ) == 'string' then
			size = tonumber( size, 10 )
		end

		return infobox.showDescIfDiff(
			smwData[ translate( 'SMW_ShipMatrixSize' ) ],
			table.concat( { 'S', size, '/', codes[ size ] } )
		)
	end

	local function getSeries()
		local series = smwData[ translate( 'SMW_Series' ) ]
		if series == nil then return end
		return mw.ustring.format(
			'[[:Category:%s|%s]]',
			translate( 'category_series', false, series ),
			series
		)
	end

	--- Cost section
	local function getCostSection()
		local tabberData = {}
		local section

		tabberData[ 'label1' ] = translate( 'LBL_Pledge' )
		section = {
			infobox:renderItem( {
				label = translate( 'LBL_Standalone' ),
				data = infobox.showDescIfDiff( smwData[ translate( 'SMW_PledgePrice' ) ], smwData[ translate( 'SMW_OriginalPledgePrice' ) ] ),
			} ),
			infobox:renderItem( {
				label = translate( 'LBL_Warbond' ),
				data = infobox.showDescIfDiff( smwData[ translate( 'SMW_WarbondPledgePrice' ) ], smwData[ translate( 'SMW_OriginalWarbondPledgePrice' ) ] ),
			} ),
			infobox:renderItem( {
				label = translate( 'LBL_Availability' ),
				data = smwData[ translate( 'SMW_PledgeAvailability' ) ],
			} ),
		}
		tabberData[ 'content1' ] = infobox:renderSection( { content = section, col = 2 }, true )

		tabberData[ 'label2' ] = translate( 'LBL_Insurance' )

		section = {
			infobox:renderItem( {
				label = translate( 'LBL_Claim' ),
				data = makeTimeReadable( smwData[ translate('SMW_InsuranceClaimTime' ) ] ),
			} ),
			infobox:renderItem( {
				label = translate( 'LBL_Expedite' ),
				data = makeTimeReadable( smwData[ translate('SMW_InsuranceExpediteTime' ) ] ),
			} ),
			infobox:renderItem( {
				label = translate( 'LBL_ExpediteFee' ),
				data = smwData[ translate('SMW_InsuranceExpediteCost' ) ],
				colspan = 2
			} ),
		}
		tabberData[ 'content2' ] = infobox:renderSection( { content = section, col = 4 }, true )

		--- TODO: Move this back up to the first tab when we fix universe cost
		section = {}

		--- Show message on where the game price data are
		if smwData[ 'UUID' ] ~= nil then
			tabberData[ 'label3' ] = translate( 'LBL_Universe' )
			tabberData[ 'content3' ] = infobox:renderMessage( {
				title = translate( 'msg_ingame_prices_title' ),
				desc = translate( 'msg_ingame_prices_content' )
			}, true )
		end

		return tabber( tabberData )
	end


	--- Specifications section
	local function getSpecificationsSection()
		local tabberData = {}
		local section

		tabberData[ 'label1' ] = translate( 'LBL_Dimensions' )
		section = {
			infobox:renderItem( {
				label = translate( 'LBL_Length' ),
				data = infobox.showDescIfDiff( smwData[ translate( 'SMW_EntityLength' ) ], smwData[ translate( 'SMW_RetractedLength' ) ] ),
			} ),
			infobox:renderItem( {
				label = translate( 'LBL_Width' ),
				data = infobox.showDescIfDiff( smwData[ translate( 'SMW_EntityWidth' ) ], smwData[ translate( 'SMW_RetractedWidth' ) ] ),
			} ),
			infobox:renderItem( {
				label = translate( 'LBL_Height' ),
				data = infobox.showDescIfDiff( smwData[ translate( 'SMW_EntityHeight' ) ], smwData[ translate( 'SMW_RetractedHeight' ) ] ),
			} ),
			infobox:renderItem( {
				label = translate( 'LBL_Mass' ),
				data = smwData[ translate( 'SMW_Mass' ) ],
			} ),
		}

		tabberData[ 'content1' ] = infobox:renderSection( { content =section, col = 3 }, true )

		tabberData[ 'label2' ] = translate( 'LBL_Speed' )
		section = {
			infobox:renderItem( {
				label = translate( 'LBL_ScmSpeed' ),
				data = smwData[ translate( 'SMW_ScmSpeed' ) ]
			} ),
			infobox:renderItem( {
				label = translate( 'LBL_0ToScm' ),
				data = smwData[ translate( 'SMW_ZeroToScmSpeedTime' ) ]
			} ),
			infobox:renderItem( {
				label = translate( 'LBL_ScmTo0' ),
				data = smwData[ translate( 'SMW_ScmSpeedToZeroTime' ) ]
			} ),
			infobox:renderItem( {
				label = translate( 'LBL_MaxSpeed' ),
				data = smwData[ translate( 'SMW_MaximumSpeed' ) ]
			} ),
			infobox:renderItem( {
				label = translate( 'LBL_0ToMax' ),
				data = smwData[ translate( 'SMW_ZeroToMaximumSpeedTime' ) ]
			} ),
			infobox:renderItem( {
				label = translate( 'LBL_MaxTo0' ),
				data = smwData[ translate( 'SMW_MaximumSpeedToZeroTime' ) ]
			} ),
			infobox:renderItem( {
				label = translate( 'LBL_ReverseSpeed' ),
				data = smwData[ translate( 'SMW_ReverseSpeed' ) ]
			} ),
			infobox:renderItem( {
				label = translate( 'LBL_RollRate' ),
				data = smwData[ translate( 'SMW_RollRate' ) ]
			} ),
			infobox:renderItem( {
				label = translate( 'LBL_PitchRate' ),
				data = smwData[ translate( 'SMW_PitchRate' ) ]
			} ),
			infobox:renderItem( {
				label = translate( 'LBL_YawRate' ),
				data = smwData[ translate( 'SMW_YawRate' ) ]
			} ),
		}
		tabberData[ 'content2' ] = infobox:renderSection( { content = section, col = 3 }, true )

		tabberData[ 'label3' ] = translate( 'LBL_Fuel' )
		section = {
			infobox:renderItem( {
				label = translate( 'LBL_HydrogenCapacity' ),
				data = smwData[ translate( 'SMW_HydrogenFuelCapacity' ) ],
			} ),
			infobox:renderItem( {
				label = translate( 'LBL_HydrogenIntake' ),
				data = smwData[ translate( 'SMW_HydrogenFuelIntakeRate' ) ],
			} ),
			infobox:renderItem( {
				label = translate( 'LBL_QuantumCapacity' ),
				data = smwData[ translate( 'SMW_QuantumFuelCapacity' ) ],
			} ),
		}
		tabberData[ 'content3' ] = infobox:renderSection( { content = section, col = 2 }, true )

		tabberData[ 'label4' ] = translate( 'LBL_Hull' )

		section = {
			infobox:renderItem( {
				label = translate( 'LBL_CrossSection' ),
				data = formatModifier( smwData[ translate( 'SMW_CrossSectionSignatureModifier' ) ] ),
			} ),
			infobox:renderItem( {
				label = translate( 'LBL_Electromagnetic' ),
				data = formatModifier( smwData[ translate( 'SMW_ElectromagneticSignatureModifier' ) ] ),
			} ),
			infobox:renderItem( {
				label = translate( 'LBL_Infrared' ),
				data = formatModifier( smwData[ translate( 'SMW_InfraredSignatureModifier' ) ] ),
			} ),
			infobox:renderItem( {
				label = translate( 'LBL_Physical' ),
				data = formatModifier( smwData[ translate( 'SMW_PhysicalDamageModifier' ) ] ),
			} ),
			infobox:renderItem( {
				label = translate( 'LBL_Energy' ),
				data = formatModifier( smwData[ translate( 'SMW_EnergyDamageModifier' ) ] ),
			} ),
			infobox:renderItem( {
				label = translate( 'LBL_Distortion' ),
				data = formatModifier( smwData[ translate( 'SMW_DistortionDamageModifier' ) ] ),
			} ),
			infobox:renderItem( {
				label = translate( 'LBL_Thermal' ),
				data = formatModifier( smwData[ translate( 'SMW_ThermalDamageModifier' ) ] ),
			} ),
			infobox:renderItem( {
				label = translate( 'LBL_Biochemical' ),
				data = formatModifier( smwData[ translate( 'SMW_BiochemicalDamageModifier' ) ] ),
			} ),
			infobox:renderItem( {
				label = translate( 'LBL_Stun' ),
				data = formatModifier( smwData[ translate( 'SMW_StunDamageModifier' ) ] ),
			} ),
			infobox:renderItem( {
				label = translate( 'LBL_Health' ),
				data = smwData[ translate( 'SMW_HealthPoint' ) ],
			} ),
		}
		tabberData[ 'content4' ] = infobox:renderSection( { content = section, col = 3 }, true )

		return tabber( tabberData )
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

	infobox:renderIndicator( {
		data = smwData[ translate( 'SMW_ProductionState' ) ],
		desc = smwData[ translate( 'SMW_ProductionStateDesc' ) ],
		class = getIndicatorClass()
	} )
	infobox:renderHeader( {
		title = smwData[ translate( 'SMW_Name' ) ],
		--- e.g. Aegis Dynamics (AEGS)
		subtitle = getManufacturer()
	} )


	--- Role, Size, Series and Loaners
	infobox:renderSection( {
		content = {
			infobox:renderItem( {
				label = translate( 'LBL_Role' ),
				data = infobox.tableToCommaList( smwData[ translate( 'SMW_Role' ) ] ),
			} ),
			infobox:renderItem( {
				label = translate( 'LBL_Size' ),
				data = getSize(),
			} ),
			infobox:renderItem( {
				label = translate( 'LBL_Series' ),
				data = getSeries(),
			} ),
			infobox:renderItem( {
				label = translate( 'LBL_Loaner' ),
				data = infobox.tableToCommaList( smwData[ translate( 'SMW_LoanerVehicle' ) ] ),
			} ),
		},
		col = 2
	} )


	--- Capacity
	infobox:renderSection( {
		title = translate( 'LBL_Capacity' ),
		col = 3,
		content = {
			infobox:renderItem( {
				label = translate( 'LBL_Crew' ),
				data = infobox.formatRange( smwData[ translate( 'SMW_MinimumCrew' ) ], smwData[ translate( 'SMW_MaximumCrew' ) ], true ),
			} ),
			infobox:renderItem( {
				label = translate( 'LBL_Cargo' ),
				data = smwData[ translate( 'SMW_CargoCapacity' ) ],
			} ),
			infobox:renderItem( {
				label = translate( 'LBL_Stowage' ),
				data = smwData[ translate( 'SMW_VehicleInventory' ) ],
			} ),
		},
	} )


	--- Cost
	infobox:renderSection( {
		title = translate( 'LBL_Cost' ),
		class = 'infobox__section--tabber',
		content = getCostSection(),
	} )


	--- Specifications
	infobox:renderSection( {
		title = translate( 'LBL_Specifications' ),
	 	class = 'infobox__section--tabber',
		content = getSpecificationsSection(),
	} )


	--- Lore section
	infobox:renderSection( {
		title = translate( 'LBL_Lore' ),
		col = 2,
		content = {
			infobox:renderItem( {
				label = translate( 'LBL_Released' ),
				data = smwData[ translate( 'SMW_LoreReleaseDate' ) ]
			} ),
			infobox:renderItem( {
				label = translate( 'LBL_Retired' ),
				data = smwData[ translate( 'SMW_LoreRetirementDate' ) ]
			} ),
		},
	} )


	--- Development section
	infobox:renderSection( {
		title = translate( 'LBL_Development' ),
		col = 2,
		content = {
			infobox:renderItem( {
				label = translate( 'LBL_Announced' ),
				data = smwData[ translate( 'SMW_ConceptAnnouncementDate' ) ]
			} ),
			infobox:renderItem( {
				label = translate( 'LBL_ConceptSale' ),
				data = smwData[ translate( 'SMW_ConceptSaleDate' ) ]
			} ),
		},
	} )


	--- Metadata section
	infobox:renderSection( {
		class = 'infobox__section--metadata infobox__section--hasBackground',
		content = {
			infobox:renderItem( {
				label = translate( 'SMW_UUID' ),
				data = smwData[ translate( 'SMW_UUID' ) ],
				row = true,
				spacebetween = true
			} ),
			infobox:renderItem( {
				label = translate( 'SMW_ClassName' ),
				data = smwData[ translate( 'SMW_ClassName' ) ],
				row = true,
				spacebetween = true
			} ),
			infobox:renderItem( {
				label = translate( 'SMW_GameBuild' ),
				data = smwData[ translate( 'SMW_GameBuild' ) ],
				row = true,
				spacebetween = true
			} )
		},
	} )

	--- Actions section
	if smwData[ translate( 'SMW_UUID' ) ] then
		infobox:renderSection( {
			class = 'infobox__section--actions infobox__section--hasBackground',
			content = {
				infobox:renderItem( {
					icon = 'WikimediaUI-Search.svg',
					data = translate( 'actions_find_item_title' ),
					desc = translate( 'actions_find_item_text' ),
					-- FIXME: Make this configurable?
					link = 'https://finder.cstone.space/search/' .. smwData[ translate( 'SMW_UUID' ) ]
				} )
			}
		} )
	end


	--- Footer
	infobox:renderFooter( {
		button = {
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
		}
	} )

	return infobox:renderInfobox( nil, smwData[ translate( 'SMW_Name' ) ] )
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

	local size = self.smwData[ translate( 'SMW_ShipMatrixSize' ) ]
	local size_cat, pledge_cat
	local isGroundVehicle = isGroundVehicle( self.smwData )

	if isGroundVehicle then
		--Ground vehicle has no ship matrix size currently
		--size_cat = 'category_ground_vehicle_size'
		pledge_cat = 'category_ground_vehicle_pledge'
		table.insert(
			self.categories,
			string.format( '[[Category:%s]]', translate( 'category_ground_vehicle' ) )
		)
	else
		size_cat = 'category_ship_size'
		pledge_cat = 'category_ship_pledge'
		table.insert(
			self.categories,
			string.format( '[[Category:%s]]', translate( 'category_ship' ) )
		)
	end

	if size ~= nil and size_cat then
		table.insert(
			self.categories,
			string.format( '[[Category:%s]]', translate( size_cat, false, size ) )
		)
	end

	if self.smwData[ translate( 'SMW_Manufacturer' ) ] ~= nil then
		local manufacturer = mw.ustring.gsub( self.smwData[ translate( 'SMW_Manufacturer' ) ], '%[+', '' )
		manufacturer = mw.ustring.gsub( manufacturer, '%]+', '' )

		table.insert(
			self.categories,
			string.format( '[[Category:%s]]', manufacturer )
		)
	end

	if self.smwData[ translate( 'SMW_ProductionState' ) ] ~= nil then
		table.insert(
			self.categories,
			string.format( '[[Category:%s]]', self.smwData[ translate( 'SMW_ProductionState' ) ] )
		)
	end

	if self.smwData[ translate( 'SMW_Series' ) ] ~= nil then
		table.insert(
			self.categories,
			string.format( '[[Category:%s]]', translate( 'category_series', false, self.smwData[ translate( 'SMW_Series' ) ] ) )
		)
	end

	if pledge_cat and self.smwData[ translate( 'SMW_PledgePrice' ) ] ~= nil then
		table.insert(
			self.categories,
			string.format( '[[Category:%s]]', translate( pledge_cat ) )
		)
	end
end

--- Sets the short description for this object
function methodtable.setShortDescription( self )
	local shortdesc
	local vehicleType
	local isGroundVehicle = isGroundVehicle( self.smwData )

	if isGroundVehicle then
		vehicleType = translate( 'shortdesc_ground_vehicle' )
	else
		vehicleType = translate( 'shortdesc_ship' )
	end

	if self.smwData[ translate( 'SMW_Role' ) ] ~= nil then
		local vehicleRole = self.smwData[ translate( 'SMW_Role' ) ]
		if type( vehicleRole ) == 'table' then
			vehicleRole = table.concat( vehicleRole, ' ' )
		end

		vehicleRole = mw.ustring.lower( vehicleRole )
		
		for _, noun in pairs( config.role_suffixes ) do
			local match = mw.ustring.find( vehicleRole, '%f[%a]' .. noun .. '%f[%A]' )
			--- Remove suffix from role
			if match then
				vehicleRole = mw.text.trim( mw.ustring.gsub( vehicleRole, noun, '' ) )
				vehicleType = noun
			end
		end

		shortdesc = mw.ustring.format( '%s %s', vehicleRole, vehicleType )
	else
		shortdesc = vehicleType
	end

	if not isGroundVehicle and self.smwData[ translate( 'SMW_ShipMatrixSize' ) ] ~= nil then
		local vehicleSize = self.smwData[ translate( 'SMW_ShipMatrixSize' ) ]
		--- Special handling for single-seat ship
		if self.smwData[ translate( 'SMW_MaximumCrew' ) ] ~= nil and self.smwData[ translate( 'SMW_MaximumCrew' ) ] == 1 then
			vehicleSize = translate( 'shortdesc_single_seat' )
		end

		shortdesc = mw.ustring.format( '%s %s', vehicleSize, shortdesc )
	end

	if self.smwData[ translate( 'SMW_Manufacturer' ) ] ~= nil then
		local mfuname = self.smwData[ translate( 'SMW_Manufacturer' ) ]
		local man = manufacturer( mfuname )
		--- Use short name if possible
		if man ~= nil and man.shortname ~= nil then mfuname = man.shortname end

		shortdesc = translate( 'shortdesc_manufactured_by', false, shortdesc, mfuname )
	end

	shortdesc = lang:ucfirst( shortdesc )

	self.currentFrame:callParserFunction( 'SHORTDESC', shortdesc )
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
function Vehicle.new( self )
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
function Vehicle.loadApiData( frame )
	local instance = Vehicle:new()
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
function Vehicle.infobox( frame )
	local instance = Vehicle:new()
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
function Vehicle.main( frame )
	local instance = Vehicle:new()
	instance:setFrame( frame )
	instance:saveApiData()

	local debugOutput = ''
	if instance.frameArgs[ 'debug' ] ~= nil then
		debugOutput = instance:makeDebugOutput()
	end

	local infobox = tostring( instance:getInfobox() )

	-- Only set categories and short desc if this is the page that also holds the smw attributes
	-- Allows outputting vehicle infoboxes on other pages without setting categories
	if instance.smwData ~= nil then
		instance:setCategories()
		instance:setShortDescription()
		-- FIXME: Is there a cleaner way?
		infobox = infobox .. common.generateInterWikiLinks( mw.title.getCurrentTitle().rootText )
	end

	return infobox .. debugOutput .. table.concat( instance.categories )
end


---
function Vehicle.test( page )
	page = page or '300i'

	local instance = Vehicle:new()
	instance.frameArgs = {}
	instance.frameArgs[ translate( 'ARG_Name' ) ] = page

	instance:saveApiData()
end


return Vehicle

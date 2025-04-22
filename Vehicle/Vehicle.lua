require( 'strict' )

local Vehicle = {}

local BOUNDS = {
	ScmSpeed = {
		min = 45,
		max = 300
	},
	MaximumSpeed = {
		min = 20,
		max = 1485
	},
	ReverseSpeed = {
		min = 7,
		max = 34
	},
	RollRate = {
		min = 15,
		max = 234
	},
	PitchRate = {
		min = 7,
		max = 97
	},
	YawRate = {
		min = 8,
		max = 97
	}
}

local metatable = {}
local methodtable = {}

metatable.__index = methodtable

local i18n = require( 'Module:i18n' ):new()
local TNT = require( 'Module:Translate' ):new()
local common = require( 'Module:Common' )
local manufacturer = require( 'Module:Manufacturer' ):new()
local hatnote = require( 'Module:Hatnote' )._hatnote
local data = mw.loadJsonData( 'Module:Vehicle/data.json' )
local config = mw.loadJsonData( 'Module:Vehicle/config.json' )

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


--- Calls TNT with the given key
---
--- @param key string The translation key
--- @param addSuffix boolean|nil Adds a language suffix if config.smw_multilingual_text is true
--- @return string If the key was not found in the .tab page, the key is returned
local function translate( key, addSuffix, ... )
	return TNT:translate( 'Module:Vehicle/i18n.json', config, key, addSuffix, { ... } ) or key
end


--- Check if the current vehicle is a ground vehicle
---
--- @param smwData table
--- @return boolean
local function isGroundVehicle( smwData )
	local size = smwData[t( 'SMW_ShipMatrixSize' )]

	return (size ~= nil and size == translate( 'Vehicle' )) or smwData[t( 'SMW_ReverseSpeed' )] ~= nil
end


--- Creates the object that is used to query the SMW store
---
--- @param page string the vehicle page containing data
--- @return table
local function makeSmwQueryObject( page )
	local langSuffix = ''
	if config.smw_multilingual_text == true then
		langSuffix = '+lang=' .. (config.module_lang or mw.getContentLanguage():getCode())
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
			table.insert( query, string.format( formatString, t( smwKey ) ) )

			if queryPart.type == 'multilingual_text' then
				table.insert( query, langSuffix )
			end
		end
	end

	-- These properties are set by Module:Vehicle availability
	table.insert( query, '?Average price#-n' )
	table.insert( query, '?Average rental price (per day)#-n' )

	table.insert( query, 'limit=1' )

	return query
end


--- FIXME: This should go to somewhere else, like Module:Common
local function makeTimeReadable( time )
	if time == nil then return end

	-- Fix for german number format
	if string.find( time, ',', 1, true ) then
		time = string.gsub( time, ',', '.' )
	end

	if type( time ) == 'string' then
		time = tonumber( time, 10 )
	end

	time = lang:formatDuration( time * 60 )

	local regex
	if lang:getCode() == 'de' then
		regex = {
			['%s?[Tt]agen?'] = 'd',
			['%s?[Ss]tunden?'] = 'h',
			['%s?[Mm]inuten?'] = 'm',
			['%s?[Ss]ekunden?'] = 's',
			[','] = '',
			['und%s'] = ''
		}
	else
		regex = {
			['%sdays*'] = 'd',
			['%shours*'] = 'h',
			['%sminutes*'] = 'm',
			['%sseconds*'] = 's',
			[','] = '',
			['and%s'] = ''
		}
	end

	for pattern, replace in pairs( regex ) do
		time = string.gsub( time, pattern, replace )
	end

	return time
end


--- Request Api Data
--- Using current subpage name without vehicle type suffix
--- @return table|nil
function methodtable.getApiDataForCurrentPage( self )
	local api = require( 'Module:Common/Api' )

	local query = self.frameArgs[translate( 'ARG_UUID' )] or self.frameArgs[translate( 'ARG_Name' )] or
		common.removeTypeSuffix(
			mw.title.getCurrentTitle().text,
			config.name_suffixes
		)

	local hardpointFilter = {}
	for _, filter in pairs( data.hardpoint_filter or {} ) do
		table.insert( hardpointFilter, '!' .. filter )
	end

	local success, json = pcall( mw.text.jsonDecode, mw.ext.Apiunto.get_raw( 'v2/vehicles/' .. query, {
		include = data.includes,
		locale = config.api_locale,
		['filter[hardpoints]'] = table.concat( hardpointFilter, ',' )
	} ) )

	if not success or api.checkResponseStructure( json, true, false ) == false then return end

	self.apiData = json['data']
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

	setData[t( 'SMW_Name' )] = self.frameArgs[translate( 'ARG_Name' )] or common.removeTypeSuffix(
		mw.title.getCurrentTitle().text,
		config.name_suffixes
	)

	if type( setData[t( 'SMW_Manufacturer' )] ) == 'string' then
		local man = manufacturer:get( setData[t( 'SMW_Manufacturer' )] )
		if man ~= nil then man = man.name end

		setData[t( 'SMW_Manufacturer' )] = man or setData[t( 'SMW_Manufacturer' )]
		setData[t( 'SMW_Manufacturer' )] = string.format( '[[%s]]', setData[t( 'SMW_Manufacturer' )] )
	end

	-- Set properties with API data
	if self.apiData ~= nil then
		-- Flight ready vehicles
		--- Override template parameter with in-game data
		if self.apiData.uuid ~= nil then
			--- Components
			if self.apiData.hardpoints ~= nil and type( self.apiData.hardpoints ) == 'table' and #self.apiData.hardpoints > 0 then
				local hardpoint = require( 'Module:VehicleHardpoint' ):new( self.frameArgs[translate( 'ARG_name' )] or
					mw.title.getCurrentTitle().fullText )
				hardpoint:setHardPointObjects( self.apiData.hardpoints )
				hardpoint:setParts( self.apiData.parts )

				if not self.apiData.hardpoints and type( self.apiData.components ) == 'table' and #self.apiData.components > 0 then
					hardpoint:setComponents( self.apiData.components )
				end
			end

			--- Commodity
			--- local commodity = require( 'Module:Commodity' ):new()
			--- commodity:addShopData( self.apiData )
		end
	end

	--mw.logObject( setData, '💾 [Vehicle] Set SMW data' )

	self.setData = setData

	return mw.smw.set( setData )
end

--- Queries the SMW Store
--- @return table
function methodtable.getSmwData( self )
	-- Cache multiple calls
	if self.smwData ~= nil and self.smwData[t( 'SMW_Name' )] ~= nil then
		self.smwData['__cache status'] = 'HIT'
		return self.smwData
	end

	local queryName = self.frameArgs[translate( 'ARG_SmwQueryName' )] or
		self.frameArgs[translate( 'ARG_Name' )] or
		mw.title.getCurrentTitle().fullText

	local smwData = mw.smw.ask( makeSmwQueryObject( queryName ) )

	if smwData == nil or smwData[1] == nil then
		return hatnote( string.format(
				'%s[[%s]]',
				t( 'message_error_no_data_text' ),
				t( 'category_error_pages_with_script_errors' )
			),
			{ icon = 'WikimediaUI-Error.svg' }
		)
	end

	self.smwData = smwData[1]
	self.smwData['__cache status'] = 'MISS'

	return self.smwData
end

--- Creates the infobox
function methodtable.getInfobox( self )
	local smwData = self:getSmwData()

	--mw.logObject( smwData, '⌛ [Vehicle] Loaded infobox SMW data' )

	local infobox = require( 'Module:InfoboxNeue' ):new( {
		placeholderImage = config.placeholder_image
	} )

	local floatingui = require( 'Module:FloatingUI' )
	local tabber = require( 'Module:Tabber' ).renderTabber

	--- SMW Data load error
	--- Infobox data should always have Name property
	if type( smwData ) ~= 'table' then
		return infobox:renderInfobox( infobox:renderMessage( {
			title = t( 'message_error_no_data_title' ),
			desc = t( 'message_error_no_data_text' ),
		} ) )
	end

	--- FIXME: Should this go into Module:i18n?
	local function hasI18n( key )
		return t( key ) ~= key
	end

	--- Create indicator and its floating element
	--- This needs to be custom-built because there are multiple content inside the floating element
	local function getIndicator()
		local state = smwData[t( 'SMW_ProductionState' )]
		if state == nil then return {} end

		local indicator = {}

		local matchedDesc
		local stateData = data.productionstates
		for _, map in pairs( stateData ) do
			local msgKey = 'label_productionstate_' .. map.key
			if string.match( state, t( msgKey ) ) ~= nil then
				indicator['color'] = map.color
				local descMsgKey = msgKey .. '_desc'
				if hasI18n( descMsgKey ) then
					matchedDesc = t( descMsgKey )
				end
			end
		end

		indicator['data'] = smwData[t( 'SMW_ProductionState' )]

		if smwData[t( 'SMW_ProductionStateDesc' )] ~= nil or matchedDesc ~= nil then
			local tooltip = {
				floatingui.renderSection( {
					data = smwData[t( 'SMW_ProductionStateDesc' )]
				} ),
				floatingui.renderSection( {
					data = smwData[t( 'SMW_ProductionState' )],
					desc = matchedDesc
				} )
			}

			indicator['tooltip'] = table.concat( tooltip )
		end

		return indicator
	end

	--- Get the content used for FloatingUI tooltips
	---
	--- @param key string i18n key used for the tooltip content
	--- @param source string|nil Text to display in the source column
	--- @return string
	local function getSimpleTooltipContent( key, source )
		local title
		if hasI18n( key .. '_title' ) then
			title = t( key .. '_title' )
		else
			title = t( key )
		end

		local content = {
			floatingui.renderSection( {
				data = title,
				desc = t( key .. '_desc' ),
				inline = true
			} )
		}

		if source ~= nil then
			table.insert( content,
				floatingui.renderSection( {
					col = 2,
					label = t( 'label_data_source' ),
					data = source,
					inline = true
				} )
			)
		end

		return table.concat( content )
	end

	--- Get the translated text with tooltip
	---
	--- @param key string i18n key used for the tooltip content
	--- @param source string|nil Text to display in the source column
	--- @param target string|nil Text to display in the tooltip
	--- @return string
	local function getTextWithTooltip( key, source, target )
		-- Return label if no target is specified (e.g. infobox label)
		target = target or t( key )
		return floatingui.render( target, getSimpleTooltipContent( key, source ), true )
	end

	local function getManufacturer()
		if smwData[t( 'SMW_Manufacturer' )] == nil then return end

		local mfu = manufacturer:get( smwData[t( 'SMW_Manufacturer' )] )
		if mfu == nil then return smwData[t( 'SMW_Manufacturer' )] end

		return infobox.showDescIfDiff(
			table.concat( { '[[', smwData[t( 'SMW_Manufacturer' )], '|', mfu.name, ']]' } ),
			mfu.code
		)
	end

	local function getSize()
		local shipMatrixSize = smwData[t( 'SMW_ShipMatrixSize' )]
		if not shipMatrixSize then return end

		shipMatrixSize = getTextWithTooltip(
			'label_Size_shipmatrix',
			'[https://robertsspaceindustries.com/ship-matrix Ship Matrix]',
			shipMatrixSize
		)

		if smwData[t( 'SMW_Size' )] == nil then return shipMatrixSize end

		local codes = { 'XXS', 'XS', 'S', 'M', 'L', 'XL' }
		local size = smwData[t( 'SMW_Size' )]

		-- For uninitialized SMW properties
		if type( size ) == 'string' then
			size = tonumber( size, 10 )
		end

		size = table.concat( { 'S', size, '/', codes[size] } )
		size = getTextWithTooltip(
			'label_Size_game',
			'Game data',
			size
		)

		return infobox.showDescIfDiff(
			shipMatrixSize,
			size
		)
	end

	local function getSeries()
		local series = smwData[t( 'SMW_Series' )]
		if series == nil then return end
		return string.format(
			'[[:Category:%s|%s]]',
			string.format( t( 'category_series' ), series ),
			series
		)
	end

	--- Cost section
	local function getCostSection()
		local tabberData = {}
		local section

		tabberData['label1'] = t( 'label_Pledge' )
		section = {
			infobox:renderItem( {
				label = t( 'label_Standalone' ),
				data = infobox.showDescIfDiff( smwData[t( 'SMW_PledgePrice' )],
					smwData[t( 'SMW_OriginalPledgePrice' )] ),
				tooltip = getSimpleTooltipContent( 'label_Standalone' )
			} ),
			infobox:renderItem( {
				label = t( 'label_Warbond' ),
				data = infobox.showDescIfDiff( smwData[t( 'SMW_WarbondPledgePrice' )],
					smwData[t( 'SMW_OriginalWarbondPledgePrice' )] ),
				tooltip = getSimpleTooltipContent( 'label_Warbond' )
			} ),
			infobox:renderItem( {
				label = t( 'label_Availability' ),
				data = smwData[t( 'SMW_PledgeAvailability' )],
			} ),
		}
		tabberData['content1'] = infobox:renderSection( { content = section, col = 2 }, true )

		-- TODO: Add i18n
		-- TODO: Make a generic tooltip for showing the min, max and average price
		tabberData['label2'] = t( 'label_Universe' )
		section = {
			infobox:renderItem( {
				label = 'Purchase',
				data = infobox.addUnitIfExists( smwData['Average price'], 'aUEC' ) or '🚫 Not available'
			} ),
			infobox:renderItem( {
				label = 'Rental',
				data = infobox.addUnitIfExists( smwData['Average rental price (1 day)'], 'aUEC' ) or '🚫 Not available'
			} )
		}

		tabberData['content2'] = infobox:renderSection( { content = section, col = 2 }, true )

		tabberData['label3'] = t( 'label_Insurance' )

		section = {
			infobox:renderItem( {
				label = t( 'label_Claim' ),
				data = makeTimeReadable( smwData[translate( 'SMW_InsuranceClaimTime' )] ),
			} ),
			infobox:renderItem( {
				label = t( 'label_Expedite' ),
				data = makeTimeReadable( smwData[translate( 'SMW_InsuranceExpediteTime' )] ),
			} ),
			infobox:renderItem( {
				label = t( 'label_ExpediteFee' ),
				data = smwData[translate( 'SMW_InsuranceExpediteCost' )],
				colspan = 2
			} ),
		}
		tabberData['content3'] = infobox:renderSection( { content = section, col = 4 }, true )

		return tabber( tabberData )
	end

	local function getDimensionsSectionData()
		local dimensions = require( 'Module:Dimensions' )
		local dimensionsOutput = dimensions._main( {
			length = smwData[t( 'SMW_EntityLength' )],
			width = smwData[t( 'SMW_EntityWidth' )],
			height = smwData[t( 'SMW_EntityHeight' )],
			mass = smwData[t( 'SMW_Mass' )],
			lengthAlt = smwData[t( 'SMW_RetractedLength' )],
			widthAlt = smwData[t( 'SMW_RetractedWidth' )],
			heightAlt = smwData[t( 'SMW_RetractedHeight' )],
			referenceType = 'human'
		} )
		if dimensionsOutput then
			return {
				content = dimensionsOutput
			}
		else
			return {
				content = {
					infobox:renderItem( {
						label = t( 'label_Length' ),
						data = infobox.showDescIfDiff( smwData[t( 'SMW_EntityLength' )],
							smwData[t( 'SMW_RetractedLength' )] ),
					} ),
					infobox:renderItem( {
						label = t( 'label_Width' ),
						data = infobox.showDescIfDiff( smwData[t( 'SMW_EntityWidth' )],
							smwData[t( 'SMW_RetractedWidth' )] ),
					} ),
					infobox:renderItem( {
						label = t( 'label_Height' ),
						data = infobox.showDescIfDiff( smwData[t( 'SMW_EntityHeight' )],
							smwData[t( 'SMW_RetractedHeight' )] ),
					} ),
					infobox:renderItem( {
						label = t( 'label_Mass' ),
						data = smwData[t( 'SMW_Mass' )],
					} )
				},
				col = 3
			}
		end
	end

	--- Format modifiers for infobox:renderItem
	--- TODO: Maybe make this generic for other infobox modules?
	local function getModifierItemData( data )
		if not data or not data.data then return {} end
		local itemData = {
			class = 'infobox__item--is-cell',
			label = data.label,
			-- Default to 0%
			data = '0%',
			tooltip = data.tooltip
		}
		local x = data.data
		-- Fix for german number format
		if string.find( x, ',', 1, true ) then
			x = string.gsub( x, ',', '.' )
		end
		if type( x ) == 'string' then x = tonumber( x, 10 ) end

		local diff = x - 1
		if diff == 0 then
			itemData.class = itemData.class .. ' infobox__item--null'
		elseif diff > 0 then
			itemData.class = itemData.class .. ' infobox__item--negative'
			itemData.data = '+' .. tostring( math.abs( diff ) * 100 ) .. '%'
		elseif diff < 0 then
			itemData.class = itemData.class .. ' infobox__item--positive'
			itemData.data = '-' .. tostring( math.abs( diff ) * 100 ) .. '%'
		end
		return itemData
	end

	local function getHullSectionData()
		return {
			content = {
				infobox:renderItem( getModifierItemData( {
					label = t( 'label_ModifierDamageTakenPhysical' ),
					data = smwData[t( 'SMW_PhysicalDamageModifier' )],
					tooltip = getSimpleTooltipContent( 'label_ModifierDamageTakenPhysical' ),
				} ) ),
				infobox:renderItem( getModifierItemData( {
					label = t( 'label_ModifierDamageTakenEnergy' ),
					data = smwData[t( 'SMW_EnergyDamageModifier' )],
					tooltip = getSimpleTooltipContent( 'label_ModifierDamageTakenEnergy' ),
				} ) ),
				infobox:renderItem( getModifierItemData( {
					label = t( 'label_ModifierDamageTakenDistortion' ),
					data = smwData[t( 'SMW_DistortionDamageModifier' )],
					tooltip = getSimpleTooltipContent( 'label_ModifierDamageTakenDistortion' ),
				} ) ),
				infobox:renderItem( getModifierItemData( {
					label = t( 'label_ModifierDamageTakenThermal' ),
					data = smwData[t( 'SMW_ThermalDamageModifier' )],
					tooltip = getSimpleTooltipContent( 'label_ModifierDamageTakenThermal' ),
				} ) ),
				infobox:renderItem( getModifierItemData( {
					label = t( 'label_ModifierDamageTakenBiochemical' ),
					data = smwData[t( 'SMW_BiochemicalDamageModifier' )],
					tooltip = getSimpleTooltipContent( 'label_ModifierDamageTakenBiochemical' ),
				} ) ),
				infobox:renderItem( getModifierItemData( {
					label = t( 'label_ModifierDamageTakenStun' ),
					data = smwData[t( 'SMW_StunDamageModifier' )],
					tooltip = getSimpleTooltipContent( 'label_ModifierDamageTakenStun' ),
				} ) ),
				infobox:renderItem( getModifierItemData( {
					label = t( 'label_CrossSection' ),
					data = smwData[t( 'SMW_CrossSectionSignatureModifier' )],
					tooltip = getSimpleTooltipContent( 'label_CrossSection' ),
				} ) ),
				infobox:renderItem( getModifierItemData( {
					label = t( 'label_Electromagnetic' ),
					data = smwData[t( 'SMW_ElectromagneticSignatureModifier' )],
					tooltip = getSimpleTooltipContent( 'label_Electromagnetic' ),
				} ) ),
				infobox:renderItem( getModifierItemData( {
					label = t( 'label_Infrared' ),
					data = smwData[t( 'SMW_InfraredSignatureModifier' )],
					tooltip = getSimpleTooltipContent( 'label_Infrared' ),
				} ) )
				-- Health is broken in the API and returns 0
				--infobox:renderItem( {
				--	class = 'infobox__item--is-cell',
				--	label = t( 'label_Health' ),
				--	data = smwData[ t( 'SMW_HealthPoint' ) ]
				--} )
			},
			contentClass = 'infobox__sectionContent--has-cells',
			col = 6
		}
	end

	--- Specifications section
	local function getSpecificationsSection()
		local tabberData = {}
		local section

		tabberData['label1'] = t( 'label_Dimensions' )
		tabberData['content1'] = infobox:renderSection( getDimensionsSectionData(), true )

		tabberData['label2'] = t( 'label_Hull' )
		tabberData['content2'] = infobox:renderSection( getHullSectionData(), true )

		tabberData['label3'] = t( 'label_Speed' )

		local function getRangeItemData( key, unit )
			local value = smwData[t( 'SMW_' .. key )]
			if not value then return {} end

			local min = BOUNDS[key].min
			local max = BOUNDS[key].max
			local totalRange = max - min
			local endPercentage = ((value - min) / totalRange) * 100

			return {
				label = t( 'label_' .. key ),
				-- TODO: Add i18n for unit
				data = value .. ' ' .. unit,
				range = {
					['start'] = '0%',
					['end'] = tostring( endPercentage ) .. '%'
				}
			}
		end

		-- Acceleration are broken in the API and return 0
		section = {
			infobox:renderItem( getRangeItemData( 'ScmSpeed', 'm/s' ) ),
			--infobox:renderItem( {
			--	label = t( 'label_0ToScm' ),
			--	data = smwData[ t( 'SMW_ZeroToScmSpeedTime' ) ]
			--} ),
			--infobox:renderItem( {
			--	label = t( 'label_ScmTo0' ),
			--	data = smwData[ t( 'SMW_ScmSpeedToZeroTime' ) ]
			--} ),
			infobox:renderItem( getRangeItemData( 'MaximumSpeed', 'm/s' ) ),
			--infobox:renderItem( {
			--	label = t( 'label_0ToMax' ),
			--	data = smwData[ t( 'SMW_ZeroToMaximumSpeedTime' ) ]
			--} ),
			--infobox:renderItem( {
			--	label = t( 'label_MaxTo0' ),
			--	data = smwData[ t( 'SMW_MaximumSpeedToZeroTime' ) ]
			--} ),
			infobox:renderItem( getRangeItemData( 'ReverseSpeed', 'm/s' ) ),
			infobox:renderItem( getRangeItemData( 'RollRate', '°/s' ) ),
			infobox:renderItem( getRangeItemData( 'PitchRate', '°/s' ) ),
			infobox:renderItem( getRangeItemData( 'YawRate', '°/s' ) ),
		}
		tabberData['content3'] = infobox:renderSection( { content = section }, true )

		tabberData['label4'] = t( 'label_Fuel' )
		section = {
			infobox:renderItem( {
				label = t( 'label_HydrogenCapacity' ),
				data = smwData[t( 'SMW_HydrogenFuelCapacity' )],
			} ),
			infobox:renderItem( {
				label = t( 'label_HydrogenIntake' ),
				data = smwData[t( 'SMW_HydrogenFuelIntakeRate' )],
			} ),
			infobox:renderItem( {
				label = t( 'label_QuantumCapacity' ),
				data = smwData[t( 'SMW_QuantumFuelCapacity' )],
			} ),
		}
		tabberData['content4'] = infobox:renderSection( { content = section, col = 2 }, true )

		return tabber( tabberData )
	end

	local function getSites( sitesData )
		local links = {}

		for _, site in ipairs( sitesData ) do
			if site.attribute then
				local query = smwData[translate( site.attribute )]

				if query ~= nil then
					table.insert( links, infobox:renderLinkButton( {
						label = t( site.label ),
						link = query
					} ) )
				end
			else
				local query = smwData[translate( site.data )]

				if query ~= nil then
					if site.data == 'SMW_ClassName' or site.data == 'SMW_UUID' then
						query = string.lower( query )
					else
						query = mw.uri.encode( query, 'PATH' )
					end

					-- TODO: This is no ideal, we should make this more generic and reusuable
					if site.label == 'FleetYards' then
						query = string.lower( string.gsub( query, '%%20', '-' ) )
					end

					table.insert( links, infobox:renderLinkButton( {
						label = t( site.label ),
						link = string.format( site.format, query )
					} ) )
				end
			end
		end

		return links
	end

	local image = self.frameArgs[translate( 'ARG_Image' )] or self.frameArgs['image'] or smwData['image']
	infobox:renderImage( image )

	infobox:renderIndicator( getIndicator() )
	infobox:renderHeader( {
		title = smwData[t( 'SMW_Name' )],
		--- e.g. Aegis Dynamics (AEGS)
		subtitle = getManufacturer()
	} )


	--- Role, Size, Series and Loaners
	infobox:renderSection( {
		content = {
			infobox:renderItem( {
				label = t( 'label_Role' ),
				data = infobox.tableToCommaList( smwData[t( 'SMW_Role' )] ),
			} ),
			infobox:renderItem( {
				label = t( 'label_Size' ),
				data = getSize(),
			} ),
			infobox:renderItem( {
				label = t( 'label_Series' ),
				data = getSeries(),
			} ),
			infobox:renderItem( {
				label = t( 'label_Loaner' ),
				data = infobox.tableToCommaList( smwData[t( 'SMW_LoanerVehicle' )] ),
				tooltip = getSimpleTooltipContent(
					'label_Loaner',
					'[https://support.robertsspaceindustries.com/hc/en-us/articles/360003093114-Loaner-Ship-Matrix Loaner Ship Matrix]'
				)
			} ),
		},
		col = 2
	} )


	--- Capacity
	infobox:renderSection( {
		title = t( 'label_Capacity' ),
		col = 3,
		content = {
			infobox:renderItem( {
				label = t( 'label_Crew' ),
				data = infobox.formatRange( smwData[t( 'SMW_MinimumCrew' )], smwData[t( 'SMW_MaximumCrew' )], true ),
			} ),
			infobox:renderItem( {
				label = t( 'label_Cargo' ),
				data = smwData[t( 'SMW_CargoCapacity' )],
			} ),
			infobox:renderItem( {
				label = t( 'label_Stowage' ),
				data = smwData[t( 'SMW_VehicleInventory' )],
			} ),
		},
	} )


	--- Cost
	infobox:renderSection( {
		title = t( 'label_Cost' ),
		class = 'infobox__section--tabber',
		content = getCostSection(),
	} )


	--- Specifications
	infobox:renderSection( {
		title = t( 'label_Specifications' ),
		class = 'infobox__section--tabber',
		content = getSpecificationsSection(),
	} )


	--- Lore section
	infobox:renderSection( {
		title = t( 'label_Lore' ),
		col = 2,
		content = {
			infobox:renderItem( {
				label = t( 'label_Released' ),
				data = smwData[t( 'SMW_LoreReleaseDate' )]
			} ),
			infobox:renderItem( {
				label = t( 'label_Retired' ),
				data = smwData[t( 'SMW_LoreRetirementDate' )]
			} ),
		},
	} )


	--- Development section
	infobox:renderSection( {
		title = t( 'label_Development' ),
		col = 2,
		content = {
			infobox:renderItem( {
				label = t( 'label_Announced' ),
				data = smwData[t( 'SMW_ConceptAnnouncementDate' )]
			} ),
			infobox:renderItem( {
				label = t( 'label_ConceptSale' ),
				data = smwData[t( 'SMW_ConceptSaleDate' )]
			} ),
		},
	} )


	--- Metadata section
	infobox:renderSection( {
		class = 'infobox__section--metadata infobox__section--hasBackground',
		content = {
			infobox:renderItem( {
				label = t( 'SMW_UUID' ),
				data = smwData[t( 'SMW_UUID' )],
				row = true,
				spacebetween = true
			} ),
			infobox:renderItem( {
				label = t( 'SMW_ClassName' ),
				data = smwData[t( 'SMW_ClassName' )],
				row = true,
				spacebetween = true
			} ),
			infobox:renderItem( {
				label = t( 'SMW_GameBuild' ),
				data = smwData[t( 'SMW_GameBuild' )],
				row = true,
				spacebetween = true
			} )
		},
	} )

	--- Actions section
	if smwData[t( 'SMW_UUID' )] then
		infobox:renderSection( {
			class = 'infobox__section--actions infobox__section--hasBackground',
			content = {
				infobox:renderItem( {
					icon = 'WikimediaUI-Search.svg',
					data = t( 'label_actions_find_item_title' ),
					desc = t( 'label_actions_find_item_text' ),
					-- FIXME: Make this configurable?
					link = 'https://finder.cstone.space/search/' .. smwData[t( 'SMW_UUID' )]
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
						data = table.concat( getSites( data.official_sites ), '' )
					} ),
					infobox:renderItem( {
						label = t( 'label_CommunitySites' ),
						data = table.concat( getSites( data.community_sites ), '' )
					} ),
				},
				class = 'infobox__section--linkButtons',
			}, true )
		}
	} )

	return infobox:renderInfobox( nil, smwData[t( 'SMW_Name' )] )
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

	local size = self.smwData[t( 'SMW_ShipMatrixSize' )]
	local size_cat, pledge_cat
	local isGroundVehicle = isGroundVehicle( self.smwData )

	if isGroundVehicle then
		--Ground vehicle has no ship matrix size currently
		--size_cat = 'category_ground_vehicle_size'
		pledge_cat = 'category_ground_vehicle_pledge'
		table.insert(
			self.categories,
			string.format( '[[Category:%s]]', t( 'category_ground_vehicle' ) )
		)
	else
		size_cat = 'category_ship_size'
		pledge_cat = 'category_ship_pledge'
		table.insert(
			self.categories,
			string.format( '[[Category:%s]]', t( 'category_ship' ) )
		)
	end

	if size ~= nil and size_cat then
		table.insert(
			self.categories,
			string.format( '[[Category:%s]]', string.format( t( size_cat ), size ) )
		)
	end

	if self.smwData[t( 'SMW_Manufacturer' )] ~= nil then
		local manufacturer = string.gsub( self.smwData[t( 'SMW_Manufacturer' )], '%[+', '' )
		manufacturer = string.gsub( manufacturer, '%]+', '' )

		table.insert(
			self.categories,
			string.format( '[[Category:%s]]', manufacturer )
		)
	end

	if self.smwData[t( 'SMW_ProductionState' )] ~= nil then
		table.insert(
			self.categories,
			string.format( '[[Category:%s]]', self.smwData[t( 'SMW_ProductionState' )] )
		)
	end

	if self.smwData[t( 'SMW_Series' )] ~= nil then
		table.insert(
			self.categories,
			string.format( '[[Category:%s]]',
				string.format( t( 'category_series' ), self.smwData[t( 'SMW_Series' )] ) )
		)
	end

	if pledge_cat and self.smwData[t( 'SMW_PledgePrice' )] ~= nil then
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
		vehicleType = t( 'shortdesc_ground_vehicle' )
	else
		vehicleType = t( 'shortdesc_ship' )
	end

	if self.smwData[t( 'SMW_Role' )] ~= nil then
		local vehicleRole = self.smwData[t( 'SMW_Role' )]
		if type( vehicleRole ) == 'table' then
			vehicleRole = table.concat( vehicleRole, ' ' )
		end

		vehicleRole = string.lower( vehicleRole )

		for _, noun in pairs( config.role_suffixes ) do
			local match = string.find( vehicleRole, '%f[%a]' .. noun .. '%f[%A]' )
			--- Remove suffix from role
			if match then
				vehicleRole = mw.text.trim( string.gsub( vehicleRole, noun, '' ) )
				vehicleType = noun
			end
		end

		shortdesc = string.format( '%s %s', vehicleRole, vehicleType )
	else
		shortdesc = vehicleType
	end

	if not isGroundVehicle and self.smwData[t( 'SMW_ShipMatrixSize' )] ~= nil then
		local vehicleSize = self.smwData[t( 'SMW_ShipMatrixSize' )]
		--- Special handling for single-seat ship
		if self.smwData[t( 'SMW_MaximumCrew' )] ~= nil and self.smwData[t( 'SMW_MaximumCrew' )] == 1 then
			vehicleSize = t( 'shortdesc_single_seat' )
		end

		shortdesc = string.format( '%s %s', vehicleSize, shortdesc )
	end

	if self.smwData[t( 'SMW_Manufacturer' )] ~= nil then
		local mfuname = self.smwData[t( 'SMW_Manufacturer' )]
		local man = manufacturer:get( mfuname )
		--- Use short name if possible
		if man ~= nil and man.shortname ~= nil then mfuname = man.shortname end

		shortdesc = string.format( t( 'shortdesc_manufactured_by' ), shortdesc, mfuname )
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

	local queryName = self.frameArgs[translate( 'ARG_SmwQueryName' )] or
		self.frameArgs[translate( 'ARG_Name' )] or
		mw.title.getCurrentTitle().fullText

	return debug.collapsedDebugSections( {
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
	} )
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
	if instance.frameArgs['debug'] ~= nil then
		local debug = require( 'Module:Common/Debug' )

		debugOutput = debug.collapsedDebugSections( {
			{
				title = 'SMW Set Data',
				content = mw.getCurrentFrame():callParserFunction( '#tag',
					{ 'nowiki', mw.dumpObject( instance.setData or {} ) } ),
			},
		} )
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
	if instance.frameArgs['debug'] ~= nil then
		debugOutput = instance:makeDebugOutput()
	end

	return instance:getInfobox() .. debugOutput
end

--- "Main" entry point for templates that saves the API Data and outputs the infobox
---
--- @param frame table Invocation frame
--- @return string
function Vehicle.main( frame )
	local instance = Vehicle:new()
	instance:setFrame( frame )
	instance:saveApiData()
	instance:getSmwData()

	local debugOutput = ''
	if instance.frameArgs['debug'] ~= nil then
		debugOutput = instance:makeDebugOutput()
	end

	local infobox = instance:getInfobox()

	-- Only set categories and short desc if this is the page that also holds the smw attributes
	-- Allows outputting vehicle infoboxes on other pages without setting categories
	if instance.smwData ~= nil then
		instance:setCategories()
		instance:setShortDescription()
		-- FIXME: Is there a cleaner way?
		infobox = infobox .. common.generateInterWikiLinks( mw.title.getCurrentTitle().text )
	end

	return infobox .. debugOutput .. table.concat( instance.categories )
end

---
function Vehicle.test( page )
	page = page or '300i'

	local instance = Vehicle:new()
	instance.frameArgs = {}
	instance.frameArgs[translate( 'ARG_Name' )] = page

	instance:saveApiData()
	mw.logObject( instance:getSmwData() )
	instance:getInfobox()
end

return Vehicle

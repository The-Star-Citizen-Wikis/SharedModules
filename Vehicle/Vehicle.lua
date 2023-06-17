local Vehicle = {}

local metatable = {}
local methodtable = {}

metatable.__index = methodtable

local TNT = require( 'Module:Translate' ):new()
local common = require( 'Module:Common' )
local api = require( 'Module:Common/Api' )
local manufacturer = require( 'Module:Manufacturer' )._manufacturer
local hatnote = require( 'Module:Hatnote' )._hatnote
local data = mw.loadJsonData( 'Module:Vehicle/data.json' )

local lang = mw.getContentLanguage()


--- Calls TNT with the given key
---
--- @param key string The translation key
--- @param addSuffix boolean Adds a language suffix if data.smw_multilingual_text is true
--- @return string If the key was not found in the .tab page, the key is returned
local function translate( key, addSuffix )
    addSuffix = addSuffix or false
    local success, translation

    local function multilingualIfActive( input )
        if addSuffix and data.smw_multilingual_text == true then
            return string.format( '%s@%s', input, data.module_lang or mw.getContentLanguage():getCode() )
        end

        return input
    end

    if data.module_lang ~= nil then
        success, translation = pcall( TNT.formatInLanguage, data.module_lang, 'Module:Vehicle/i18n.json', key or '' )
    else
        success, translation = pcall( TNT.format, 'Module:Vehicle/i18n.json', key or '' )
    end

    if not success or translation == nil then
        return multilingualIfActive( key )
    end

    return multilingualIfActive( translation )
end


--- Creates the object that is used to query the SMW store
---
--- @param page string the vehicle page containing data
--- @return table
local function makeSmwQueryObject( page )
    local langSuffix = ''
    if data.smw_multilingual_text == true then
        langSuffix = '+lang=' .. ( data.module_lang or mw.getContentLanguage():getCode() )
    end

    return {
        string.format( '[[%s]]', page ),
        string.format( '?%s#-', translate( 'SMW_Name' ) ),
        string.format( '?%s#-', translate( 'SMW_Manufacturer' ) ),
        string.format( '?%s#-', translate( 'SMW_ProductionState' ) ), langSuffix,
        string.format( '?%s#-', translate( 'SMW_Role' ) ), langSuffix,
        string.format( '?%s#-', translate( 'SMW_ShipMatrixSize' ) ), langSuffix,
        string.format( '?%s#-', translate( 'SMW_Size' ) ),
        string.format( '?%s#-', translate( 'SMW_Series' ) ),
        string.format( '?%s', translate( 'SMW_LoanerVehicle' ) ),
        string.format( '?%s#-', translate( 'SMW_MinimumCrew' ) ),
        string.format( '?%s#-', translate( 'SMW_MaximumCrew' ) ),
        string.format( '?%s', translate( 'SMW_CargoCapacity' ) ) ,
        string.format( '?%s', translate( 'SMW_VehicleInventory' ) ) ,
        string.format( '?%s', translate( 'SMW_PledgePrice' ) ),
        string.format( '?%s', translate( 'SMW_OriginalPledgePrice' ) ),
        string.format( '?%s', translate( 'SMW_WarbondPledgePrice' ) ),
        string.format( '?%s', translate( 'SMW_OriginalWarbondPledgePrice' ) ),
        string.format( '?%s#-', translate( 'SMW_PledgeAvailability' ) ),
        string.format( '?%s#-n', translate( 'SMW_InsuranceClaimTime' ) ),
        string.format( '?%s#-n', translate( 'SMW_InsuranceExpediteTime' ) ),
        string.format( '?%s', translate( 'SMW_InsuranceExpediteCost' ) ),
        string.format( '?%s', translate( 'SMW_EntityLength' ) ),
        string.format( '?%s', translate( 'SMW_RetractedLength' ) ),
        string.format( '?%s', translate( 'SMW_EntityWidth' ) ),
        string.format( '?%s', translate( 'SMW_RetractedWidth' ) ),
        string.format( '?%s', translate( 'SMW_EntityHeight' ) ),
        string.format( '?%s', translate( 'SMW_RetractedHeight' ) ),
        string.format( '?%s', translate( 'SMW_Mass' ) ),
        string.format( '?%s', translate( 'SMW_ScmSpeed' ) ),
        string.format( '?%s', translate( 'SMW_ZeroToScmSpeedTime' ) ),
        string.format( '?%s', translate( 'SMW_ScmSpeedToZeroTime' ) ),
        string.format( '?%s', translate( 'SMW_MaximumSpeed' ) ),
        string.format( '?%s', translate( 'SMW_ZeroToMaximumSpeedTime' ) ),
        string.format( '?%s', translate( 'SMW_MaximumSpeedToZeroTime' ) ),
        string.format( '?%s', translate( 'SMW_ReverseSpeed' ) ),
        string.format( '?%s', translate( 'SMW_RollRate' ) ),
        string.format( '?%s', translate( 'SMW_PitchRate' ) ),
        string.format( '?%s', translate( 'SMW_YawRate' ) ),
        string.format( '?%s', translate( 'SMW_HydrogenFuelCapacity' ) ),
        string.format( '?%s', translate( 'SMW_HydrogenFuelIntakeRate' ) ),
        string.format( '?%s', translate( 'SMW_QuantumFuelCapacity' ) ),
        string.format( '?%s#-', translate( 'SMW_CrossSectionSignatureModifier' ) ),
        string.format( '?%s#-', translate( 'SMW_ElectromagneticSignatureModifier' ) ),
        string.format( '?%s#-', translate( 'SMW_InfraredSignatureModifier' ) ),
        string.format( '?%s#-', translate( 'SMW_PhysicalDamageModifier' ) ),
        string.format( '?%s#-', translate( 'SMW_EnergyDamageModifier' ) ),
        string.format( '?%s#-', translate( 'SMW_DistortionDamageModifier' ) ),
        string.format( '?%s#-', translate( 'SMW_ThermalDamageModifier' ) ),
        string.format( '?%s#-', translate( 'SMW_BiochemicalDamageModifier' ) ),
        string.format( '?%s#-', translate( 'SMW_StunDamageModifier' ) ),
        string.format( '?%s', translate( 'SMW_HealthPoint' ) ),
        string.format( '?%s', translate( 'SMW_LoreReleaseDate' ) ),
        string.format( '?%s', translate( 'SMW_LoreRetirementDate' ) ),
        string.format( '?%s', translate( 'SMW_ConceptAnnouncementDate' ) ),
        string.format( '?%s#-', translate( 'SMW_ConceptSaleDate' ) ),
        string.format( '?%s#-', translate( 'SMW_GalactapediaUrl' ) ),
        string.format( '?%s#-', translate( 'SMW_PledgeStoreUrl' ) ),
        string.format( '?%s#-', translate( 'SMW_PresentationUrl' ) ),
        string.format( '?%s#-', translate( 'SMW_PortfolioUrl' ) ),
        string.format( '?%s#-', translate( 'SMW_WhitleysGuideUrl' ) ),
        string.format( '?%s#-', translate( 'SMW_BrochureUrl' ) ),
        string.format( '?%s#-', translate( 'SMW_TrailerUrl' ) ),
        string.format( '?%s#-', translate( 'SMW_QAndAUrl' ) ),
        string.format( '?%s#-', translate( 'SMW_UUID' ) ),
        string.format( '?%s#-', translate( 'SMW_ClassName' ) ),
        string.format( '?%s#-', translate( 'SMW_ShipMatrixName' ) ),
		'?Page image#-=image'
    }
end


local function makeTimeReadable( t )
	if type( t ) == 'string' then t = tonumber( t, 10 ) end
	if t == nil then return end
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
		t = string.gsub( t, pattern, replace )
	end

	return t
end


--- FIXME: This should go to somewhere else, like Module:Common
--- TODO: Should we color code this for buff and debuff?
local function formatModifier( x )
	if type( x ) == 'string' then x = tonumber( x, 10 ) end
	if x == nil then return end
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
--- @return table or nil
function methodtable.getApiDataForCurrentPage( self )
	local query = self.frameArgs[ translate( 'ARG_UUID' ) ] or self.frameArgs[ translate( 'ARG_Name' ) ] or common.removeTypeSuffix(
        mw.title.getCurrentTitle().rootText,
		data.name_suffixes
    )

    local json = mw.text.jsonDecode( mw.ext.Apiunto.get_raw( 'v2/vehicles/' .. query, {
        include = data.includes,
        locale = data.api_locale
    } ) )

    if api.checkResponseStructure( json, true, false ) == false then return end

    self.apiData = json[ 'data' ]
    self.apiData = api.makeAccessSafe( self.apiData )

    return self.apiData
end


--- Base Properties that are shared across all Vehicles
--- @return table SMW Result
function methodtable.setSemanticProperties( self )
	local setData = {}
	local loanerKey = translate( 'SMW_LoanerVehicle' )

	--- Retrieve value(s) from the frame
	---
	--- @param datum table An entry from data.smw_data
	--- @param argKey string The key to use as an accessor to frameArgs
	--- @return string|number|table|nil
	local function getFromArgs( datum, argKey )
		local value
		-- Numbered parameters
		if datum.type == 'range' and type( datum.max ) == 'number' then
			value = {}

			for i = 1, datum.max do
				local argValue = self.frameArgs[ argKey .. i ]
				if argValue then table.insert( value, argValue ) end
			end
		else
			value = self.frameArgs[ argKey ]
		end

		return value
	end

	for _, datum in ipairs( data.smw_data ) do
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

			if #parts == 2 then
				-- Retrieve data from frameArgs
				if parts[ 1 ] == 'ARG' then
					value = getFromArgs( datum, translate( key ) )

					-- Use EN lang as fallback for arg names
					if value == nil then
						local success, translation = pcall( TNT.formatInLanguage, 'en', 'Module:Vehicle/i18n.json', key )
						if success then
							value = getFromArgs( datum, translation )
						end
					end
				-- Retrieve data from API
				elseif parts[ 1 ] == 'API' then
					mw.logObject({
						key_access = parts[2],
						value = self.apiData:get( parts[ 2 ] )
					})

					value = self.apiData:get( parts[ 2 ] )

					if smwKey == loanerKey and type( value ) == 'table' then
						local tmp = {}
						for _, loaner in ipairs( value ) do
							table.insert( tmp, loaner.name )
						end
						value = tmp
					end
				end
			end

			-- Transform value
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
					elseif datum.type == 'multilingual_text' and data.smw_multilingual_text == true then
						value = string.format( '%s@%s', value, data.module_lang or mw.getContentLanguage():getCode() )
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
		data.name_suffixes
	)

	if type( setData[ translate( 'SMW_Manufacturer' ) ] ) == 'string' then
		local man = manufacturer( setData[ translate( 'SMW_Manufacturer' ) ] )
		if man ~= nil then man = man.name end

		setData[ translate( 'SMW_Manufacturer' ) ] = man or setData[ translate( 'SMW_Manufacturer' ) ]
		setData[ translate( 'SMW_Manufacturer' ) ] = string.format( '[[%s]]', setData[ translate( 'SMW_Manufacturer' ) ] )
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
			end

			--- Commodity
			local commodity = require( 'Module:Commodity' ):new()
			commodity:addShopData( self.apiData )
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

    local queryName = self.frameArgs[ translate( 'ARG_smwqueryname' ) ] or mw.title.getCurrentTitle().fullText

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
		placeholderImage = data.placeholder_image
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

		local classMap = {
			[ translate( 'FlightReady' ) ] = 'green',
			[ translate( 'InProduction' ) ] = 'yellow',
			[ translate( 'ActiveForSquadron42' ) ] = 'yellow',
			[ translate( 'InConcept' ) ] = 'red'
		}

		for matcher, class in pairs( classMap ) do
			if string.match( state, matcher ) ~= nil then
				return 'infobox__indicator--' .. class
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
		if smwData[ translate( 'SMW_Series' ) ] == nil then return end
		return string.format(
			'[[:Category:%s|%s]]',
			TNT.format( 'Vehicle', 'category_series', smwData[ translate( 'SMW_Series' ) ] ),
			smwData[ translate( 'SMW_Series' ) ]
		)
	end

	--- Capacity section
	local function getCrew()
		if smwData[ translate( 'SMW_MinimumCrew' ) ] == nil and smwData[ translate( 'SMW_MaximumCrew' ) ] == nil then
			return
		end

		if smwData[ translate( 'SMW_MinimumCrew' ) ] and
		   smwData[ translate( 'SMW_MaximumCrew' ) ] and
		   smwData[ translate( 'SMW_MinimumCrew' ) ] ~= smwData[ translate( 'SMW_MaximumCrew' ) ] then
			return table.concat( { smwData[ translate( 'SMW_MinimumCrew' ) ], ' – ', smwData[ translate( 'SMW_MaximumCrew' ) ] } )
		end

		return smwData[ translate( 'SMW_MinimumCrew' ) ] or smwData[ translate( 'SMW_MaximumCrew' ) ]
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
				label = translate( 'LBL_Avaliblity' ),
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
					query = string.lower( query )
				elseif site.data == 'SMW_ShipMatrixName' then
					query = mw.uri.encode( query, 'PATH' )
				end

				table.insert( links, infobox:renderLinkButton( {
					label = site.label,
					link = string.format( site.format, query )
				} ) )
			end
		end

		return links
	end


	infobox:renderImage( self.frameArgs[ translate( 'ARG_Image' ) ] or smwData[ 'image' ] )

	infobox:renderIndicator( {
		data = smwData[ translate( 'SMW_ProductionState' ) ],
		desc = self.frameArgs[ translate( 'ARG_ProductionStateDesc' ) ],
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
				data = getCrew(),
			} ),
			infobox:renderItem( {
				label = translate( 'LBL_Cargo' ),
				data = smwData[ translate( 'SMW_CargoCapacity' ) ],
			} ),
			infobox:renderItem( {
				label = translate( 'LBL_Stowage' ),
				data = smwData[ translate( 'SMW_VehicleInventory' ) ],
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


	--- Footer
	infobox:renderFooterButton( {
		icon = 'WikimediaUI-Globe.svg',
		label = translate( 'LBL_OtherSites' ),
		type = 'popup',
		content = infobox:renderSection( {
			content = {
				infobox:renderItem( {
					label = translate( 'LBL_OfficialSites' ),
					data = getOfficialSites()
				} ),
				infobox:renderItem( {
					label = translate( 'LBL_CommunitySites' ),
					data = getCommunitySites()
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


--- Sets the main categories for this object
function methodtable.setCategories( self )
	if data.set_categories == false then
		return
	end

	if self.smwData[ translate( 'SMW_ReverseSpeed' ) ] ~= nil then
		table.insert(
			self.categories,
			string.format( '[[Category:%s]]', translate( 'category_ground_vehicle' ) )
		)
	else
		table.insert(
			self.categories,
			string.format( '[[Category:%s]]', translate( 'category_ship' ) )
		)
	end

	if self.smwData[ translate( 'SMW_Manufacturer' ) ] ~= nil then
		table.insert(
			self.categories,
			string.format( '[[Category:%s]]', self.smwData[ translate( 'SMW_Manufacturer' ) ] )
		)
	end

	if self.smwData[ translate( 'SMW_ProductionState' ) ] ~= nil then
		table.insert(
			self.categories,
			string.format( '[[Category:%s]]', self.smwData[ translate( 'SMW_ProductionState' ) ] )
		)
	end
end


--- Save Api Data to SMW store
function methodtable.saveApiData( self )
    self:getApiDataForCurrentPage()
    self:setSemanticProperties()
	self:setCategories()
end


--- Generates debug output
function methodtable.makeDebugOutput( self )
	self.smwData = nil
	local smwData = self:getSmwData()

	local queryName = self.frameArgs[ translate( 'ARG_smwqueryname' ) ] or mw.title.getCurrentTitle().fullText

	local query = makeSmwQueryObject( queryName )
	local queryParts = {
		restrictions = {},
		output = {},
		other = {}
	}
	for _, part in ipairs( query ) do
		if string.sub( part, 1, 1 ) == '?' then
			table.insert( queryParts.output, part )
		elseif string.sub( part, 1, 5 ) == '+lang' then
			local index = #queryParts.output
			queryParts.output[ index ] = string.format( '%s|%s', queryParts.output[ index ], part )
		elseif string.sub( part, 1, 2 ) == '[[' then
			table.insert( queryParts.restrictions, mw.getCurrentFrame():callParserFunction( '#tag', { 'nowiki', part } ) )
		elseif #part > 0 and part ~= nil then
			table.insert( queryParts.other, part )
		end
	end
	local queryString = string.format(
		'Restrictions:<pre>%s</pre>Outputs:<pre>%s</pre>Other:<pre>%s</pre>',
		table.concat( queryParts.restrictions, "\n" ),
		table.concat( queryParts.output, "\n"),
		table.concat( queryParts.other, "\n")
	)

	local debugOutput = mw.html.create( 'div' )
	  :addClass( 'mw-collapsible' )
	  :addClass( 'mw-collapsed' )
	  :tag( 'h3' ):wikitext( 'SMW Query' ):done()
	  :tag( 'div' ):wikitext( queryString ):done()
		-- SMW Data
	  :tag( 'div' ):addClass( 'mw-collapsible' ):addClass( 'mw-collapsed' )
	  :tag( 'h3' ):wikitext( 'SMW Data' ):done()
	  :tag( 'pre' ):addClass( 'mw-collapsible-content' ):wikitext( mw.dumpObject( smwData ) ):done()
	  :done()
		-- Args
	  :tag( 'div' ):addClass( 'mw-collapsible' ):addClass( 'mw-collapsed' )
	  :tag( 'h3' ):wikitext( 'Frame Args' ):done()
	  :tag( 'pre' ):addClass( 'mw-collapsible-content' ):wikitext( mw.dumpObject( self.frameArgs ) ):done()
	  :done()
	  :allDone()

	return tostring( debugOutput )
end


--- New Instance
--- @param type string Term used remove suffix from page title
function Vehicle.new( self )
    local instance = {
        categories = {}
    }
    setmetatable( instance, metatable )
    return instance
end


-- Load and save data from api.star-citizen.wiki
function Vehicle.loadApiData( frame )
	local instance = Vehicle:new()
	instance:setFrame( frame )
	instance:saveApiData()

	local debugOutput
	if instance.frameArgs[ 'debug' ] ~= nil then
		debugOutput = mw.html.create( 'div' )
			:addClass( 'mw-collapsible' ):addClass( 'mw-collapsed' )
			:tag( 'h3' ):wikitext( 'SMW Set Data' ):done()
			:tag( 'pre' ):addClass( 'mw-collapsible-content' ):wikitext( mw.getCurrentFrame():callParserFunction( '#tag', { 'nowiki', mw.dumpObject( instance.setData or {} ) } ) ):done()
			:done()
			:allDone()
	end

	return debugOutput
end


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
function Vehicle.main( frame )
	local instance = Vehicle:new()
	instance:setFrame( frame )
	instance:saveApiData()

	local debugOutput = ''
	if instance.frameArgs[ 'debug' ] ~= nil then
		debugOutput = instance:makeDebugOutput()
	end

	return tostring( instance:getInfobox() ) .. debugOutput
end


---
function Vehicle.test( page )
	page = page or '300i'

	local instance = Vehicle:new()
	instance.frameArgs = {}
	instance.frameArgs[translate( 'ARG_Name' )] = page

	instance:saveApiData()
end


return Vehicle

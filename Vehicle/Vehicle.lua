local Vehicle = {}

local metatable = {}
local methodtable = {}

metatable.__index = methodtable

local TNT = require( 'Module:Translate' ):new()
local common = require( 'Module:Common' )
local api = require( 'Module:Common/Api' )
local log = require( 'Module:Log' )
local manufacturer = require( 'Module:Manufacturer' )._manufacturer
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


--- Request Api Data
--- Using current subpage name without vehicle type suffix
--- @return table or nil
function methodtable.getApiDataForCurrentPage( self )
	local query = self.frameArgs.uuid or self.frameArgs[ 'name' ] or common.removeTypeSuffix(
        mw.title.getCurrentTitle().rootText,
        { 'ship', 'ground vehicle' }
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
	-- Set properties with Template param
	local setData = {
		[ 'Name' ] = self.frameArgs[ 'name' ] or common.removeTypeSuffix(
				mw.title.getCurrentTitle().rootText,
				{ 'ship', 'ground vehicle' }
			),
		[ 'Production state' ] = self.frameArgs[ 'productionstate' ],
		[ 'Role' ] = self.frameArgs[ 'role' ],
		[ 'Series' ] = self.frameArgs[ 'series' ],
		[ 'Ship matrix size' ] = self.frameArgs[ 'size' ],
		--- Pledge info
		[ 'Pledge availability' ] = self.frameArgs[ 'pledgeavailability' ],
		[ 'Pledge price' ] = self.frameArgs[ 'pledgecost' ],
		[ 'Original pledge price' ] = self.frameArgs[ 'originalpledgecost' ],
		[ 'Warbond pledge price' ] = self.frameArgs[ 'warbondcost' ],
		[ 'Original warbond pledge price' ] = self.frameArgs[ 'originalwarbondcost' ],
		--- Crew
		[ 'Minimum crew' ] = self.frameArgs[ 'mincrew' ],
		[ 'Maximum crew' ] = self.frameArgs[ 'maxcrew' ],
		--- Cargo
		[ 'Cargo capacity' ] = self.frameArgs[ 'cargocapacity' ],
		 --- Speed
		[ 'SCM speed' ] = self.frameArgs[ 'combatspeed' ],
		[ 'Maximum speed' ] = self.frameArgs[ 'maxspeed' ],
		--- Dimensions
		[ 'Entity length' ] = self.frameArgs[ 'length' ],
		[ 'Entity width' ] = self.frameArgs[ 'width' ],
		[ 'Entity height' ] = self.frameArgs[ 'height' ],
		[ 'Retracted length' ] = self.frameArgs[ 'retractedlength' ],
		[ 'Retracted width' ] = self.frameArgs[ 'retractedwidth' ],
		[ 'Retracted height' ] = self.frameArgs[ 'retractedheight' ],
		[ 'Mass' ] = self.frameArgs[ 'mass' ],
		--- Lore
		[ 'Lore release date' ] = self.frameArgs[ 'releasedate' ],
		[ 'Lore retirement date' ] = self.frameArgs[ 'retiredate' ],
		--- Development
		[ 'Concept announcement date' ] = self.frameArgs[ 'conceptdate' ],
		[ 'Concept sale date' ] = self.frameArgs[ 'saledate' ],
		--- Official sites
		[ 'Galactapedia URL' ] = self.frameArgs[ 'galactapediaurl' ],
		[ 'Pledge store URL' ] = self.frameArgs[ 'rsistoreurl' ],
		[ 'Brochure URL' ] = self.frameArgs[ 'brochureurl' ],
		[ 'Trailer URL' ] = self.frameArgs[ 'trailerurl' ],
		[ 'Whitleys Guide URL' ] = self.frameArgs[ 'whitleysguideurl' ],
	}

	local manufacturerArg = self.frameArgs[ 'manufacturer' ]
	if manufacturerArg then
		setData[ 'Manufacturer' ] = manufacturer( manufacturerArg ).name or manufacturerArg
	end

	--- Handle numbered parameters
	local dataArgMap = {
		[ 'Presentation URL' ] = 'presentationurl',
		[ 'Q and A URL' ] = 'qandaurl'
	}

	for dataKey, argKey in pairs( dataArgMap ) do
		local dataValues = {
			self.frameArgs[ argKey ]
		}
		for i = 1, 5 do
			local argValue = self.frameArgs[ argKey .. i ]
			if argValue then  table.insert( dataValues, argValue ) end
		end
		setData[ dataKey ] = dataValues
	end

    -- Set properties with API data
    if self.apiData ~= nil then
		-- RSI website data
		setData[ 'Ship matrix name' ] = self.apiData.name
		-- Sizes are lowercased
		if self.apiData.size ~= nil and self.apiData.size ~= 'undefined' then
			setData[ 'Ship matrix size' ] = lang:ucfirst( self.apiData.size )
		end
		setData[ 'Role' ] = self.apiData.foci

		-- Loaner vehicles
		local loaners = {}
		if type( self.apiData.loaner ) == 'table' then
			for _, loaner in pairs( self.apiData.loaner ) do
				table.insert( loaners, string.format( '[[%s]]', loaner.name ) )
			end
		end

		if #loaners > 0 then
			setData[ 'Loaner vehicle' ] = loaners
		end

		-- Flight ready vehicles
		--- Override template parameter with in-game data
		if self.apiData.uuid ~= nil then
			setData[ 'Game build' ] = self.apiData.version
			setData[ 'UUID' ] = self.apiData.uuid
			setData[ 'Class name' ] = self.apiData.class_name
			setData[ 'Size' ] = self.apiData.size_class
			setData[ 'Mass' ] = self.apiData.mass
			setData[ 'Cargo capacity' ] = common.formatNum( self.apiData.cargo_capacity )
			setData[ 'Vehicle inventory' ] = common.formatNum( self.apiData.vehicle_inventory )
			setData[ 'Maximum speed' ] = common.formatNum( self.apiData.speed.max )
			setData[ 'Zero to Maximum speed time' ] = common.formatNum( self.apiData.speed.zero_to_max )
			setData[ 'Maximum speed to zero time' ] = common.formatNum( self.apiData.speed.max_to_zero )
			setData[ 'Health point' ] = common.formatNum( self.apiData.health )

			if self.apiData.armor ~= nil then
				setData[ 'Infrared signature modifier' ] = common.formatNum( self.apiData.armor.signal_infrared )
				setData[ 'Electromagnetic signature modifier' ] = common.formatNum( self.apiData.armor.signal_electromagnetic )
				setData[ 'Cross section signature modifier' ] = common.formatNum( self.apiData.armor.signal_cross_section )
				setData[ 'Physical damage modifier' ] = common.formatNum( self.apiData.armor.damage_physical )
				setData[ 'Energy damage modifier' ] = common.formatNum( self.apiData.armor.damage_energy )
				setData[ 'Distortion damage modifier' ] = common.formatNum( self.apiData.armor.damage_distortion )
				setData[ 'Thermal damage modifier' ] = common.formatNum( self.apiData.armor.damage_thermal )
				setData[ 'Biochemical damage modifier' ] = common.formatNum( self.apiData.armor.damage_biochemical )
				setData[ 'Stun damage modifier' ] = common.formatNum( self.apiData.armor.damage_stun )
			end

			--- Ground vehicle-specific data
			--- Lazy way to differentiate ground vehicle
			--- This is ship matrix data though so it might be inconsistent
			if self.apiData.size == 'vehicle' then
				setData[ 'Reverse speed' ] = common.formatNum( self.apiData.speed.reverse )
			--- Spaceship-specific data
			else
				setData[ 'SCM speed' ] = common.formatNum( self.apiData.speed.scm )
				setData[ 'Zero to SCM speed time' ] = common.formatNum( self.apiData.speed.zero_to_scm )
				setData[ 'SCM speed to zero time' ] = common.formatNum( self.apiData.speed.scm_to_zero )
				setData[ 'Roll rate' ] = common.formatNum( self.apiData.agility.roll or nil, nil )
				setData[ 'Pitch rate' ] = common.formatNum( self.apiData.agility.pitch or nil, nil )
				setData[ 'Yaw rate' ] = common.formatNum( self.apiData.agility.yaw or nil, nil )
				setData[ 'Hydrogen fuel capacity' ] = common.formatNum( self.apiData.fuel.capacity )
				setData[ 'Hydrogen fuel intake rate' ] = common.formatNum( self.apiData.fuel.intake_rate or 0 )

				if self.apiData.quantum ~= nil then
					setData[ 'Quantum fuel capacity' ] = common.formatNum( self.apiData.quantum.quantum_fuel_capacity )
				end
			end

			--- Insurance
			if self.apiData.insurance ~= nil then
				setData[ 'Insurance claim time' ] = common.formatNum( self.apiData.insurance.claim_time or 0 )
				setData[ 'Insurance expedite time' ] = common.formatNum( self.apiData.insurance.expedite_time or 0 )
				setData[ 'Insurance expedite cost' ] = common.formatNum( self.apiData.insurance.expedite_cost or 0 )
			end

			--- Components
			if self.apiData.hardpoints ~= nil and type( self.apiData.hardpoints ) == 'table' and #self.apiData.hardpoints > 0 then
				local hardpoint = require( 'Module:VehicleHardpoint' ):new( self.frameArgs[ 'name' ] or mw.title.getCurrentTitle().fullText )
				hardpoint:setHardPointObjects( self.apiData.hardpoints )
				hardpoint:setParts( self.apiData.parts )
			end

			--- Commodity
			local commodity = require( 'Module:Commodity' ):new()
			commodity:addShopData( self.apiData )
		end
	end

	return mw.smw.set( setData )
end


--- Queries the SMW Store
--- @return table
function methodtable.getSmwData( self )
	-- Cache multiple calls
    if self.smwData ~= nil and self.smwData[ 'Name' ] ~= nil then
        return self.smwData
    end

    local queryName = self.frameArgs[ 'smwqueryname' ] or mw.title.getCurrentTitle().fullText

    local smwData = mw.smw.ask( {
        '[[ ' .. queryName .. ' ]]',
        '?Name#-',
        '?Manufacturer#-',
        '?Production state#-',
        '?Role#-',
        '?Ship matrix size#-',
        '?Size#-',
        '?Series#-',
        '?Loaner vehicle',
        '?Minimum crew#-',
        '?Maximum crew#-',
        '?Cargo capacity',
        '?Vehicle inventory',
        '?Pledge price',
        '?Original pledge price',
        '?Warbond pledge price',
        '?Original warbond pledge price',
        '?Pledge availability#-',
        '?Insurance claim time#-n',
        '?Insurance expedite time#-n',
        '?Insurance expedite cost',
        '?Entity length',
        '?Retracted length',
        '?Entity width',
        '?Retracted width',
        '?Entity height',
        '?Retracted height',
        '?Mass',
        '?SCM speed',
        '?Zero to SCM speed time',
        '?SCM speed to zero time',
        '?Maximum speed',
        '?Zero to Maximum speed time',
        '?Maximum speed to zero time',
        '?Reverse speed',
        '?Roll rate',
        '?Pitch rate',
        '?Yaw rate',
        '?Hydrogen fuel capacity',
        '?Hydrogen fuel intake rate',
        '?Quantum fuel capacity',
        '?Cross section signature modifier',
        '?Electromagnetic signature modifier',
        '?Infrared signature modifier',
        '?Physical damage modifier',
        '?Energy damage modifier',
        '?Distortion damage modifier',
        '?Thermal damage modifier',
        '?Biochemical damage modifier',
        '?Stun damage modifier',
        '?Health point',
        '?Lore release date',
        '?Lore retirement date',
        '?Concept announcement date',
        '?Concept sale date',
        '?Galactapedia URL#-',
        '?Pledge store URL#-',
        '?Presentation URL#-',
        '?Portfolio URL#-',
        '?Whitleys Guide URL#-',
        '?Brochure URL#-',
        '?Trailer URL#-',
        '?Q and A URL#-',
        '?UUID',
        '?Class name',
        '?Ship matrix name',
    } )

    if smwData == nil or smwData[ 1 ] == nil then
        return '[[Category:Pages with script errors]]' .. log.info( 'SMW data not found on page.' )
    end

    self.smwData = smwData[ 1 ]

    return self.smwData
end


--- Creates the infobox
function methodtable.getInfobox( self )
	local smwData = self:getSmwData()

	local infobox = require( 'Module:InfoboxNeue' ):new( {
		placeholderImage = 'Placeholderv2.png'
	} )
	local tabber = require( 'Module:Tabber' ).renderTabber
	local sectionTable = {}

	--- SMW Data load error
	--- Infobox data should always have Name property
	if type( smwData ) ~= 'table' then
		return infobox:renderInfobox( infobox:renderMessage( {
			title = translate( 'error_no_data_title' ),
			desc = translate( 'error_no_data_text' ),
		} ) )
	end

	local function getIndicatorClass()
		if smwData[ 'Production state' ] == nil then return end

		local classMap = {
			[ 'Flight ready' ] = 'green',
			[ 'In production' ] = 'yellow',
			[ 'Active for Squadron 42' ] = 'yellow',
			[ 'In concept' ] = 'red'
		}

		for matcher, class in pairs( classMap ) do
			if string.match( smwData[ 'Production state' ], matcher ) ~= nil then
				return 'infobox__indicator--' .. class
			end
		end
	end

	local function getManufacturer()
		if smwData[ 'Manufacturer' ] == nil then return end

		local mfu = manufacturer( smwData[ 'Manufacturer' ] )
		if mfu == nil then return smwData[ 'Manufacturer' ] end

		return infobox.showDescIfDiff(
			table.concat( { '[[', smwData[ 'Manufacturer' ], '|', mfu.name , ']]' } ),
			mfu.code
		)
	end

	infobox:renderImage( self.frameArgs[ 'image' ] )
	infobox:renderIndicator( {
		data = smwData[ 'Production state' ],
		desc = self.frameArgs[ 'productionstatedesc' ],
		class = getIndicatorClass()
	} )
	infobox:renderHeader( {
		title = smwData[ 'Name' ],
		--- e.g. Aegis Dynamics (AEGS)
		subtitle = getManufacturer()
	} )

	local function getSize()
		if smwData[ 'Size' ] == nil then return smwData[ 'Ship matrix size' ] end
		local codes = { 'XXS', 'XS', 'S', 'M', 'L', 'XL' }
		return infobox.showDescIfDiff(
			smwData[ 'Ship matrix size' ],
			table.concat( { 'S', smwData[ 'Size' ], '/', codes[ smwData[ 'Size' ] ] } )
		)
	end

	local function getSeries()
		if smwData[ 'Series' ] == nil then return end
		return string.format(
			'[[:Category:%s series|%s]]',
			smwData[ 'Series' ], smwData[ 'Series' ]
		)
	end

	infobox:renderItem( {
		label = 'Role',
		data = infobox.tableToCommaList( smwData[ 'Role' ] ),
	} )
	infobox:renderItem( {
		label = 'Size',
		data = getSize(),
	} )
	infobox:renderItem( {
		label = 'Series',
		data = getSeries(),
	} )
	infobox:renderItem( {
		label = 'Loaner',
		data = infobox.tableToCommaList( smwData[ 'Loaner vehicle' ] ),
	} )

	infobox:renderSection( { content = sectionTable, col = 2 } )

	--- Capacity section
	local function getCrew()
		if smwData[ 'Minimum crew' ] and smwData[ 'Maximum crew' ] == nil then return end
		if smwData[ 'Minimum crew' ] and smwData[ 'Maximum crew' ] and smwData[ 'Minimum crew' ] ~= smwData[ 'Maximum crew' ] then
			return table.concat( { smwData[ 'Minimum crew' ], ' – ', smwData[ 'Maximum crew' ] } )
		end

		return smwData[ 'Minimum crew' ] or smwData[ 'Maximum crew' ]
	end

	infobox:renderItem( {
		label = 'Crew',
		data = getCrew(),
	} )
	infobox:renderItem( {
		label = 'Cargo',
		data = smwData[ 'Cargo capacity' ],
	} )
	infobox:renderItem( {
		label = 'Stowage',
		data = smwData[ 'Vehicle inventory' ],
	} )

	infobox:renderSection( { content = sectionTable, title = 'Capacity', col = 3 } )

	--- Cost section
	local function getCostSection()
		local tabberData = {}
		local section

		tabberData['label1'] = 'Pledge'
		section = {
			infobox:renderItem( {
				label = 'Standalone',
				data = infobox.showDescIfDiff( smwData[ 'Pledge price' ], smwData[ 'Original pledge price' ] ),
			} ),
			infobox:renderItem( {
				label = 'Warbond',
				data = infobox.showDescIfDiff( smwData[ 'Warbond pledge price' ], smwData[ 'Original warbond pledge price' ] ),
			} ),
			infobox:renderItem( {
				label = 'Avaliblity',
				data = smwData[ 'Pledge availability' ],
			} ),
		}
		tabberData['content1'] = infobox:renderSection( { content = section, col = 2 }, true )

		tabberData['label2'] = 'Insurance'

		local function makeTimeReadable( t )
			if t ~= nil then
				t = lang:formatDuration( t * 60 )

				local regex = {
					[ '%shours*' ] = 'h',
					[ '%sminutes*' ] = 'm',
					[ '%sseconds*' ] = 's',
					[ ','] = '',
					[ 'and%s'] = ''
				}
				for pattern, replace in pairs( regex ) do
					t = string.gsub( t, pattern, replace )
				end
			end
			return t
		end

		section = {
			infobox:renderItem( {
				label = 'Claim',
				data = makeTimeReadable( smwData[ 'Insurance claim time' ] ),
			} ),
			infobox:renderItem( {
				label = 'Expedite',
				data = makeTimeReadable( smwData[ 'Insurance expedite time' ] ),
			} ),
			infobox:renderItem( {
				label = 'Expedite fee',
				data = smwData[ 'Insurance expedite cost' ],
				colspan = 2
			} ),
		}
		tabberData['content2'] = infobox:renderSection( { content = section, col = 4 }, true )

		--- TODO: Move this back up to the first tab when we fix universe cost
		section = {}

		--- Show message on where the game price data are
		if smwData[ 'UUID' ] ~= nil then
			tabberData['label3'] = 'Universe'
			tabberData['content3'] = infobox:renderMessage( {
				title = 'Persistent Universe data has moved',
				desc = 'Buy and rent information are now at the [[{{FULLPAGENAMEE}}#Universe_availability|universe availability]] section on the page.'
			} )
		end

		return tabber( tabberData )
	end

	sectionTable = { getCostSection() }

	infobox:renderSection( {
		content = sectionTable,
		title = 'Cost',
		class = 'infobox__section--tabber'
	} )

	--- Specifications section
	local function getSpecificationsSection()
		local tabberData = {}
		local section

		tabberData['label1'] = 'Dimensions'
		section = {
			infobox:renderItem( {
				label = 'Length',
				data = infobox.showDescIfDiff( smwData[ 'Entity length' ], smwData[ 'Retracted length' ] ),
			} ),
			infobox:renderItem( {
				label = 'Width',
				data = infobox.showDescIfDiff( smwData[ 'Entity width' ], smwData[ 'Retracted width' ] ),
			} ),
			infobox:renderItem( {
				label = 'Height',
				data = infobox.showDescIfDiff( smwData[ 'Entity height' ], smwData[ 'Retracted height' ] ),
			} ),
			infobox:renderItem( {
				label = 'Mass',
				data = smwData[ 'Mass' ],
			} ),
		}

		tabberData['content1'] = infobox:renderSection( { content =section, col = 3 }, true )

		tabberData['label2'] = 'Speed'
		section = {
			infobox:renderItem( {
				label = 'SCM speed',
				data = smwData[ 'SCM speed' ]
			} ),
			infobox:renderItem( {
				label = '0 to SCM',
				data = smwData[ 'Zero to SCM speed time' ]
			} ),
			infobox:renderItem( {
				label = 'SCM to 0',
				data = smwData[ 'SCM speed to zero time' ]
			} ),
			infobox:renderItem( {
				label = 'Max speed',
				data = smwData[ 'Maximum speed' ]
			} ),
			infobox:renderItem( {
				label = '0 to max',
				data = smwData[ 'Zero to Maximum speed time' ]
			} ),
			infobox:renderItem( {
				label = 'Max to 0',
				data = smwData[ 'Maximum speed to zero time' ]
			} ),
			infobox:renderItem( {
				label = 'Reverse speed',
				data = smwData[ 'Reverse speed' ]
			} ),
			infobox:renderItem( {
				label = 'Roll rate',
				data = smwData[ 'Roll rate' ]
			} ),
			infobox:renderItem( {
				label = 'Pitch rate',
				data = smwData[ 'Pitch rate' ]
			} ),
			infobox:renderItem( {
				label = 'Yaw rate',
				data = smwData[ 'Yaw rate' ]
			} ),
		}
		tabberData['content2'] = infobox:renderSection( { content = section, col = 3 }, true )

		tabberData['label3'] = 'Fuel'
		section = {
			infobox:renderItem( {
				label = 'Hydrogen capacity',
				data = smwData[ 'Hydrogen fuel capacity' ],
			} ),
			infobox:renderItem( {
				label = 'Hydrogen intake',
				data = smwData[ 'Hydrogen fuel intake rate' ],
			} ),
			infobox:renderItem( {
				label = 'Quantum capacity',
				data = smwData[ 'Quantum fuel capacity' ],
			} ),
		}
		tabberData['content3'] = infobox:renderSection( { content = section, col = 2 }, true )

		tabberData['label4'] = 'Hull'

		--- FIXME: This should go to somewhere else, like Module:Common
		--- TODO: Should we color code this for buff and debuff?
		local function formatModifier( x )
			if x == nil then return end
			local diff = x - 1
			local sign = ''
			if diff == 0 then
				--- Display 'None' instead of 0 % for better readability
				return 'None'
			elseif diff > 0 then
				--- Extra space for formatting
				sign = '+ '
			elseif diff < 0 then
				sign = '- '
			end
			return sign .. tostring( math.abs( diff ) * 100 ) .. ' %'
		end

		section = {
			infobox:renderItem( {
				label = 'Cross section',
				data = formatModifier( smwData[ 'Cross section signature modifier' ] ),
			} ),
			infobox:renderItem( {
				label = 'Electromagnetic',
				data = formatModifier( smwData[ 'Electromagnetic signature modifier' ] ),
			} ),
			infobox:renderItem( {
				label = 'Infrared',
				data = formatModifier( smwData[ 'Infrared signature modifier' ] ),
			} ),
			infobox:renderItem( {
				label = 'Physical',
				data = formatModifier( smwData[ 'Physical damage modifier' ] ),
			} ),
			infobox:renderItem( {
				label = 'Energy',
				data = formatModifier( smwData[ 'Energy damage modifier' ] ),
			} ),
			infobox:renderItem( {
				label = 'Distortion',
				data = formatModifier( smwData[ 'Distortion damage modifier' ] ),
			} ),
			infobox:renderItem( {
				label = 'Thermal',
				data = formatModifier( smwData[ 'Thermal damage modifier' ] ),
			} ),
			infobox:renderItem( {
				label = 'Biochemical',
				data = formatModifier( smwData[ 'Biochemical damage modifier' ] ),
			} ),
			infobox:renderItem( {
				label = 'Stun',
				data = formatModifier( smwData[ 'Stun damage modifier' ] ),
			} ),
			infobox:renderItem( {
				label = 'Health',
				data = smwData[ 'Health point' ],
			} ),
		}
		tabberData['content4'] = infobox:renderSection( { content = section, col = 3 }, true )

		return tabber( tabberData )
	end

	sectionTable = { getSpecificationsSection() }

	infobox:renderSection( {
		content = sectionTable,
		title = 'Specifications',
	 	class = 'infobox__section--tabber'
	} )

	--- Lore section
	sectionTable = {
		infobox.renderItem( {
				label = 'Released',
				data = smwData[ 'Lore release date' ]
		} ),
		infobox.renderItem( {
				label = 'Retired',
				data = smwData[ 'Lore retirement date' ]
		} ),
	}

	infobox:renderSection( {
		content = sectionTable,
		title = 'Lore',
		col = 2
	} )

	--- Development section
	sectionTable = {
		infobox:renderItem( {
			label = 'Announced',
			data = smwData[ 'Concept announcement date' ]
		} ),
		infobox:renderItem( {
			label = 'Concept sale',
			data = smwData[ 'Concept sale date' ]
		} ),
	}

	infobox:renderSection( {
		content = sectionTable,
		title = 'Development',
		col = 2
	} )

	--- Other sites
	local function getOfficialSites()
		return {
			infobox:renderLinkButton( {
				label = 'Galactapedia',
				link = smwData[ 'Galactapedia URL' ]
			} ),
			infobox:renderLinkButton( {
				label = 'Pledge store',
				link = smwData[ 'Pledge store URL' ]
			} ),
			infobox:renderLinkButton( {
				label = 'Presentation',
				link = smwData[ 'Presentation URL' ]
			} ),
			infobox:renderLinkButton( {
				label = 'Portfolio',
				link = smwData[ 'Portfolio URL' ]
			} ),
			infobox:renderLinkButton( {
				label = 'Whitley\'s Guide',
				link = smwData[ 'Whitleys Guide URL' ]
			} ),
			infobox:renderLinkButton( {
				label = 'Brochure',
				link = smwData[ 'Brochure URL' ]
			} ),
			infobox:renderLinkButton( {
				label = 'Trailer',
				link = smwData[ 'Trailer URL' ]
			} ),
			infobox:renderLinkButton( {
				label = 'Q&A',
				link = smwData[ 'Q and A URL' ]
			} ),
		}
	end

	local function getCommunitySites()
		local links = {}
		local query

		if smwData[ 'UUID' ] ~= nil then
			table.insert( links, infobox:renderLinkButton( {
				label = 'Universal Item Finder',
				link = string.format(
					'https://finder.cstone.space/search/%s',
					smwData[ 'UUID' ]
				)
			} ) )
		end

		if smwData[ 'Class name' ] ~= nil then
			query = smwData[ 'Class name' ]:lower()
			table.insert( links, infobox:renderLinkButton( {
				label = '#DPSCalculator',
				link = string.format( 'https://www.erkul.games/ship/%s', query )
			} ) )
			table.insert( links, infobox:renderLinkButton( {
				label = 'SPViewer',
				link = string.format( 'https://www.spviewer.eu/pages/ship-performances.html?ship=%s', query )
			} ) )
			table.insert( links, infobox:renderLinkButton( {
				label = 'TIS Ship Map',
				link = string.format( 'https://tradein.space/#/ship_maps/%s', query )
			} ) )
		end

		if smwData[ 'Ship matrix name' ] ~= nil then
			query = mw.uri.encode( smwData[ 'Ship matrix name' ], 'PATH' )
			table.insert( links, infobox:renderLinkButton( {
				label = 'StarShip 42',
				link = string.format( 'https://www.starship42.com/fleetview/single/?source=Star%%20Citizen%%20Wiki&type=matrix&style=colored&s=%s', query )
			} ) )
			table.insert( links, infobox:renderLinkButton( {
				label = 'FleetYards',
				link = string.format( 'https://fleetyards.net/ships/%s', query )
			} ) )
		end

		return links
	end

	sectionTable = {
		infobox:renderItem( {
			label = 'Official sites',
			data = getOfficialSites()
		} ),
		infobox:renderItem( {
			label = 'Community sites',
			data = getCommunitySites()
		} ),
	}

	infobox:renderFooterButton( {
		icon = 'WikimediaUI-Globe.svg',
		label = 'Other sites',
		type = 'popup',
		content = infobox.renderSection( {
			content = table.concat( sectionTable ),
			class = 'infobox__section--linkButtons'
		} )
	} )

	return infobox:renderInfobox( nil, smwData[ 'name' ] )
end


--- Set the frame and load args
--- @param frame table
function methodtable.setFrame( self, frame )
	self.currentFrame = frame
	self.frameArgs = require( 'Module:Arguments' ).getArgs( frame )
end


--- Save Api Data to SMW store
function methodtable.saveApiData( self )
    local apiData = self:getApiDataForCurrentPage()

    self:setSemanticProperties()

    return apiData
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


return Vehicle

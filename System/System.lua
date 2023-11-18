local System = {}

local Starmap = require( 'Module:Starmap' )
local Infobox = require( 'Module:InfoboxNeue' )
local TNT = require( 'Module:Translate' ):new()
local config = mw.loadJsonData( 'Module:System/config.json' )

local lang
if config.module_lang then
	lang = mw.getLanguage( config.module_lang )
else
	lang = mw.getContentLanguage()
end
local langCode = lang:getCode()

--- Wrapper function for Module:Translate.translate
-- @param key string The translation key
-- @param addSuffix boolean Adds a language suffix if config.smw_multilingual_text is true
-- @return string If the key was not found in the .tab page, the key is returned
local function t( key, addSuffix, ... )
	return TNT:translate( 'Module:System/i18n.json', config, key, addSuffix, {...} ) or key
end

--- Alternative for doing table[key][key], this returns nil instead of an error if it doesn't exist
-- @param table object
local function e( object, ... )
	local value = object
	if not value then return end
	for _, key in ipairs( { ... } ) do
		value = value[ key ]
		if value == nil then return nil end
	end
	return value
end

--- Does string end with x
-- @param str string
-- @param suffix string
-- @return boolean
local function endsWith( str, suffix )
    return string.sub( str, -string.len( suffix ) ) == suffix
end

--- Does string start with x
-- @param str string
-- @param prefix string
-- @return boolean
local function startsWith( str, prefix )
    return string.sub( str, 1, string.len( prefix ) ) == prefix
end

--- Filter table
-- @param array table
-- @param key string
-- @param value any
-- @param zero any Value to return if zero matches
local function filter( array, key, value, zero )
	local matches = {}
	
	for _, item in ipairs( array ) do
		if item[ key ] == value then
			table.insert( matches, item )
		end
	end
	
	if zero and #matches == 0 then
		return zero
	else
		return matches
	end
end

--- Split a string with seperator
-- @param str string Input
-- @param sep string Seperator
local function split( str, sep )
	local matches = {}
	
	for str in string.gmatch( str, '([^' .. sep .. ']+)' ) do
		table.insert( matches, str )
	end
	
	return matches
end

--- If but inline
-- @param condition boolean
-- @param truthy any What to return if true
-- @param falsy any What to return if false
local function inlineIf( condition, truthy, falsy )
	if not not condition then return truthy else return falsy end
end

-- @param categories table Plain text categories in array
local function convertCategories( categories )
	local mapped = {}

	for _, category in pairs( categories ) do
		if category ~= nil then
			if string.sub( category, 1, 2 ) ~= '[[' then
				category = string.format( '[[Category:%s]]', category )
			end
			
			table.insert( mapped, category )
		end
	end

	return table.concat( mapped )
end

-- @param frame table https://www.mediawiki.org/wiki/Extension:Scribunto/Lua_reference_manual#Frame_object
function System.main( frame )
	local args = frame:getParent().args
	local infobox = Infobox:new( { placeholderImage = config[ 'placeholder_image' ] } )
	
	local name = args[ 'name' ]
	local code = args[ 'code' ]
	local system = Starmap.findStructure( 'system', code or name ) or {}
	
	if (name == nil or name == '') and system[ 'name' ] then name = system[ 'name' ] end
	if (code == nil or code == '') and system[ 'code' ] then code = system[ 'code' ] end
	
	if name == nil then
		return infobox:renderInfobox( infobox:renderMessage( { 
			title = t( 'error_no_data_title' ),
			desc = t( 'error_no_data_desc' )
		} ) )
	end
	
	local type = args[ 'type' ] or system[ 'type' ]
	local status = args[ 'status' ] or system[ 'status' ]
	local translatedType = nil
	local translatedStatus = nil
	if type then translatedType = t( 'val_type_' .. string.lower( type ) ) end
	if status then translatedStatus = t( 'val_status_' .. string.lower( status ) ) end
	
	local image = args[ 'image' ]
	local systemObjects = Starmap.systemObjects( code or name ) or {}
	local planets = args[ 'planets' ] or #filter( systemObjects, 'type', 'PLANET', '' )
	local satellites = args[ 'satellites' ] or #filter( systemObjects, 'type', 'SATELLITE', '' )
	local asteroidBelts = args[ 'asteroidbelts' ] or #filter( systemObjects, 'type', 'ASTEROID_BELT', '' )
	local asteroidFields = args[ 'asteroidfields' ] or #filter( systemObjects, 'type', 'ASTEROID_FIELDS', '' )
	local anomalies = args[ 'anomalies' ] or #filter( systemObjects, 'type', 'ANOMALY', '' )
	local stations = args[ 'stations' ] or #filter( systemObjects, 'type', 'MANMADE', '' )
	local jumppoints = args[ 'jumppoints' ] or #filter( systemObjects, 'type', 'JUMPPOINT', '' )
	local blackholes = args[ 'blackholes' ] or #filter( systemObjects, 'type', 'BLACKHOLE', '' )
	local pois = args[ 'pois' ] or #filter( systemObjects, 'type', 'POI', '' )
	local starTypes = args[ 'startypes' ]
	local starmapLink = args[ 'starmap' ] or inlineIf( code, Starmap.link( code ), nil  )
	local discoveredIn = args[ 'discoveredin' ]
	local discoveredBy = args[ 'discoveredby' ]
	local sensorDanger = inlineIf( args[ 'danger' ], tonumber( args[ 'danger' ] ), tonumber( e( system, 'aggregated_danger' ) or 0 ) )
	local sensorEconomy = inlineIf( args[ 'economy' ], tonumber( args[ 'economy' ] ), tonumber( e( system, 'aggregated_economy' ) or 0 ) )
	local sensorPopulation = inlineIf( args[ 'population' ], tonumber( args[ 'population' ] ), tonumber( e( system, 'aggregated_population' ) or 0 ) )
	local historicalNames = args[ 'historicalnames' ]
	local population = args[ 'population' ]
	local affiliation = args[ 'affiliation' ] or e( system, 'affiliation', 1, 'name' )
	local size = inlineIf( system[ 'aggregated_size' ], tonumber( system[ 'aggregated_size' ] ), nil ) -- Argument version is checked for later
	local affiliationLink = nil
	if affiliation then affiliationLink = inlineIf( startsWith( affiliation, '[[' ), '', '[[' ) .. affiliation .. inlineIf( endsWith( affiliation, ']]' ), '', ']]' ) end
	
	local starTypeArray = {}
	if starTypes == nil or starTypes == '' then
		local stars = filter( systemObjects, 'type', 'STAR' )
		
		for _, star in ipairs( stars ) do
			if star[ 'subtype' ] then
				table.insert( starTypeArray, config[ 'subtype_rename' ][ star[ 'subtype' ][ 'name' ] ] or star[ 'subtype' ][ 'name' ] )
			end
		end
		
		starTypes = table.concat( starTypeArray, ', ' )
	end
	
	infobox:renderImage( image )
	
	if endsWith( name, ' system' ) == false then name = name .. ' system' end
	
	infobox:renderHeader( {
		title = name,
		subtitle = affiliationLink
	} )

	infobox:renderSection( {
		content = {
			infobox:renderItem( {
				label = t( 'lbl_type' ),
				data = translatedType,
			} ),
			infobox:renderItem( {
				label = t( 'lbl_size' ),
				data = args[ 'size' ] or inlineIf( size, tostring( size ) .. ' AU', '? AU' ),
			} ),
			infobox:renderItem( {
				label = t( 'lbl_status' ),
				data = translatedStatus,
			} ),
			infobox:renderItem( {
				label = inlineIf( #split( starTypes or '', ',' ) == 1, t( 'lbl_star_type' ), t( 'lbl_star_types' ) ),
				data = starTypes,
			} ),
			infobox:renderItem( {
				label = t( 'lbl_population' ),
				data = population,
			} ),
		},
		col = 2
	} )

	infobox:renderSection( {
		title = t( 'lbl_astronomical_objects' ),
		content = {
			infobox:renderItem( {
				label = t( 'lbl_planets' ),
				data = inlineIf( planets == 0, nil, tostring( planets ) )
			} ),
			infobox:renderItem( {
				label = t( 'lbl_satellites' ),
				data = inlineIf( satellites == 0, nil, tostring( satellites ) )
			} ),
			infobox:renderItem( {
				label = t( 'lbl_asteroid_belts' ),
				data = inlineIf( asteroidFields == 0, nil, tostring( asteroidFields ) )
			} ),
			infobox:renderItem( {
				label = t( 'lbl_asteroid_fields' ),
				data = inlineIf( asteroidFields == 0, nil, tostring( asteroidFields ) )
			} ),
			infobox:renderItem( {
				label = t( 'lbl_anomalies' ),
				data = inlineIf( anomalies == 0, nil, tostring( anomalies ) )
			} ),
			infobox:renderItem( {
				label = t( 'lbl_stations' ),
				data = inlineIf( stations == 0, nil, tostring( stations ) )
			} ),
			infobox:renderItem( {
				label = t( 'lbl_jump_points' ),
				data = inlineIf( jumppoints == 0, nil, tostring( jumppoints ) )
			} ),
			infobox:renderItem( {
				label = t( 'lbl_blackholes' ),
				data = inlineIf( blackholes == 0, nil, tostring( blackholes ) )
			} ),
			infobox:renderItem( {
				label = t( 'lbl_pois' ),
				data = inlineIf( pois == 0, nil, tostring( pois ) )
			} )
		},
		col = 3
	} )

	if sensorDanger ~= 0 and sensorEconomy ~= 0 and sensorPopulation ~= 0 then
		infobox:renderSection( {
			title = t( 'lbl_sensors' ),
			content = {
				infobox:renderItem( {
					label = t( 'lbl_sensor_danger' ),
					data = inlineIf( sensorDanger, tostring( sensorDanger ) .. '/10', nil ) 
				} ),
				infobox:renderItem( {
					label = t( 'lbl_sensor_economy' ),
					data = inlineIf( sensorEconomy, tostring( sensorEconomy ) .. '/10', nil ) 
				} ),
				infobox:renderItem( {
					label = t( 'lbl_sensor_population' ),
					data = inlineIf( sensorPopulation, tostring( sensorPopulation ) .. '/10', nil ) 
				} )
			},
			col = 3
		} )
	end

	infobox:renderSection( {
		title = t( 'lbl_history' ),
		content = {
			infobox:renderItem( {
				label = t( 'lbl_discovered_in' ),
				data = discoveredIn,
			} ),
			infobox:renderItem( {
				label = t( 'lbl_discovered_by' ),
				data = discoveredBy,
			} ),
			infobox:renderItem( {
				label = inlineIf( #split( historicalNames or '', ',' ) == 1, t( 'lbl_historical_name' ), t( 'lbl_historical_names' ) ),
				data = historicalNames,
			} )
		},
		col = 2
	} )

	infobox:renderFooter( {
		content = {
			infobox:renderItem( {
				label = t( 'lbl_starmap_id' ),
				data = inlineIf( system[ 'id' ], tostring( system[ 'id' ] ), nil ),
				row = true,
				spacebetween = true
			} ),
			infobox:renderItem( {
				label = t( 'lbl_starmap_code' ),
				data = code,
				row = true,
				spacebetween = true
			} ),
		},
		button = {
			icon = 'WikimediaUI-Globe.svg',
			label = t( 'lbl_other_sites' ),
			type = 'popup',
			content = infobox:renderSection( {
				content = {
					infobox:renderItem( {
						label = t( 'lbl_official_sites' ),
						data = infobox:renderLinkButton( {
							label = t( 'lbl_starmap' ),
							link = starmapLink
						} )
					} ),
				},
				class = 'infobox__section--linkButtons',
			}, true )
		}
	} )

	mw.smw.set( {
		[ t( 'lbl_starmap_id' ) ] = inlineIf( system[ 'id' ], tostring( system[ 'id' ] ), nil ),
		[ t( 'lbl_starmap_code' ) ] = code,
		[ t( 'lbl_system_type' ) ] = translatedType,
		[ t( 'lbl_system_size' ) ] = size,
		[ t( 'lbl_system_status' ) ] = translatedStatus,
		[ t( 'lbl_star_type' ) ] = inlineIf( #starTypeArray > 0, starTypeArray, starTypes )
	} )

	frame:callParserFunction( 'SHORTDESC', string.format( 
		inlineIf( tonumber( planets ) == 1, t( 'shortdesc_singular' ), t( 'shortdesc_plural' ) ), 
		string.gsub( string.lower( translatedType ), '^%l', string.upper ),
		planets
	) )

	local categories = { 'Systems' }
	if affiliation then table.insert( categories, affiliation .. ' Systems' ) end

	return tostring( infobox:renderInfobox( nil, name ) ) .. convertCategories( categories )
end

function System.test( name )
	if not name then name = 'Stanton' end
	
	local systemObjects = Starmap.systemObjects( name )
	local planets = filter( systemObjects, 'type', 'PLANET' )
	local stars = filter( systemObjects, 'type', 'STAR' )
end

return System

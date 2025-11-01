require( 'strict' )

local p = {}

local libraryUtil = require( 'libraryUtil' )

--- Universal parameters for ALL entity types
p.PARAMETERS = {
	{
		name = 'uuid',
		sources = { 'local' }
	},
	{
		name = 'name',
		sources = { 'local', 'api', 'page_title' },
		apiField = 'name',
		apiConfig = 'starCitizenWiki'
	},
	{
		name = 'className',
		sources = { 'api' },
		apiField = 'class_name',
		apiConfig = 'starCitizenWiki'
	},
	{
		name = 'manufacturer',
		sources = { 'local', 'api' },
		apiField = 'manufacturer.code',
		apiConfig = 'starCitizenWiki'
	}
}

--- Determines which type module to use (Item, Vehicle, etc.)
--- @param args table Template arguments
--- @param apiData table|nil Initial API data (if UUID provided)
--- @return string Type module name
local function determineTypeModule( args, apiData )
	-- Explicit type hint
	if args.entity_type then
		return args.entity_type
	end

	-- Infer from API data
	if apiData then
		-- Vehicle types
		local vehicleTypes = { 'Ship', 'GroundVehicle', 'Spacecraft' }
		for _, vType in ipairs( vehicleTypes ) do
			if apiData.type == vType then
				return 'Vehicle'
			end
		end

		-- Default to Item for everything else
		return 'Item'
	end

	-- Default when no API data
	return 'Item'
end

--- Utility: Fetches data from an API
--- @param apiConfigKey string The key of the API config
--- @param apiConfigs table Available API configurations
--- @param query string The query parameter (UUID)
--- @return table|nil API response data
function p.fetchApiData( apiConfigKey, apiConfigs, query )
	if not query or query == '' then
		return nil
	end

	local apiConfig = apiConfigs[apiConfigKey]
	if not apiConfig then
		return nil
	end

	local endpoint = string.format( apiConfig.endpoint, query )

	local success, json = pcall( mw.text.jsonDecode, mw.ext.Apiunto.fetch(
		apiConfig.name,
		endpoint,
		apiConfig.params
	) )

	if not success or not json then
		return nil
	end

	local data = json
	if apiConfig.responseDataPath then
		data = json[apiConfig.responseDataPath]
	end

	return data
end

--- Utility: Fetches data from all configured APIs
--- @param apiConfigs table API configurations
--- @param args table Template arguments
--- @return table API data cache
function p.getApiDataForAllApis( apiConfigs, args )
	local apiCache = {}

	if not args.uuid then
		return apiCache
	end

	for apiConfigKey in pairs( apiConfigs ) do
		local data = p.fetchApiData( apiConfigKey, apiConfigs, args.uuid )
		if data then
			apiCache[apiConfigKey] = data
		end
	end

	return apiCache
end

--- Utility: Resolves nested field path using dot notation
--- @param data table The table to search in
--- @param path string Dot-separated path
--- @return any|nil Value at path
function p.getNestedValue( data, path )
	if not data or not path then
		return nil
	end

	local value = data
	for key in path:gmatch( '[^.]+' ) do
		if type( value ) ~= 'table' then
			return nil
		end
		value = value[key]
		if value == nil then
			return nil
		end
	end

	return value
end

--- Resolves manufacturer with code-to-name lookup
--- @param value string Raw value (code or name)
--- @return table Resolved manufacturer data {name, code, display}
local function resolveManufacturer( value )
	if not value then
		return { name = nil, code = nil, display = nil }
	end
	
	local manufacturer = require( 'Module:Manufacturer' ):new()
	local mfu = manufacturer:get( value )
	
	if mfu then
		-- Found a match: we have both name and code
		return {
			name = mfu.name,
			code = mfu.code,
			display = string.format( '[[%s]] (%s)', mfu.name, mfu.code )
		}
	else
		-- No match: store value as name, no code
		return {
			name = value,
			code = nil,
			display = string.format( '[[%s]]', value )
		}
	end
end

--- Utility: Resolves parameter value from sources
--- @param paramDef table Parameter definition
--- @param args table Template arguments
--- @param apiCache table API data cache
--- @param pageName string Current page name
--- @return table Resolved parameter {name, value, source}
function p.resolveParameter( paramDef, args, apiCache, pageName )
	local value = nil
	local source = 'none'

	for _, sourceType in ipairs( paramDef.sources ) do
		if sourceType == 'local' then
			local localValue = args[paramDef.name] or args[paramDef.name:gsub( '^%l', string.upper )]
			if localValue then
				value = localValue
				source = 'local'
				break
			end
		elseif sourceType == 'api' then
			if paramDef.apiField and paramDef.apiConfig then
				local apiData = apiCache[paramDef.apiConfig]
				if apiData then
					local apiValue = p.getNestedValue( apiData, paramDef.apiField )
					if apiValue then
						value = apiValue
						source = string.format( 'API (%s)', paramDef.apiConfig )
						break
					end
				end
			end
		elseif sourceType == 'page_title' then
			if pageName then
				value = pageName
				source = 'page title'
				break
			end
		end
	end

	-- Special handling for manufacturer
	if paramDef.name == 'manufacturer' and value then
		local mfuData = resolveManufacturer( value )
		return {
			name = paramDef.name,
			value = mfuData.name,
			source = source,
			_manufacturerCode = mfuData.code,
			_manufacturerDisplay = mfuData.display
		}
	end

	return {
		name = paramDef.name,
		value = value,
		source = source
	}
end

--- Main entry point
--- @param args table Arguments from frame
--- @return string Wikitext output
function p._main( args )
	libraryUtil.checkType( '_main', 1, args, 'table' )

	-- Phase 1: Initial API fetch to determine type (if UUID provided)
	local initialApiData = nil
	if args.uuid then
		-- Use minimal API config to fetch initial data
		local starCitizenWikiConfig = {
			name = 'StarCitizenWikiAPI',
			endpoint = 'v2/items/%s',
			params = { locale = 'en_EN' },
			responseDataPath = 'data'
		}
		initialApiData = p.fetchApiData( 'starCitizenWiki', { starCitizenWiki = starCitizenWikiConfig }, args.uuid )
	end

	-- Determine which type module to use
	local typeModuleName = determineTypeModule( args, initialApiData )
	local typeModule = require( 'Module:Entity/' .. typeModuleName )

	-- Delegate everything to the type module
	return typeModule.render( args, p )
end

--- Frame entry point
--- @param frame table Invocation frame
--- @return string Wikitext output
function p.main( frame )
	local args = require( 'Module:Arguments' ).getArgs( frame )
	return p._main( args )
end

return p

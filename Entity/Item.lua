require( 'strict' )

local p = {}

--- Item-specific parameters (dimensions, mass, etc.)
p.PARAMETERS = {
	{
		name = 'type',
		sources = { 'api', 'local' },
		apiField = 'type',
		apiConfig = 'starCitizenWiki'
	},
	{
		name = 'length',
		sources = { 'local', 'api' },
		apiField = 'dimension.length',
		apiConfig = 'starCitizenWiki'
	},
	{
		name = 'width',
		sources = { 'local', 'api' },
		apiField = 'dimension.width',
		apiConfig = 'starCitizenWiki'
	},
	{
		name = 'height',
		sources = { 'local', 'api' },
		apiField = 'dimension.height',
		apiConfig = 'starCitizenWiki'
	},
	{
		name = 'volume',
		sources = { 'api' },
		apiField = 'dimension.volume',
		apiConfig = 'starCitizenWiki'
	},
	{
		name = 'mass',
		sources = { 'local', 'api' },
		apiField = 'mass',
		apiConfig = 'starCitizenWiki'
	}
}

--- API configurations for items
p.API_CONFIGS = {
	starCitizenWiki = {
		name = 'StarCitizenWikiAPI',
		endpoint = 'v2/items/%s',
		params = { locale = 'en_EN' },
		responseDataPath = 'data'
	}
}

--- Determines the item subtype from API data
--- @param apiData table API response data
--- @return string|nil Subtype name (e.g., 'WeaponGun', 'QuantumDrive')
function p.getSubtype( apiData )
	if not apiData or not apiData.type then
		return nil
	end

	return apiData.type
end

--- Loads subtype module if it exists
--- @param subtype string Item subtype
--- @return table|nil Subtype module
function p.loadSubtypeModule( subtype )
	if not subtype then
		return nil
	end

	local moduleName = string.format( 'Module:Entity/Item/%s', subtype )
	local success, subtypeModule = pcall( require, moduleName )

	if success and subtypeModule then
		return subtypeModule
	end

	return nil
end

--- Merges parameter definitions
--- @param baseParams table Base parameters
--- @param additionalParams table Additional parameters
--- @return table Merged parameters
local function mergeParameters( baseParams, additionalParams )
	if not additionalParams then
		return baseParams
	end

	local merged = {}
	local nameIndex = {}

	for _, param in ipairs( baseParams ) do
		table.insert( merged, param )
		nameIndex[param.name] = #merged
	end

	for _, param in ipairs( additionalParams ) do
		if nameIndex[param.name] then
			merged[nameIndex[param.name]] = param
		else
			table.insert( merged, param )
			nameIndex[param.name] = #merged
		end
	end

	return merged
end

--- Builds main section with type and volume
--- @param paramValues table Parameter values
--- @return table|nil Main section or nil
local function buildMainSection( paramValues )
	if not paramValues.type and not paramValues.volume then
		return nil
	end

	local items = {}

	if paramValues.type then
		table.insert( items, {
			label = 'Type',
			content = tostring( paramValues.type )
		} )
	end

	if paramValues.volume then
		table.insert( items, {
			label = 'Volume',
			content = tostring( paramValues.volume )
		} )
	end

	return {
		items = items
	}
end

--- Builds dimensions section
--- @param paramValues table Parameter values
--- @return table|nil Dimensions section or nil
local function buildDimensionsSection( paramValues )
	if not (paramValues.length or paramValues.width or paramValues.height or paramValues.mass) then
		return nil
	end

	local dimensions = require( 'Module:Dimensions' )
	local dimensionsOutput = dimensions._main( {
		length = paramValues.length,
		width = paramValues.width,
		height = paramValues.height,
		mass = paramValues.mass
	} )

	if dimensionsOutput then
		return {
			label = 'Dimensions',
			collapsible = true,
			collapsed = true,
			content = dimensionsOutput
		}
	else
		local items = {}
		if paramValues.length then
			table.insert( items, { label = 'Length', content = tostring( paramValues.length ) } )
		end
		if paramValues.width then
			table.insert( items, { label = 'Width', content = tostring( paramValues.width ) } )
		end
		if paramValues.height then
			table.insert( items, { label = 'Height', content = tostring( paramValues.height ) } )
		end
		if paramValues.mass then
			table.insert( items, { label = 'Mass', content = tostring( paramValues.mass ) } )
		end

		if #items > 0 then
			return {
				label = 'Dimensions',
				collapsible = true,
				collapsed = true,
				items = items,
				columns = 3
			}
		end
	end

	return nil
end

--- Builds development section
--- @param paramValues table Parameter values
--- @return table|nil Development section
local function buildDevelopmentSection( paramValues )
	local items = {}

	if paramValues.className then
		table.insert( items, { label = 'Class name', content = paramValues.className } )
	end
	if paramValues.uuid then
		table.insert( items, { label = 'UUID', content = paramValues.uuid } )
	end

	if #items > 0 then
		return {
			label = 'Development',
			collapsible = true,
			collapsed = true,
			items = items
		}
	end

	return nil
end

--- Builds heat items from API data
--- @param heatData table Heat data from API
--- @return table|nil Array of items or nil
local function buildHeatItems( heatData )
	if not heatData then
		return nil
	end

	local items = {}

	if heatData.max_temperature then
		table.insert( items, {
			label = 'Max Temperature',
			content = string.format( '%d K', heatData.max_temperature )
		} )
	end

	if heatData.overheat_temperature then
		table.insert( items, {
			label = 'Overheat Temperature',
			content = string.format( '%d K', heatData.overheat_temperature )
		} )
	end

	if heatData.max_cooling_rate then
		table.insert( items, {
			label = 'Cooling Rate',
			content = string.format( '%.2f K/s', heatData.max_cooling_rate )
		} )
	end

	return items
end

--- Builds power items from API data
--- @param powerData table Power data from API
--- @return table|nil Array of items or nil
local function buildPowerItems( powerData )
	if not powerData then
		return nil
	end

	local items = {}

	if powerData.power_draw then
		table.insert( items, {
			label = 'Power Draw',
			content = string.format( '%.1f pwr/s', powerData.power_draw )
		} )
	end

	if powerData.em_max then
		table.insert( items, {
			label = 'EM Signature',
			content = string.format( '%.1f', powerData.em_max )
		} )
	end

	return items
end

--- Builds distortion items from API data
--- @param distortionData table Distortion data from API
--- @return table|nil Array of items or nil
local function buildDistortionItems( distortionData )
	if not distortionData then
		return nil
	end

	local items = {}

	if distortionData.maximum then
		table.insert( items, {
			label = 'Maximum',
			content = string.format( '%.0f', distortionData.maximum )
		} )
	end

	if distortionData.decay_rate then
		table.insert( items, {
			label = 'Decay Rate',
			content = string.format( '%.0f/s', distortionData.decay_rate )
		} )
	end

	return items
end

--- Builds durability items from API data
--- @param durabilityData table Durability data from API
--- @return table|nil Array of items or nil
local function buildDurabilityItems( durabilityData )
	if not durabilityData then
		return nil
	end

	local items = {}

	if durabilityData.health then
		table.insert( items, {
			label = 'Health',
			content = string.format( '%.0f', durabilityData.health )
		} )
	end

	if durabilityData.max_lifetime then
		table.insert( items, {
			label = 'Max Lifetime',
			content = string.format( '%.0f s', durabilityData.max_lifetime )
		} )
	end

	if durabilityData.repairable ~= nil then
		table.insert( items, {
			label = 'Repairable',
			content = durabilityData.repairable and 'Yes' or 'No'
		} )
	end

	if durabilityData.salvageable ~= nil then
		table.insert( items, {
			label = 'Salvageable',
			content = durabilityData.salvageable and 'Yes' or 'No'
		} )
	end

	return items
end

--- Builds engineering section with heat/power/distortion/durability (data-driven)
--- @param apiData table API response data
--- @return table|nil Engineering section or nil
local function buildEngineeringSection( apiData )
	if not apiData then
		return nil
	end

	local subsections = {}

	-- Add heat subsection if data exists
	if apiData.heat then
		local heatItems = buildHeatItems( apiData.heat )
		if heatItems and #heatItems > 0 then
			table.insert( subsections, {
				label = 'Heat',
				columns = 2,
				items = heatItems
			} )
		end
	end

	-- Add power subsection if data exists
	if apiData.power then
		local powerItems = buildPowerItems( apiData.power )
		if powerItems and #powerItems > 0 then
			table.insert( subsections, {
				label = 'Power',
				columns = 2,
				items = powerItems
			} )
		end
	end

	-- Add distortion subsection if data exists
	if apiData.distortion then
		local distortionItems = buildDistortionItems( apiData.distortion )
		if distortionItems and #distortionItems > 0 then
			table.insert( subsections, {
				label = 'Distortion',
				columns = 2,
				items = distortionItems
			} )
		end
	end

	-- Add durability subsection if data exists
	if apiData.durability then
		local durabilityItems = buildDurabilityItems( apiData.durability )
		if durabilityItems and #durabilityItems > 0 then
			table.insert( subsections, {
				label = 'Durability',
				columns = 2,
				items = durabilityItems
			} )
		end
	end

	if #subsections == 0 then
		return nil
	end

	return {
		label = 'Engineering',
		collapsible = true,
		collapsed = true,
		sections = subsections
	}
end

--- Main rendering function (self-contained orchestration)
--- @param args table Template arguments
--- @param entityModule table Reference to Entity module for utilities
--- @return string HTML output
function p.render( args, entityModule )
	-- Merge all API configs (base + subtype if needed later)
	local allApiConfigs = {}
	for key, config in pairs( p.API_CONFIGS ) do
		allApiConfigs[key] = config
	end

	-- Fetch APIs
	local apiCache = entityModule.getApiDataForAllApis( allApiConfigs, args )

	-- Determine subtype
	local apiData = apiCache.starCitizenWiki
	local subtype = p.getSubtype( apiData )
	local subtypeModule = p.loadSubtypeModule( subtype )

	-- Phase 2: If subtype has additional APIs, merge and fetch
	if subtypeModule and subtypeModule.API_CONFIGS then
		for key, config in pairs( subtypeModule.API_CONFIGS ) do
			if not allApiConfigs[key] then
				allApiConfigs[key] = config
			end
		end

		local additionalApiData = entityModule.getApiDataForAllApis( allApiConfigs, args )
		for key, data in pairs( additionalApiData ) do
			if not apiCache[key] then
				apiCache[key] = data
			end
		end
	end

	-- Merge parameters (entity base + item + subtype)
	local allParams = mergeParameters( entityModule.PARAMETERS, p.PARAMETERS )
	if subtypeModule and subtypeModule.PARAMETERS then
		allParams = mergeParameters( allParams, subtypeModule.PARAMETERS )
	end

	-- Resolve parameters
	local pageName = mw.title.getCurrentTitle().text
	local parameters = {}
	for _, paramDef in ipairs( allParams ) do
		table.insert( parameters, entityModule.resolveParameter( paramDef, args, apiCache, pageName ) )
	end

	-- Extract parameter values
	local paramValues = {}
	for _, param in ipairs( parameters ) do
		paramValues[param.name] = param.value
	end

	-- Extract manufacturer display format
	local manufacturerDisplay = nil
	for _, param in ipairs( parameters ) do
		if param.name == 'manufacturer' and param._manufacturerDisplay then
			manufacturerDisplay = param._manufacturerDisplay
			break
		end
	end

	-- Build context
	local context = {
		args = args,
		apiCache = apiCache,
		pageName = pageName
	}

	-- Build sections in order
	local sections = {}

	-- 1. Main section (volume)
	local mainSection = buildMainSection( paramValues )
	if mainSection then
		table.insert( sections, mainSection )
	end

	-- 2. Subtype-specific sections (e.g., Key stats)
	if subtypeModule and subtypeModule.getAdditionalSections then
		local additionalSections = subtypeModule.getAdditionalSections( paramValues, context )
		if additionalSections then
			for _, section in ipairs( additionalSections ) do
				table.insert( sections, section )
			end
		end
	end

	-- 3. Engineering section (data-driven, automatic)
	local engineeringSection = buildEngineeringSection( apiData )
	if engineeringSection then
		table.insert( sections, engineeringSection )
	end

	-- 4. Dimensions section
	local dimensionsSection = buildDimensionsSection( paramValues )
	if dimensionsSection then
		table.insert( sections, dimensionsSection )
	end

	-- 5. Development section
	local developmentSection = buildDevelopmentSection( paramValues )
	if developmentSection then
		table.insert( sections, developmentSection )
	end

	-- Render infobox
	local infoboxLua = require( 'Module:InfoboxLua' )
	return infoboxLua.render( {
		title = paramValues.name or 'Entity',
		subtitle = manufacturerDisplay,
		sections = sections
	} )
end

return p

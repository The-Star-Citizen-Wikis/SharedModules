require( 'strict' )

local p = {}

--- Builds power plant section
--- @param powerPlantData table Power plant data from API
--- @return table|nil Power plant section or nil
local function buildPowerPlantSection( powerPlantData )
	if not powerPlantData then
		return nil
	end

	local items = {}

	if powerPlantData.power_output then
		table.insert( items, {
			label = 'Power Output',
			content = string.format( '%.1f pwr/s', powerPlantData.power_output )
		} )
	end

	if #items > 0 then
		return {
			label = 'Key stats',
			collapsible = true,
			columns = 2,
			items = items
		}
	end

	return nil
end

--- Returns power plant sections
--- @param paramValues table Parameter values (unused)
--- @param context table Resolution context
--- @return table Array of sections
function p.getAdditionalSections( paramValues, context )
	local sections = {}
	local apiData = context.apiCache.starCitizenWiki

	if not apiData then
		return sections
	end

	-- Add power plant-specific section
	local powerPlantSection = buildPowerPlantSection( apiData.power_plant )
	if powerPlantSection then
		table.insert( sections, powerPlantSection )
	end

	return sections
end

return p

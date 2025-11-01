require( 'strict' )

local p = {}

--- Builds food section
--- @param foodData table Food data from API
--- @return table|nil Food section or nil
local function buildFoodSection( foodData )
	if not foodData then
		return nil
	end

	local items = {}

	if foodData.nutritional_density_rating then
		table.insert( items, {
			label = 'NDR',
			content = tostring( foodData.nutritional_density_rating )
		} )
	end

	if foodData.effects and #foodData.effects > 0 then
		local linkedEffects = {}
		for _, effect in ipairs( foodData.effects ) do
			table.insert( linkedEffects, string.format( '[[%s]]', effect ) )
		end
		table.insert( items, {
			label = 'Effects',
			content = table.concat( linkedEffects, ', ' )
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

--- Returns food-specific sections
--- @param paramValues table Parameter values (unused)
--- @param context table Resolution context
--- @return table Array of sections
function p.getAdditionalSections( paramValues, context )
	local sections = {}
	local apiData = context.apiCache.starCitizenWiki

	if not apiData then
		return sections
	end

	local foodSection = buildFoodSection( apiData.food )
	if foodSection then
		table.insert( sections, foodSection )
	end

	return sections
end

return p

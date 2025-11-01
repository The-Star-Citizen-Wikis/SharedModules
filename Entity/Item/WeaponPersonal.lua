require( 'strict' )

local p = {}

--- No component dependencies - personal weapons don't have vehicle component data
-- p.includes = nil

--- Builds personal weapon section
--- @param weaponData table Personal weapon data from API
--- @return table|nil Weapon section or nil
local function buildPersonalWeaponSection( weaponData )
	if not weaponData then
		return nil
	end

	local items = {}

	-- Add personal weapon-specific fields
	-- Note: Structure may vary based on actual personal_weapon API structure
	if weaponData.damage_per_shot then
		table.insert( items, {
			label = 'Damage per Shot',
			content = string.format( '%.2f', weaponData.damage_per_shot )
		} )
	end

	if weaponData.fire_rate then
		table.insert( items, {
			label = 'Fire Rate',
			content = string.format( '%d RPM', weaponData.fire_rate )
		} )
	end

	if weaponData.magazine_size then
		table.insert( items, {
			label = 'Magazine Size',
			content = tostring( weaponData.magazine_size )
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

--- Returns personal weapon sections
--- @param paramValues table Parameter values (unused)
--- @param context table Resolution context
--- @return table Array of sections
function p.getAdditionalSections( paramValues, context )
	local sections = {}
	local apiData = context.apiCache.starCitizenWiki

	if not apiData then
		return sections
	end

	-- Add personal weapon section
	local weaponSection = buildPersonalWeaponSection( apiData.personal_weapon )
	if weaponSection then
		table.insert( sections, weaponSection )
	end

	return sections
end

return p

require( 'strict' )

local p = {}

--- Builds weapon stats section
--- @param weaponData table Weapon data from API
--- @return table|nil Weapon section or nil
local function buildWeaponSection( weaponData )
	if not weaponData then
		return nil
	end

	local items = {}

	if weaponData.damage_per_shot then
		table.insert( items, {
			label = 'Damage per Shot',
			content = string.format( '%.2f', weaponData.damage_per_shot )
		} )
	end

	if weaponData.modes and weaponData.modes[1] then
		local mode = weaponData.modes[1]
		if mode.damage_per_second then
			table.insert( items, {
				label = 'DPS',
				content = string.format( '%.2f', mode.damage_per_second )
			} )
		end
		if mode.rpm then
			table.insert( items, {
				label = 'Fire Rate',
				content = string.format( '%d RPM', mode.rpm )
			} )
		end
	end

	if weaponData.range then
		table.insert( items, {
			label = 'Range',
			content = string.format( '%d m', weaponData.range )
		} )
	end

	if weaponData.capacity then
		table.insert( items, {
			label = 'Capacity',
			content = tostring( weaponData.capacity )
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

--- Returns weapon-specific sections
--- Implements standard subtype interface
--- @param paramValues table Parameter values keyed by name (unused)
--- @param context table Resolution context
--- @return table Array of sections
function p.getAdditionalSections( paramValues, context )
	local sections = {}
	local apiData = context.apiCache.starCitizenWiki

	if not apiData then
		return sections
	end

	-- Add weapon-specific section
	local weaponSection = buildWeaponSection( apiData.vehicle_weapon )
	if weaponSection then
		table.insert( sections, weaponSection )
	end

	return sections
end

return p

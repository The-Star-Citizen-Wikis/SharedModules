require( 'strict' )

local p = {}

--- Builds quantum drive section
--- @param quantumData table Quantum drive data from API
--- @return table|nil Quantum section or nil
local function buildQuantumSection( quantumData )
	if not quantumData then
		return nil
	end

	local items = {}

	if quantumData.quantum_fuel_requirement then
		table.insert( items, {
			label = 'Fuel Requirement',
			content = string.format( '%.5f QF/Gm', quantumData.quantum_fuel_requirement )
		} )
	end

	if quantumData.standard_jump then
		if quantumData.standard_jump.speed then
			table.insert( items, {
				label = 'Quantum Speed',
				content = string.format( '%.0f m/s', quantumData.standard_jump.speed )
			} )
		end

		if quantumData.standard_jump.cooldown then
			table.insert( items, {
				label = 'Cooldown',
				content = string.format( '%.1f s', quantumData.standard_jump.cooldown )
			} )
		end

		if quantumData.standard_jump.stage_one_accel_rate then
			table.insert( items, {
				label = 'Acceleration',
				content = string.format( '%.1f m/s²', quantumData.standard_jump.stage_one_accel_rate )
			} )
		end
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

--- Returns quantum drive sections
--- @param paramValues table Parameter values (unused)
--- @param context table Resolution context
--- @return table Array of sections
function p.getAdditionalSections( paramValues, context )
	local sections = {}
	local apiData = context.apiCache.starCitizenWiki

	if not apiData then
		return sections
	end

	-- Add quantum-specific section
	local quantumSection = buildQuantumSection( apiData.quantum_drive )
	if quantumSection then
		table.insert( sections, quantumSection )
	end

	return sections
end

return p

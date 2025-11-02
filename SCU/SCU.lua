require( 'strict' )

local p = {}

local libraryUtil = require( 'libraryUtil' )
local yn = require( 'Module:Yesno' )
local mArguments -- lazily initialise Module:Arguments

--- Constant for SCU to µSCU conversion
local MICRO_SCU_PER_SCU = 1000000

--- Parses input value to extract numeric value and unit
---
--- @param input string|number Input value (e.g., "1", "2 SCU", "252,000 µSCU")
--- @return table|nil Parsed result as {value=number, unit=string} or nil on error
local function parseInput( input )
	if not input then
		return nil
	end

	-- If already a number, assume SCU
	if type( input ) == 'number' then
		return { value = input, unit = 'SCU' }
	end

	-- Convert to string and trim
	local str = tostring( input )
	str = mw.text.trim( str )

	if str == '' then
		return nil
	end

	-- Remove thousand separators (commas, spaces, etc.)
	str = str:gsub( '[,%s]', '' )

	-- Try to match number with optional unit
	-- Pattern: optional minus, digits, optional decimal point and digits, optional whitespace, optional unit
	local numStr, unit = str:match( '^([%-]?%d+%.?%d*)%s*(.*)$' )

	if not numStr then
		return nil
	end

	local value = tonumber( numStr )
	if not value then
		return nil
	end

	-- Normalize unit (default to SCU if not specified)
	if unit == '' or unit == 'SCU' then
		unit = 'SCU'
	elseif unit == 'µSCU' or unit == 'uSCU' then
		unit = 'µSCU'
	else
		-- Unknown unit
		return nil
	end

	return { value = value, unit = unit }
end

--- Converts value to SCU
---
--- @param value number Numeric value
--- @param unit string Unit of the value ('SCU' or 'µSCU')
--- @return number Value in SCU
local function toSCU( value, unit )
	if unit == 'µSCU' then
		return value / MICRO_SCU_PER_SCU
	end
	-- Already in SCU or nil unit (default SCU)
	return value
end

--- Converts value to µSCU
---
--- @param value number Numeric value
--- @param unit string Unit of the value ('SCU' or 'µSCU')
--- @return number Value in µSCU
local function toMicroSCU( value, unit )
	if unit == 'SCU' or not unit then
		return value * MICRO_SCU_PER_SCU
	end
	-- Already in µSCU
	return value
end

--- Formats a number with optional precision and separators
---
--- @param value number The number to format
--- @param precision number|nil Optional decimal places to round to
--- @param useSeparators boolean Whether to use thousand separators
--- @return string Formatted number string
local function formatNumber( value, precision, useSeparators )
	-- Apply precision if specified
	if precision then
		local multiplier = 10 ^ precision
		value = math.floor( value * multiplier + 0.5 ) / multiplier
	end

	-- Format with separators if requested
	if useSeparators then
		local lang = mw.language.getContentLanguage()
		return lang:formatNum( value )
	else
		return tostring( value )
	end
end

--- Converts input value to target unit with formatting options
---
--- @param input string|number Input value to convert
--- @param targetUnit string Target unit ('SCU' or 'µSCU')
--- @param options table|nil Optional table with:
---   - includeUnit (boolean, default true): Include unit in output
---   - precision (number, optional): Decimal places to round to
---   - useSeparators (boolean, default true): Use thousand separators
--- @return string|nil Formatted output string or nil on error
function p.convert( input, targetUnit, options )
	-- Parse input
	local parsed = parseInput( input )
	if not parsed then
		return nil
	end

	-- Set default options
	options = options or {}
	local includeUnit = options.includeUnit
	if includeUnit == nil then
		includeUnit = true
	end
	local useSeparators = options.useSeparators
	if useSeparators == nil then
		useSeparators = true
	end
	local precision = options.precision

	-- Normalize target unit
	targetUnit = targetUnit or 'SCU'
	if targetUnit ~= 'SCU' and targetUnit ~= 'µSCU' and targetUnit ~= 'uSCU' then
		return nil
	end
	if targetUnit == 'uSCU' then
		targetUnit = 'µSCU'
	end

	-- Convert to target unit
	local outputValue
	if targetUnit == 'SCU' then
		outputValue = toSCU( parsed.value, parsed.unit )
	else
		outputValue = toMicroSCU( parsed.value, parsed.unit )
	end

	-- Format the number
	local formattedNumber = formatNumber( outputValue, precision, useSeparators )

	-- Add unit if requested
	if includeUnit then
		return formattedNumber .. ' ' .. targetUnit
	else
		return formattedNumber
	end
end

--- Core conversion function for direct Lua module use
---
--- @param input string|number Input value to convert
--- @param targetUnit string|nil Target unit ('SCU' or 'µSCU'), defaults to 'SCU'
--- @param options table|nil Optional table with precision, includeUnit, useSeparators
--- @return string|nil Converted and formatted value or error message
function p._main( input, targetUnit, options )
	if not input then
		return '<span class="error">Error: No input value provided</span>'
	end

	targetUnit = targetUnit or 'SCU'
	options = options or {}

	local result = p.convert( input, targetUnit, options )

	if not result then
		return '<span class="error">Error: Invalid input format</span>'
	end

	return result
end

--- Wikitext entry point for SCU conversion
---
--- @param frame table Frame object from MediaWiki
--- @return string|nil Converted and formatted value or error message
function p.main( frame )
	mArguments = require( 'Module:Arguments' )
	local args = mArguments.getArgs( frame )

	local input = args[1]
	local targetUnit = args[2] or 'SCU'

	-- Parse optional named parameters
	local options = {}

	if args.precision then
		options.precision = tonumber( args.precision )
	end

	if args.includeUnit ~= nil then
		options.includeUnit = yn( args.includeUnit )
	end

	if args.useSeparators ~= nil then
		options.useSeparators = yn( args.useSeparators )
	end

	return p._main( input, targetUnit, options )
end

return p


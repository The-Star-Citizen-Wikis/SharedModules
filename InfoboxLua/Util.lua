require( 'strict' )

local libraryUtil = require( 'libraryUtil' )
local checkType = libraryUtil.checkType
local checkTypeForNamedArg = libraryUtil.checkTypeForNamedArg

local p = {}


--- Checks if a value is a string and is not empty.
---
--- @param value any The value to check.
--- @return boolean True if the value is a non-empty string, false otherwise.
function p.isNonEmptyString( value )
	return type( value ) == 'string' and value ~= ''
end

--- Validates input data against a provided schema and constructs a new object.
--- Returns nil if validation fails.
---
--- @param rawData table
--- @param schema DataSchemaDefinition
--- @return table|nil
function p.validateAndConstruct( rawData, schema )
	checkType( 'Util.validateAndConstruct', 1, rawData, 'table' )
	checkType( 'Util.validateAndConstruct', 2, schema, 'table' )

	local newObject = {}

	for key, schemaDef in pairs( schema ) do
		checkType( 'Util.validateAndConstruct (schema validation for key: ' .. tostring( key ) .. ')', 1, schemaDef,
			'table' )
		checkTypeForNamedArg( 'Util.validateAndConstruct (schema validation for key: ' .. tostring( key ) .. ')', 'type',
			schemaDef.type, 'string' )
		if schemaDef.required ~= nil then
			checkTypeForNamedArg( 'Util.validateAndConstruct (schema validation for key: ' .. tostring( key ) .. ')',
				'required', schemaDef.required, 'boolean', true )
		end

		local value = rawData[key]

		if schemaDef.required and value == nil then
			error( 'Input data missing required key: ' .. tostring( key ) )
		end

		if value ~= nil then
			checkTypeForNamedArg( 'Util.validateAndConstruct', tostring( key ), value, schemaDef.type, false )
			newObject[key] = value
		elseif schemaDef.default ~= nil then
			newObject[key] = schemaDef.default
		else
			if schemaDef.required == false then
				newObject[key] = nil
			end
		end
	end

	for key, _ in pairs( rawData ) do
		if not schema[key] then
			error( 'Input data contains extraneous key not defined in schema: ' .. tostring( key ) )
		end
	end

	return newObject
end

return p

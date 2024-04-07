local commonSMW = {}

local common = require( 'Module:Common' )
local libraryUtil = require( 'libraryUtil' )
local checkType = libraryUtil.checkType
local checkTypeMulti = libraryUtil.checkTypeMulti

--- Formats a value to be used by smw.set
---
--- @param datum table An entry from data.json
--- @param val any The value to be formatted
--- @param moduleConfig table Optional, only used for multilingual text (phasing out)
--- @param lang table Content language, uses page language if not set
--- @return any The formatted value
function commonSMW.format( datum, val, moduleConfig, lang )
    datum = datum or {}
    moduleConfig = moduleConfig or { smw_multilingual_text = false }

    -- Format number for SMW
    if datum.type == 'number' then
        val = common.formatNum( val )
        -- Multilingual Text, add a suffix
    elseif datum.type == 'multilingual_text' and moduleConfig.smw_multilingual_text == true then
        -- FIXME: This is a temp fix to handle tables in val (d280346 in API), need some clean up
        if type( val ) == 'table' then
            local tmp = {}
            for _, valText in ipairs( val ) do
                valText = mw.ustring.format( '%s@%s', valText, moduleConfig.module_lang or mw.getContentLanguage():getCode() )
                table.insert( tmp, valText )
            end
            val = tmp
        else
            val = mw.ustring.format( '%s@%s', val, moduleConfig.module_lang or mw.getContentLanguage():getCode() )
        end
        -- String format
    elseif type( datum.format ) == 'string' then
        if mw.ustring.find( datum.format, '%', 1, true  ) then
            val = mw.ustring.format( datum.format, val )
        elseif datum.format == 'ucfirst' then
            lang = lang or mw.getContentLanguage()
            val = lang:ucfirst( val )
        elseif datum.format == 'replace-dash' then
            val = mw.ustring.gsub( val, '%-', ' ' )
            -- Remove part of the value
        elseif datum.format:sub( 1, 6 ) == 'remove' then
            val = tostring( val ):gsub( mw.text.split( datum.format, ':', true )[ 2 ], '' )
        end
        -- Min/Max
    elseif datum.type == 'minmax' then
        val = {
            common.formatNum( val.min ),
            common.formatNum( val.max ),
        }
        -- 'Special' boolean case to explicitly set false
    elseif datum.type == 'boolean' then
        if val == true then
            val = 1
        else
            val = 0
        end
    end

    return val
end

--- Adds SMW properties to a table either from the API or Frame arguments
---
--- @param apiData table Data from the Wiki API
--- @param frameArgs table Frame args processed by Module:Arguments
--- @param smwSetObject table The SMW Object that gets passed to mw.smw.set
--- @param translateFn function The function used to translate argument names
--- @param moduleConfig table Table from config.json
--- @param moduleData table Table from data.json
--- @param moduleName string The module name used to retrieve fallback attribute names
--- @return nil
function commonSMW.addSmwProperties( apiData, frameArgs, smwSetObject, translateFn, moduleConfig, moduleData, moduleName )
	checkTypeMulti( 'Module:Common/SMW.addSmwProperties', 1, apiData, { 'table', 'nil' } )
    checkType( 'Module:Common/SMW.addSmwProperties', 2, frameArgs, 'table' )
    checkType( 'Module:Common/SMW.addSmwProperties', 3, smwSetObject, 'table' )
    checkType( 'Module:Common/SMW.addSmwProperties', 4, translateFn, 'function' )
    checkType( 'Module:Common/SMW.addSmwProperties', 5, moduleConfig, 'table' )
    checkType( 'Module:Common/SMW.addSmwProperties', 6, moduleData, 'table' )
    checkType( 'Module:Common/SMW.addSmwProperties', 7, moduleName, 'string' )

    local TNT = require( 'Module:Translate' ):new()
    local lang
    if moduleConfig.module_lang then
        lang = mw.getLanguage( moduleConfig.module_lang )
    else
        lang = mw.getContentLanguage()
    end

	--- Retrieve value(s) from the frame
	---
	--- @param datum table An entry from data.smw_data
	--- @param argKey string The key to use as an accessor to frameArgs
	--- @return string|number|table|nil
	local function getFromArgs( datum, argKey )
		local value
		-- Numbered parameters, e.g. URL1, URL2, URL3, etc.
		if datum.type == 'range' and type( datum.max ) == 'number' then
			value = {}

			for i = 1, datum.max do
				local argValue = frameArgs[ argKey .. i ]
				if argValue then table.insert( value, argValue ) end
			end
		-- A "simple" arg
		else
			value = frameArgs[ argKey ]
		end

		return value
	end

	-- Iterate through the list of SMW attributes that shall be filled
	for _, datum in ipairs( moduleData.smw_data ) do
		-- Retrieve the SMW key and from where the data should be pulled
		local smwKey, from
		for key, get_from in pairs( datum ) do
			if mw.ustring.sub( key, 1, 3 ) == 'SMW' then
				smwKey = key
				from = get_from or {}
			end
		end

		if type( from ) ~= 'table' then
			from = { from }
		end

		-- Iterate the list of data sources in order, later sources override previous ones
		-- I.e. if the list is Frame Args, API; The api will override possible values set from the frame
		for _, key in ipairs( from ) do
			local parts = mw.text.split( key, '_', true )
			local value

			-- Re-assemble keys with multiple '_'
			if #parts > 2 then
				local tmp = parts[ 1 ]
				table.remove( parts, 1 )
				parts = {
					tmp,
					table.concat( parts, '_' )
				}
			end

			mw.logObject( parts, 'Key Parts' )

			-- safeguard check if we have two parts
			if #parts == 2 then
				-- Retrieve data from frameArgs
				if parts[ 1 ] == 'ARG' then
					value = getFromArgs( datum, translateFn( key ) or '<UNSET>' )

					-- Use EN lang as fallback for arg names that are empty
					if value == nil then
						local success, translation = pcall(
							TNT.formatInLanguage,
							'en',
							string.format( 'Module:%s/i18n.json', moduleName ),
							key
                        )
						if success then
							value = getFromArgs( datum, translation )
						end
					end
				-- Retrieve data from API
				elseif parts[ 1 ] == 'API' and apiData ~= nil then
					mw.logObject({
						key_access = parts[2],
						value = apiData:get( parts[ 2 ] )
					})

					value = apiData:get( parts[ 2 ] )
				end
			end

			-- Transform value based on 'format' key
			if value ~= nil then
				if type( value ) ~= 'table' then
					value = { value }
				end

                if datum.type == 'table' then
                    local api = require( 'Module:Common/Api' )
                    local output = {}

                    for _, data in ipairs( value ) do
                        if type( datum.data_key ) == 'string' then
                            table.insert( output, commonSMW.format( datum, api.makeAccessSafe( data ):get( datum.data_key ), moduleConfig, lang ) )
                        elseif type( data ) ~= 'table' then -- Format each value if its a normal array
                            table.insert( output, commonSMW.format( datum, data, moduleConfig, lang ) )
                        end
                    end

                    value = output
                elseif datum.type == 'subobject' then
                    local api = require( 'Module:Common/Api' )

                    for _, data in ipairs( value ) do
                        local subobject = {}
                        data = api.makeAccessSafe( data )
                        commonSMW.addSmwProperties( data, {}, subobject, translateFn, moduleConfig, datum, moduleName )

                        mw.smw.subobject( subobject )
                    end
                else
                    for index, val in ipairs( value ) do
                        local newValue = mw.clone( val )

                        if type( newValue ) == 'table' and datum.type ~= 'table' and datum.type ~= 'minmax' and datum.type ~= 'subobject' and datum.type ~= 'multilingual_text' then
                            newValue = mw.ustring.format( '!ERROR! Key %s is a table value; please fix', key )
                        else
                            newValue = commonSMW.format( datum, newValue, moduleConfig, lang )
                        end

                        table.remove( value, index )
                        table.insert( value, index, newValue )
                    end
                end

				if datum.type ~= 'subobject' and type( smwKey ) == 'string' then
					if type( value ) == 'table' and #value == 1 then
						value = value[ 1 ]
					end

					-- i18n should be present for SMW property name, but sometimes it doesn't
					local smwPropName = translateFn( smwKey ) or smwKey
					smwSetObject[ smwPropName ] = value
				end
			end
		end
	end
end


--- Adds SMW ask properties to the ask object, based on the keys defined in data.json (moduleData)
---
--- @param smwAskObject table The table that gets passed to mw.smw.ask
--- @param translateFn function The translate function used to translate argument names
--- @param moduleConfig table The module config from config.json
--- @param moduleData table The module data from data.json
--- @return nil
function commonSMW.addSmwAskProperties( smwAskObject, translateFn, moduleConfig, moduleData )
	checkType( 'Module:Common/SMW.addSmwAskProperties', 1, smwAskObject, 'table' )
	checkType( 'Module:Common/SMW.addSmwAskProperties', 2, translateFn, 'function' )
	checkType( 'Module:Common/SMW.addSmwAskProperties', 3, moduleConfig, 'table' )
	checkType( 'Module:Common/SMW.addSmwAskProperties', 4, moduleData, 'table' )

	local langSuffix = ''
	if moduleConfig.smw_multilingual_text == true then
		langSuffix = '+lang=' .. ( moduleConfig.module_lang or mw.getContentLanguage():getCode() )
	end

	for _, queryPart in ipairs( moduleData.smw_data ) do
		local smwKey
		for key, _ in pairs( queryPart ) do
			if mw.ustring.sub( key, 1, 3 ) == 'SMW' then
				smwKey = key
				break
			end
		end

		local formatString = '?%s'

		if queryPart.smw_format then
			formatString = formatString .. queryPart.smw_format
		end

		-- safeguard
		if smwKey ~= nil and translateFn( smwKey ) ~= nil then
			table.insert( smwAskObject, mw.ustring.format( formatString, translateFn( smwKey ) ) )

			if queryPart.type == 'multilingual_text' then
				table.insert( smwAskObject, langSuffix )
			end
		end
	end
end


--- Retrieve subobjects
---
--- @param pageName string
--- @param identifierPropKey string SMW property key used to identify subobjects
--- @param propKeys table table of SMW property keys
--- @param translateFn function The translate function used to translate argument names
--- @return table
function commonSMW.loadSubobjects( pageName, identifierPropKey, propKeys, translateFn )
	checkType( 'Module:Common/SMW.loadSubobjects', 1, pageName, 'string' )
	checkType( 'Module:Common/SMW.loadSubobjects', 2, identifierPropKey, 'string' )
	checkType( 'Module:Common/SMW.loadSubobjects', 3, propKeys, 'table' )
	checkType( 'Module:Common/SMW.loadSubobjects', 4, translateFn, 'function' )

    local askQuery = {
        '[[-Has subobject::' .. pageName .. ']]',
        '[[' .. translateFn( identifierPropKey ) .. '::+]]'
    }

    for _, propKey in ipairs( propKeys ) do
        table.insert( askQuery, mw.ustring.format( '?%s', translateFn( propKey ) ) )
    end

    table.insert( askQuery, 'mainlabel=-' )

    local subobjects = mw.smw.ask( askQuery )

    if subobjects == nil then return {} end

    local subobjectTable = {}

    for _, subobject in ipairs( subobjects ) do
        if subobject[ translateFn( identifierPropKey ) ] then
            table.insert( subobjectTable, subobject )
        end
    end

    return subobjectTable
end


--- @param setData table Array data to be set
--- @param tableData table|nil Array data from API
--- @param nameKey string Key of the value being used as name in the SMW property
--- @param valueKey string Key of the value being used as value in the SMW property
--- @param prefix string Prefix of the SMW property name
--- @param translateFn function The translate function used to translate argument names
--- @param formatConfig table An optional format definition in the style of data.json, used for formatting
function commonSMW.setFromTable( setData, tableData, nameKey, valueKey, prefix, translateFn, formatConfig )
	checkType( 'Module:Common/SMW.setFromTable', 1, setData, 'table' )
	checkTypeMulti( 'Module:Common/SMW.setFromTable', 2, tableData, { 'table', 'nil' } )
	checkType( 'Module:Common/SMW.setFromTable', 3, nameKey, 'string' )
	checkType( 'Module:Common/SMW.setFromTable', 4, valueKey, 'string' )
	checkType( 'Module:Common/SMW.setFromTable', 5, prefix, 'string' )
	checkType( 'Module:Common/SMW.setFromTable', 6, translateFn, 'function' )

	if tableData == nil or type( tableData ) ~= 'table' then
		return
	end

	for _, data in pairs( tableData ) do
		local name = data[nameKey] or ''
		name = 'SMW_' .. prefix .. name:gsub('^%l', mw.ustring.upper):gsub( ' ', '' )

		if translateFn( name ) ~= nil then
			local value

			value = data[valueKey]

			-- Handle percentage such as 10% used in modifiers
			if type( value ) == 'string' and value:find( '%d+%%' ) then
				value = mw.ustring.gsub( value, '%%', '' ) / 100
			end

			setData[ translateFn( name ) ] = commonSMW.format( formatConfig, value )
		end
	end
end


return commonSMW

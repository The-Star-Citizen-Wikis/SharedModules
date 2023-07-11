local commonSMW = {}

local common = require( 'Module:Common' )
local libraryUtil = require( 'libraryUtil' )
local checkType = libraryUtil.checkType


--- Adds SMW properties to a table either from the API or Frame arguments
---
--- @param apiData table Data from the Wiki API
--- @param frameArgs table Frame args processed by Module:Arguments
--- @param smwSetObject table The SMW Object that gets passed to mw.smw.set
--- @param translateFn function The function used to translate argument names
--- @param moduleConfig table Table from config.json
--- @param moduleData table Table from data.json
--- @param moduleName string The module name used to retrieve fallback attribute names
--- @return void
function commonSMW.addSmwProperties( apiData, frameArgs, smwSetObject, translateFn, moduleConfig, moduleData, moduleName )
    checkType( 'Module:Common/SMW.addSmwProperties', 1, apiData, 'table' )
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
			if string.sub( key, 1, 3 ) == 'SMW' then
				smwKey = key
				from = get_from
			end
		end

		smwKey = translateFn( smwKey )

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
					value = getFromArgs( datum, translateFn( key ) )

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

				for index, val in ipairs( value ) do
					-- This should not happen
					if type( val ) == 'table' then
						val = string.format( '!ERROR! Key %s is a table value; please fix', key )
					end

					-- Format number for SMW
					if datum.type == 'number' then
						val = common.formatNum( val )
					-- Multilingual Text, add a suffix
					elseif datum.type == 'multilingual_text' and moduleConfig.smw_multilingual_text == true then
						val = string.format( '%s@%s', val, moduleConfig.module_lang or mw.getContentLanguage():getCode() )
					-- Num format
					elseif datum.type == 'number' then
						val = common.formatNum( val )
					-- String format
					elseif type( datum.format ) == 'string' then
						if string.find( datum.format, '%', 1, true  ) then
							val = string.format( datum.format, val )
						elseif datum.format == 'ucfirst' then
							val = lang:ucfirst( val )
						elseif datum.format == 'replace-dash' then
							val = string.gsub( val, '%-', ' ' )
						end
					end

					table.remove( value, index )
					table.insert( value, index, val )
				end

				if type( value ) == 'table' and #value == 1 then
					value = value[ 1 ]
				end

                smwSetObject[ smwKey ] = value
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
--- @return void
function commonSMW.addSmwAskProperties( smwAskObject, translateFn, moduleConfig, moduleData )
	checkType( 'Module:Common/SMW.addSmwAskProperties', 1, smwAskObject, 'table' )
	checkType( 'Module:Common/SMW.addSmwAskProperties', 2, translateFn, 'function' )
	checkType( 'Module:Common/SMW.addSmwAskProperties', 3, moduleConfig, 'table' )
	checkType( 'Module:Common/SMW.addSmwAskProperties', 4, moduleData, 'table' )

	local langSuffix = ''
	if moduleConfig.smw_multilingual_text == true then
		langSuffix = '+lang=' .. ( moduleConfig.module_lang or mw.getContentLanguage():getCode() )
	end

	for _, queryPart in pairs( moduleData.smw_data ) do
		local smwKey
		for key, _ in pairs( queryPart ) do
			if string.sub( key, 1, 3 ) == 'SMW' then
				smwKey = key
				break
			end
		end

		local formatString = '?%s'

		if queryPart.smw_format then
			formatString = formatString .. queryPart.smw_format
		end

		-- safeguard
		if smwKey ~= nil then
			table.insert( smwAskObject, string.format( formatString, translateFn( smwKey ) ) )

			if queryPart.type == 'multilingual_text' then
				table.insert( smwAskObject, langSuffix )
			end
		end
	end
end


return commonSMW
local common = {}

--- Checks if Api Request was successful and if the Response is valid
--- @param response table
--- @param errorOnData boolean
--- @param errorOnData boolean
--- @return boolean
function common.checkResponseStructure( response, errorOnStatus, errorOnData )
    if response[ 'status_code' ] ~= nil and response[ 'status_code' ] ~= 200 then
        if errorOnStatus == nil or errorOnStatus == true then
            error( 'API request returns the error code ' .. response[ 'status_code' ] .. '(' .. response[ 'message' ] .. ')', 0 )
        end
        return false
    end

    if response[ 'data' ] == nil then
        if errorOnData == nil or errorOnData == true then
            error( 'API data does not contain a "data" field', 0 )
        end
        return false
    end
    return true
end

--- Sets the table to return nil for unknown keys instead of erroring out
--- For deep nested tables use apiData:get( 'table1.table2.table3' ) etc.
--- @param apiData table - The json decoded data from the api
--- @return table
function common.makeAccessSafe( apiData )
	local function set( data )
		setmetatable( data, {
			__index = function(self, key)
				return nil
			end
		} )
	end

	local function iterSet( data )
		set( data )

		for _, v in pairs( data ) do
			if type( v ) == 'table' then
				iterSet( v )
			end
		end
	end

	iterSet( apiData )

	apiData.get = function( self, key )
		local parts = mw.text.split( key, '.', true )

		local val = self
		for _, part in ipairs( parts ) do
			local success, conv = pcall( tonumber, part, 10 )
			if success and conv ~= nil then
				part = conv
			end

			if val[ part ] == nil then
				return nil
			end

			val = val[ part ]
		end

		if val == nil or ( type( val ) == 'table' and #val == 0 ) or type( val ) == 'function' then
			return nil
		end

		return val
	end

	return apiData
end

return common

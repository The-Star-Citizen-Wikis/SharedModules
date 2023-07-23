require( 'strict' )

local Translate = {}

local metatable = {}
local methodtable = {}

metatable.__index = methodtable

local libraryUtil = require( 'libraryUtil' )
local checkType = libraryUtil.checkType

--- Cache table containing i18n data at the 'data' key, and a key map at the 'keys' key
--- The table is keyed by the i18n.json module name
local cache = {}
local i18nDataset = 'Module:Translate/i18n.json'


--- Uses the current title as the base and appends '/i18n.json'
---
--- @param dataset table
--- @return string|nil
local function guessDataset( dataset )
    if string.find( dataset, ':', 1, true ) then
        return dataset
    elseif type( dataset ) == 'string' then
        return string.format( 'Module:%s/i18n.json', dataset )
    end

    return nil
end


--- Loads a dataset and saves it to the cache
---
--- @param dataset string
--- @return table { data = "The dataset", keys = "Translation key mapped to index" }
local function load( dataset )
    if cache[ dataset ] ~= nil then
        return cache[ dataset ]
    end

    local data = mw.loadJsonData( dataset )
    local keys = {}
    for index, row in ipairs( data.data ) do
        keys[ row[ 1 ] ] = index
    end

    cache[ dataset ] = {
        data = data,
        keys = keys
    }

    return cache[ dataset ]
end


--- Retrieves a message from a dataset and formats it according to parameters and language
---
--- @param dataset string
--- @param key string
--- @param params table
--- @param lang string
local function formatMessage( dataset, key, params, lang )
    local data = load( dataset )

    if data.keys[ key ] == nil then
        error( formatMessage( i18nDataset, 'error_bad_msgkey', { key, dataset }, mw.getContentLanguage():getCode() ) )
    end

    local msg = data.data.data[ data.keys[ key ] ][ 2 ]

    if msg == nil then
        error( formatMessage( i18nDataset, 'error_bad_msgkey', { key, dataset }, mw.getContentLanguage():getCode() ) )
    end

    msg = msg[ lang ] or error( string.format( 'Language "%s" not found for key "%s"', lang, key ) )

    local result = mw.message.newRawMessage( msg, unpack( params or {} ) )

    return result:plain()
end


--- Translates a message
---
--- @param dataset string
--- @param key string
--- @return string
function methodtable.format( dataset, key, ... )
    dataset = guessDataset( dataset )

    checkType('format', 1, dataset, 'string')
    checkType('format', 2, key, 'string')

    local lang = mw.getContentLanguage():getCode()

    return formatMessage( dataset, key, {...}, lang )
end


--- Translates a message in a given language
---
--- @param lang string
--- @param dataset string
--- @param key string
--- @return string
function methodtable.formatInLanguage( lang, dataset, key, ... )
    dataset = guessDataset( dataset )

    checkType('formatInLanguage', 1, lang, 'string')
    checkType('formatInLanguage', 2, dataset, 'string')
    checkType('formatInLanguage', 3, key, 'string')

    return formatMessage( dataset, key, {...}, lang )
end


--- Wrapper function for Translate.getTemplateData that wraps the output in a <templatedata> tag
---
--- @param frame table Current MW Frame
--- @return string
function Translate.doc( frame )
    local dataset = frame.args[ 1 ] or frame.args[ 'dataset' ] or ( mw.title.getCurrentTitle().prefixedText .. '/i18n.json' )

    return frame:extensionTag( 'templatedata', Translate.getTemplateData( dataset ) )
end


--- Base logic taken from Module:TNT
--- Iterates through all user settable arguments and outputs json usable in a <templatedata> tag
---
--- @param dataset string The data.json page from which the arguments are taken
--- @return string Json
function Translate.getTemplateData( dataset )
    local data = load( guessDataset( dataset ) )
    local instance = Translate:new( dataset )

    local names = {}
    for _, field in ipairs( data.data.schema.fields ) do
        table.insert( names, field.name )
    end

    local numOnly = true
    local params = {}
    local paramOrder = {}

    for _, row in ipairs( data.data.data ) do
        local newVal = {}
        local name

        if row[ 1 ]:sub( 1, 3 ) == 'ARG' then
            for pos, columnName in ipairs( names ) do
                if columnName == 'id' then
                    name = instance.format( dataset, row[ pos ] )
                elseif columnName ~= 'message' then
                    newVal[ columnName ] = row[ pos ]

                    -- Allow to share examples and label
                    if ( columnName == 'example' or columnName == 'label' ) and type( row[ pos ] ) == 'string' then
                        newVal[ columnName ] = {
                            de = row[ pos ],
                            en = row[ pos ],
                        }
                    end
                end
            end

            if name and newVal[ 'type' ] ~= nil then
                if type( name ) ~= "number" and ( type( name ) ~= "string" or not string.match( name, "^%d+$" ) ) then
                    numOnly = false
                end

                params[ name ] = newVal

                table.insert( paramOrder, name )

                -- TODO: Limit this to a specified subset of url args
                if row[ 1 ]:sub( -3 ) == 'Url' then
                    for i = 1, 4 do
                        local tmp = {}
                        for k, v in pairs( newVal ) do
                            if type( v ) == 'table' then
                                tmp[ k ] = {}
                                for k1, v1 in pairs( v ) do
                                    tmp[ k ][ k1 ] = v1
                                end
                            else
                                tmp[ k ] = v
                            end
                        end

                        local nameI = name .. tostring( i )
                        tmp[ 'required' ] = false
                        tmp[ 'suggested' ] = false
                        params[ nameI ] = tmp

                        table.insert( paramOrder, nameI )
                    end
                end
            end
        end
    end

    -- Work around json encoding treating {"1":{...}} as an [{...}]
    if numOnly then
        params['zzz123']=''
    end

    local json = mw.text.jsonEncode({
        params = params,
        paramOrder = paramOrder,
        description = data.template_description,
    })

    if numOnly then
        json = string.gsub( json,'"zzz123":"",?', "" )
    end

    return json
end


--- Calls TNT with the given key
---
--- @param dataset string The i18n.json page
--- @param config table The calling module's config
--- @param key string The translation key
--- @param addSuffix boolean|nil Adds a language suffix if config.smw_multilingual_text is true
--- @return string If the key was not found in the .tab page, the key is returned
function methodtable.translate( self, dataset, config, key, addSuffix, ... )
    checkType( 'Module:Translate.translate', 1, self, 'table' )
    checkType( 'Module:Translate.translate', 2, dataset, 'string' )
    checkType( 'Module:Translate.translate', 3, config, 'table' )
    checkType( 'Module:Translate.translate', 4, key, 'string' )
    checkType( 'Module:Translate.translate', 5, addSuffix, 'boolean', true )

	addSuffix = addSuffix or false
	local success, translation

	local function multilingualIfActive( input )
		if addSuffix and config.smw_multilingual_text == true then
			return string.format( '%s@%s', input, config.module_lang or mw.getContentLanguage():getCode() )
		end

		return input
	end

	if config.module_lang ~= nil then
		success, translation = pcall( self.formatInLanguage, config.module_lang, dataset, key or '', ... )
	else
		success, translation = pcall( self.format, dataset, key or '', ... )
	end

	if not success or translation == nil then
        local title = mw.title.new( guessDataset( dataset ) )

        if not title.exists then
            error( string.format( 'I18N table "%s" does not exist!', dataset ), 3 )
        end

		return nil
	end

	return multilingualIfActive( translation )
end


--- New Instance
---
--- @return table Translate
function Translate.new( self, dataset )
    local instance = {
        dataset = dataset or nil
    }

    setmetatable( instance, metatable )

    return instance
end


return Translate
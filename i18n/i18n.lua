require( 'strict' )

local i18n = {}

local metatable = {}
local methodtable = {}

metatable.__index = methodtable

local libraryUtil = require( 'libraryUtil' )
local checkType = libraryUtil.checkType

--- Cache table containing i18n data
--- e.g. cache['en']['SMW'] will get you the SMW table in English
local cache = {}


--- Retrieve dataset namespace from key prefix
---
--- @param key string The translation key
--- @return string
local function getNamespace( key )
    local namespace = string.match( key, '([^_]*)' )
    return namespace
end


--- Retrieve a list of applicable language codes
---
--- @return table
local function getLanguageCodes()
    local mwlang = mw.language.getContentLanguage()
    local langCodes = { mwlang:getCode() }

    local fallbackLangCodes = mwlang:getFallbackLanguages()
    if next( fallbackLangCodes ) ~= nil then
        for _, fallbackLangCode in pairs( fallbackLangCodes ) do
            table.insert( langCodes, fallbackLangCode )
        end
    end
    return langCodes
end


--- Loads a dataset and saves it to the cache
---
--- @param lang string
--- @param namespace string
--- @return table|nil { data = "The dataset", keys = "Translation key mapped to index" }
local function load( lang, namespace )
    -- Init language cache if it does not exist
    if cache[ lang ] == nil then
        cache[ lang ] = {}
    end

    if cache[ lang ][ namespace ] then
        mw.log( string.format( '[i18n] Dataset[%s][%s]: Cache HIT', lang, namespace ) )
        return cache[ lang ][ namespace ]
    end

    local datasetName = string.format( 'Module:i18n/%s/%s.json', namespace, lang )
    local success, data = pcall( mw.loadJsonData, datasetName )

    if not success then
        mw.log( string.format( '[i18n] Dataset[%s][%s]: %s not found on wiki', lang, namespace, datasetName ) )
        -- Cache the empty result so we do not run mw.loadJsonData again
        cache[ lang ][ namespace ] = {}
        return
    end

    cache[ lang ][ namespace ] = data
    mw.log( string.format( '[i18n] Dataset[%s][%s]: Cache MISS', lang, namespace ) )

    return cache[ lang ][ namespace ]
end


--- Returns translated message
---
--- @param key string The translation key
--- @return string If the key was not found in the i18n table, the key is returned
function methodtable.translate( self, key )
    checkType( 'Module:i18n.translate', 1, self, 'table' )
    checkType( 'Module:i18n.translate', 2, key, 'string' )

    mw.log( string.format( '[i18n] Message key: %s', key ) )

    local namespace = getNamespace( key )
    if namespace == nil then
        -- No namespace found error
        return key
    end

    local message
    local languages = getLanguageCodes()

    local i = 1
    while ( message == nil and i <= #languages ) do
        local dataset = load( languages[ i ], namespace )
        if dataset then
            local match = dataset[ key ]
            if match then
                message = match
                mw.log( string.format( '[i18n] Message MATCH: %s', message ) )
            end
        end
        i = i + 1
    end
    return message or key
end


--- New Instance
---
--- @return table i18n
function i18n.new( self )
    local instance = {}

    setmetatable( instance, metatable )

    return instance
end


return i18n
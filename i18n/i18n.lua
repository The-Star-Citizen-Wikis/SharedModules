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

--- Cache language codes for reuse
local languages = {}


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
    if #languages > 0 then return languages end
    local mwlang = mw.language.getContentLanguage()
    local langCodes = { mwlang:getCode() }

    local fallbackLangCodes = mwlang:getFallbackLanguages()
    if next( fallbackLangCodes ) ~= nil then
        for _, fallbackLangCode in pairs( fallbackLangCodes ) do
            table.insert( langCodes, fallbackLangCode )
        end
    end

    mw.log( string.format( '[i18n] 🌐 Setting language chain: %s', table.concat( langCodes, '→' ) ) )
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
        return cache[ lang ][ namespace ]
    end

    local datasetName = string.format( 'Module:i18n/%s/%s.json', namespace, lang )
    local success, data = pcall( mw.loadJsonData, datasetName )

    if not success then
        mw.log( string.format( '[i18n] 🚨 Loading dataset[%s][%s]: %s not found on wiki', lang, namespace, datasetName ) )
        -- Cache the empty result so we do not run mw.loadJsonData again
        cache[ lang ][ namespace ] = {}
        return
    end

    cache[ lang ][ namespace ] = data
    mw.log( string.format( '[i18n] ⌛ Loading dataset[%s][%s]: %s', lang, namespace, datasetName ) )

    return cache[ lang ][ namespace ]
end


--- Returns translated message
---
--- @param key string The translation key
--- @return string If the key was not found in the i18n table, the key is returned
function methodtable.translate( self, key )
    checkType( 'Module:i18n.translate', 1, self, 'table' )
    checkType( 'Module:i18n.translate', 2, key, 'string' )

    mw.log( string.format( '[i18n] 🔍 Looking for message: %s', key ) )

    local namespace = getNamespace( key )
    if namespace == nil then
        -- No namespace found error
        return key
    end

    languages = getLanguageCodes()

    local message
    local i = 1

    while ( message == nil and i <= #languages ) do
        local dataset = load( languages[ i ], namespace )
        if dataset then
            local match = dataset[ key ]
            if match then
                message = match
                mw.log( string.format( '[i18n] ✔️ Found message: %s', message ) )
            end
        end
        i = i + 1
    end

    if message == nil then
        message = key
        mw.log( string.format( '[i18n] ❌ Could not found message: %s', key ) )
    end

    return message
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
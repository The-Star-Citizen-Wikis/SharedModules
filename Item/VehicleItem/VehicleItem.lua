require( 'strict' )

local VehicleItem = {}


local metatable = {}
local methodtable = {}

metatable.__index = methodtable


local TNT = require( 'Module:Translate' ):new()
local data = mw.loadJsonData( 'Module:Item/VehicleItem/data.json' )
-- Intentionally re-use the config from Module:Item
local config = mw.loadJsonData( 'Module:Item/config.json' )


local lang
if config.module_lang then
    lang = mw.getLanguage( config.module_lang )
else
    lang = mw.getContentLanguage()
end


--- FIXME: This should go to somewhere else, like Module:Common
--- Calls TNT with the given key
---
--- @param key string The translation key
--- @param addSuffix boolean Adds a language suffix if config.smw_multilingual_text is true
--- @return string If the key was not found in the .tab page, the key is returned
local function translate( key, addSuffix, ... )
    addSuffix = addSuffix or false
    local success, translation

    local function multilingualIfActive( input )
        if addSuffix and config.smw_multilingual_text == true then
            return string.format( '%s@%s', input, config.module_lang or mw.getContentLanguage():getCode() )
        end

        return input
    end

    if config.module_lang ~= nil then
        success, translation = pcall( TNT.formatInLanguage, config.module_lang, 'Module:Item/VehicleItem/i18n.json', key or '', ... )
    else
        success, translation = pcall( TNT.format, 'Module:Item/VehicleItem/i18n.json', key or '', ... )
    end

    if not success or translation == nil then
        return multilingualIfActive( key )
    end

    return multilingualIfActive( translation )
end


--- Adds the properties valid for this item to the SMW Set object
---
--- @param smwSetObject table
function methodtable.addSmwProperties( self, smwSetObject )
    local smwCommon = require( 'Module:Common/SMW' )

    smwCommon.addSmwProperties(
        self.apiData,
        self.frameArgs,
        smwSetObject,
        translate,
        config,
        data,
        'VehicleItem'
    )
end


function methodtable.addSmwAskProperties( self, smwAskObject )
    require( 'Module:Common/SMW' ).addSmwQueryParams(
        smwAskObject,
        translate,
        config,
        data
    )
end


function methodtable.addInfoboxData( self, infobox, smwData )

end


--- New Instance
function VehicleItem.new( self, apiData, frameArgs )
    local instance = {
        apiData = apiData,
        frameArgs = frameArgs
    }

    setmetatable( instance, metatable )

    return instance
end


return VehicleItem
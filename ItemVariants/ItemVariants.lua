require( 'strict' )

local ItemVariants = {}

local metatable = {}
local methodtable = {}

metatable.__index = methodtable

local MODULE_NAME = 'Module:ItemVariants'
local config = mw.loadJsonData( MODULE_NAME .. '/config.json' )

local TNT = require( 'Module:Translate' ):new()


--- Wrapper function for Module:Translate.translate
---
--- @param key string The translation key
--- @param addSuffix boolean|nil Adds a language suffix if config.smw_multilingual_text is true
--- @return string If the key was not found in the .tab page, the key is returned
local function translate( key, addSuffix, ... )
    return TNT:translate( MODULE_NAME .. '/i18n.json', config, key, addSuffix, { ... } ) or key
end


--- Remove all occurances of words from string
---
--- @param inputString string the string to be removed from
--- @param wordsToRemove string the string containing the words to remove
--- @return string
local function removeWordsFromString( inputString, wordsToRemove )
    -- Split the input string into individual words
    local words = {}
    for word in inputString:gmatch( '%S+' ) do
        table.insert( words, word )
    end

    -- Create a set of words to remove
    local wordsSet = {}
    for word in wordsToRemove:gmatch( '%S+' ) do
        wordsSet[ word ] = true
    end

    -- Filter out words that need to be removed
    local cleanedWords = {}
    for _, word in ipairs( words ) do
        if not wordsSet[ word ] then
            table.insert( cleanedWords, word )
        end
    end

    -- Join the cleaned words back into a string
    local cleanedString = table.concat( cleanedWords, ' ' )

    return cleanedString
end


--- Creates the object that is used to query the SMW store
---
--- @param page string the item page containing data
--- @return table|string
local function makeSmwQueryObject( self, page )
    local itemBaseVariantName = translate( 'SMW_ItemBaseVariantName' )

    local itemBaseVariant = mw.smw.ask {
        mw.ustring.format( '[[-%s::%s]]', itemBaseVariantName, page ),
        '?#-=name',
        '?Page Image#-=image',
        limit = 1
    }

    if type( itemBaseVariant ) ~= 'table' or #itemBaseVariant ~= 1 then
        return ''
    end

    mw.logObject( itemBaseVariant, 'itemBaseVariant' )

    itemBaseVariant = itemBaseVariant[ 1 ]
    self.itemBaseVariant = itemBaseVariant

    local query = {
        '[[:+]]',
        mw.ustring.format(
            '<q>[[%s::%s]] || [[%s::%s]] || [[-%s::%s]]</q>',
            itemBaseVariant.name,
            page,
            itemBaseVariantName,
            itemBaseVariant.name,
            itemBaseVariantName,
            itemBaseVariant.name
        ),
        '?#-=name',
        '?Page Image#-=image'
    }

    return query
end


--- Queries the SMW Store
--- @return table|nil
function methodtable.getSmwData( self, page )
    --mw.logObject( self.smwData, 'cachedSmwData' )
    -- Cache multiple calls
    if self.smwData ~= nil then
        return self.smwData
    end

    local smwData = mw.smw.ask( makeSmwQueryObject( self, page ) )

    if smwData == nil or smwData[ 1 ] == nil then
        return nil
    end

    -- Insert base variant back to the table
    table.insert( smwData, 1, self.itemBaseVariant )

    mw.logObject( smwData, 'getSmwData' )
    self.smwData = smwData

    return self.smwData
end

--- Generates wikitext needed for the template
--- @return string
function methodtable.out( self )
    local smwData = self:getSmwData( self.page )

    if smwData == nil then
        local msg = mw.ustring.format( translate( 'error_no_variants_found' ), self.page )
		return require( 'Module:Hatnote' )._hatnote( msg, { icon = 'WikimediaUI-Error.svg' } )
    end

    local containerHtml = mw.html.create( 'div' ):addClass( 'template-itemVariants' )

    for i, variant in ipairs( smwData ) do
        local displayName = removeWordsFromString( variant.name, self.itemBaseVariant.name )
        -- Sometimes base variant does have a variant name
        if displayName == '' then
            if i == 1 then
                displayName = '(Base)'
            else
                displayName = variant.name
            end
        end

        mw.log( displayName, variant.name )

        local variantHtml = mw.html.create( 'div' ):addClass( 'template-itemVariant' )

        if variant.name == self.page then
            variantHtml:addClass( 'template-itemVariant--selected' )
        end

        variantHtml:tag( 'div' )
            :addClass( 'template-itemVariant-fakelink' )
            :wikitext( mw.ustring.format( '[[%s]]', variant.name ) )
        variantHtml:tag( 'div' )
            :addClass( 'template-itemVariant-image' )
            :wikitext( mw.ustring.format( '[[%s|128px|link=]]', variant.image ) )
        variantHtml:tag( 'div' )
            :addClass( 'template-itemVariant-title' )
            :wikitext( displayName )
        containerHtml:node( variantHtml )
    end

    return tostring( containerHtml ) .. mw.getCurrentFrame():extensionTag {
        name = 'templatestyles', args = { src = MODULE_NAME .. '/styles.css' }
    }
end

--- New Instance
---
--- @return table ItemVariants
function ItemVariants.new( self, page )
    local instance = {
        page = page or nil
    }

    setmetatable( instance, metatable )

    return instance
end

--- Parser call for generating the table
function ItemVariants.outputTable( frame )
    local args = require( 'Module:Arguments' ).getArgs( frame )
    local page = args[ 1 ] or mw.title.getCurrentTitle().rootText

    local instance = ItemVariants:new( page )
    local out = instance:out()

    return out
end

--- For debugging use
---
--- @param page string page name on the wiki
--- @return string
function ItemVariants.test( page )
    local instance = ItemVariants:new( page )
    local out = instance:out()

    return out
end

return ItemVariants

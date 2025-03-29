require( 'strict' )

local p = {}

local hatnote = require( 'Module:Hatnote' )._hatnote

local MODULE_NAME = 'Module:Vehicle availability'

local columnMappings = {
    { key = 'starSystemName', display = 'System' },
    { key = 'terminalName', display = 'Terminal' },
    { key = 'price', display = 'Price' }
}


--- Checks if a table has any elements
--- @param t table
--- @return boolean
local function hasElements( t )
    if t == nil then
        return false
    end
    for _ in ipairs(t) do
        return true
    end
    return false
end


--- Formats a value for displaybased on the key
--- @param key string
--- @param row table
--- @return string
local function formatValue( key, row )
    local value = row[key]

    if value == nil then
        return ''
    end

    if key == 'starSystemName' then
        return string.format( '[[%s system|%s]]', value, value )
    end

    if key == 'terminalName' then
        local linkKeys = { 'companyName', 'cityName', 'spaceStationName' }
        local parts = {}
        for part in value:gmatch( '[^%-]+' ) do
            part = part:match( '^%s*(.-)%s*$' ) -- trim whitespace
            local shouldLink = false
            for _, linkKey in ipairs( linkKeys ) do
                if row[linkKey] and part == row[linkKey] then
                    shouldLink = true
                    break
                end
            end
            if shouldLink then
                table.insert( parts, '[[' .. part .. ']]' )
            else
                table.insert( parts, part )
            end
        end
        return table.concat( parts, ' - ' )
    end

    if key == 'price' then
        return mw.getContentLanguage():formatNum( value )
    end

    return value
end


--- Generates HTML for a table
--- @param data table
--- @param caption string
--- @return table
local function getTableHtml( data, caption )
    local html = mw.html.create( 'table' )
    html:addClass( 't-vehicle-availability-table wikitable wikitable--fluid sortable' )

    if caption then
        html:tag( 'caption' ):wikitext( caption )
    end

    local headerRow = html:tag( 'tr' )
    for _, mapping in ipairs( columnMappings ) do
        headerRow:tag( 'th' ):wikitext( mapping.display )
    end

    for _, row in ipairs( data ) do
        local tr = html:tag( 'tr' )

        for _, mapping in ipairs( columnMappings ) do
            tr:tag( 'td' ):wikitext( formatValue( mapping.key, row ) )
        end
    end

    return html
end


--- Gets the data from the data page
--- @param page string page name on the wiki
--- @return table|nil
function p.getData( page )
    local dataPage = MODULE_NAME .. '/' .. page .. '.json'
    local success, result = pcall( mw.loadJsonData, dataPage )

    if not success then
        mw.log( '🚨 [Vehicle availability] Failed to load JSON data from ' .. dataPage .. ': ' .. tostring(result) )
        return nil
    end

    return result
end


--- Generates wikitext needed for the template
--- @param page string page name on the wiki
--- @return string
function p.out( page )
    local data = p.getData( page )

    if data == nil then
        return hatnote(
            string.format( 'No availability data found for [[%s]]', page ),
            { icon = 'WikimediaUI-Error.svg' }
        )
    end

    local html = mw.html.create()

    html:wikitext(
        hatnote(
            'Purchase and rental data are sourced from [https://uexcorp.space UEX]',
            { icon = 'WikimediaUI-Robot.svg' }
        )
    )

    if data.purchaseLocations == nil then
        html:wikitext(
            hatnote(
                string.format( 'No purchase locations data found for [[%s]]', page ),
                { icon = 'WikimediaUI-Error.svg' }
            )
        )
    elseif not hasElements( data.purchaseLocations ) then
        html:wikitext(
            hatnote(
                string.format( '[[%s]] is not available for purchase', page ),
                { icon = 'WikimediaUI-Notice.svg' }
            )
        )
    else
        html:node( getTableHtml( data.purchaseLocations, 'Purchase' ) )
    end

    if data.rentalLocations == nil then
        html:wikitext(
            hatnote(
                string.format( 'No rental locations data found for [[%s]]', page ),
                { icon = 'WikimediaUI-Error.svg' }
            )
        )
    elseif not hasElements( data.rentalLocations ) then
        html:wikitext(
            hatnote(
                string.format( '[[%s]] is not available for rental', page ),
                { icon = 'WikimediaUI-Notice.svg' }
            )
        )
    else
        html:node( getTableHtml( data.rentalLocations, 'Rental' ) )
    end

    local frame = mw.getCurrentFrame()

    return table.concat( {
        frame:extensionTag( {
            name = 'templatestyles',
            args = { src = MODULE_NAME .. '/styles.css' }
        } ),
        -- TODO: Convert this into module
        frame:expandTemplate{ title = 'Find item UIF' },
        '<hr>',
        tostring( html )
    } )
end


--- Wikitext template for the vehicle availability
---
--- @param frame table
--- @return string
function p.template( frame )
    local args = require( 'Module:Arguments' ).getArgs( frame )
    local page = args[ 1 ] or mw.title.getCurrentTitle().text
    return p.out( page )
end

return p

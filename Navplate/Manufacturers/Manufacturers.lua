require( 'strict' )

-- This is barebone but the idea is to make a generic module that
-- build any navplate from template defined from data.json
--
-- TODO:
-- - Implement i18n
-- - Support group headers
-- - Support icon

local p = {}

local navplate = require( 'Module:Navplate' )
local template = mw.loadJsonData( 'Module:Navplate/Manufacturers/data.json' )
local manufacturer = require( 'Module:Manufacturer' ):new()
local util = require( 'Module:Navplate/Util' )

--- Outputs the table
--- @param mfu string
--- @return string
local function render( mfu )
    local mfuName = manufacturer:get( mfu ) and manufacturer:get( mfu ).name or
        mfu

    if mfuName == nil then
        return string.format(
            '<strong class="error">Error: %s.</strong>',
            'Missing manufacturer parmeter'
        )
    end

    local smwData = util.getSmwData( {
        conditions = {
            'Category:' .. mfuName
        },
        printout = {
            'Category'
        }
    } )

    local itemsData = nil
    if smwData ~= nil then
        if template and template.content then
            itemsData = util.buildItemsData( smwData, template.content )
        else
            mw.log( '[Module:Navplate/Manufacturers] Error: Template content not loaded or missing.' )
            itemsData = {}
        end
    end

    local navplateData = {
        subtitle = 'Products of',
        title = string.format( '[[%s]]', mfuName ),
        items = itemsData
    }

    --mw.logObject( navplateData, '[Module:Navplate/Manufacturers] Passing navplate data to Navplate.fromData:' )

    return navplate.fromData( navplateData )
end

--- Main entry point
---
--- @param frame table Invocation frame
--- @return string
function p.main( frame )
    local args = require( 'Module:Arguments' ).getArgs( frame )
    return render( args[1] )
end

--- Test function
--- @param mfu string
function p.test( mfu )
    render( mfu )
end

return p

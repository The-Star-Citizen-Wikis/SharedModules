require( 'strict' )

local util = require( 'Module:InfoboxNeueMkII/Util' )
local types = require( 'Module:InfoboxNeueMkII/Types' )

local p = {}


--- Renders an infobox item.
---
--- @param data table
--- @return mw.html|nil
function p.getHtml( data )
    --- @type ItemComponentData|nil
    local item = util.validateAndConstruct( data, types.ItemComponentDataSchema )

    if not item then
        return nil
    end


    local root = mw.html.create( 'div' )
    root:addClass( 't-infobox-item' )

    if item.class then
        root:addClass( item.class )
    end

    if util.isNonEmptyString( item.label ) then
        root:tag( 'div' )
            :addClass( 't-infobox-item-label' )
            :wikitext( item.label )
            :done()
    end

    root:tag( 'div' )
        :addClass( 't-infobox-item-content' )
        :wikitext( item.content )
        :done()

    return root
end

return p

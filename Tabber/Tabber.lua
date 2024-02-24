local Tabber = {}


--- Helper function to get Tabber length
---
--- @param data table
--- @return number
local function getTabberLength( data )
    local length = 0

    for k, _ in next, data do
        if mw.ustring.find( k, 'label' ) == 1 then
            length = length + 1
        end
    end

    return length
end


--- Render Tabber
---
--- @param data table { label{n}, content{n} }
--- @return string wikitext of Tabber
function Tabber.renderTabber( data )
    if type( data ) ~= 'table' then
        return ''
    end

    local tabberContent = {}

    for i = 1, getTabberLength( data ) do
        local label = data[ 'label' .. i ]
        local content = data[ 'content' .. i ]

        if label ~= nil and label ~= '' and content ~= nil and content ~= '' then
            table.insert( tabberContent, table.concat( { '|-|', label, '=', content } ) )
        end
    end

    if next( tabberContent ) == nil then
        return ''
    end

    return mw.getCurrentFrame():extensionTag{
        name = 'tabber', content = table.concat( tabberContent )
    }
end


return Tabber

--- Lua functions for Extension:FloatingUI
---
--- WARNING
--- -------
--- THIS IS AN EXPERIMENTAL MODULE MADE FOR AN EXPERIMENTAL EXTENSION
--- THIS IS NOT READY FOR PRODUCTION AND SUBJECT TO CHANGE
--- -------
local FloatingUI = {}


--- Return the HTML of the FloatingUI section component as string
---
--- @param data table {label, data, desc, col, inline)
--- @return string html
function FloatingUI.renderSection( data )
    if data == nil or type( data ) ~= 'table' or next( data ) == nil then return '' end

    local htmlTag = 'div'
    if data[ 'inline' ] == true then
        htmlTag = 'span'
    end

    local html = mw.html.create( htmlTag )
        :addClass( 't-floatingui-section' )

    if data[ 'col' ] then html:addClass( 't-floatingui-section--cols-' .. data[ 'col' ] ) end

    local dataOrder = { 'label', 'data', 'desc' }
    for _, key in ipairs( dataOrder ) do
        if data[ key ] then
            html:tag( htmlTag )
                :addClass( 't-floatingui-' .. key )
                :wikitext( data[ key ] )
        end
    end
    return tostring( html )
end

--- Load FloatingUI library only
---
--- @return string wikitext Wikitext to load the FloatingUI library only
function FloatingUI.load()
    local frame = mw.getCurrentFrame()
    return frame:extensionTag {
        name = 'templatestyles', args = { src = 'Module:FloatingUI/styles.css' }
    } .. frame:callParserFunction {
        name = '#floatingui', args = { '' }
    }
end

--- Render the HTML for FloatingUI
---
--- @param reference string Reference wikitext to trigger the floating element
--- @param content string Content wikitext in the floating element
--- @param inline boolean Whether to render inline
--- @return string wikitext Wikitext for the HTML required to use FloatingUI
function FloatingUI.render( reference, content, inline )
    if not reference or not content then
        return ''
    end

    local htmlTag = 'div'
    if inline == true then
        htmlTag = 'span'
    end

    local html = mw.html.create()
        :tag( htmlTag )
        :addClass( 'ext-floatingui-reference' )
        :wikitext( reference )
        :done()
        :tag( htmlTag )
        :addClass( 'ext-floatingui-content' )
        :tag( htmlTag )
        :addClass( 'mw-parser-output' )
        :tag( htmlTag )
        :addClass( 't-floatingui' )
        :wikitext( content )
        :allDone()

    return tostring( html )
end

return FloatingUI

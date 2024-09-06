--- Lua functions for Extension:FloatingUI
---
--- WARNING
--- -------
--- THIS IS AN EXPERIMENTAL MODULE MADE FOR AN EXPERIMENTAL EXTENSION
--- THIS IS NOT READY FOR PRODUCTION AND SUBJECT TO CHANGE
--- -------
local FloatingUI = {}


--- Load FloatingUI library only
---
--- @return string wikitext Wikitext to load the FloatingUI library only
function FloatingUI.load()
    return mw.getCurrentFrame():callParserFunction {
        name = '#floatingui'
    }
end

--- Render FloatingUI
---
--- @param reference string Reference wikitext to trigger the floating element
--- @param content string Content wikitext in the floating element
--- @return string wikitext Wikitext for the HTML required to use FloatingUI
function FloatingUI.render( reference, content )
    if not reference or not content then
        return ''
    end

    return mw.getCurrentFrame():callParserFunction {
        name = '#floatingui',
        args = {
            reference,
            content
        }
    }
end

return FloatingUI

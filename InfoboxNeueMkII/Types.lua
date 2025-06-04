require( 'strict' )

local p = {}


--- MediaWiki built-in types

--- @class mw.html @Built-in Lua type for HtmlBuilder in MediaWiki.
--- @field create function @Creates a new HTML element.
--- @field node function @Adds a node to the HTML element.
--- @field wikitext function @Adds wikitext to the HTML element.
--- @field tag function @Creates a new HTML element.
--- @field attr function @Sets the attributes of the HTML element.
--- @field css function @Sets the CSS properties of the HTML element.
--- @field done function @Finishes the HTML element.


--- Schema definitions for InfoboxNeueMkII components.

--- @class DataSchemaFieldDefinition @Represents the definition of a single field within a schema.
--- @field type string The expected Lua type (e.g., "string", "number", "table", "boolean").
--- @field required boolean|nil Whether the field is mandatory. Defaults to effectively false if nil.
--- @field default any|nil A default value to use if the field is not present in rawData and not required.

--- @alias DataSchemaDefinition table<string, DataSchemaFieldDefinition> @Represents a schema for validating data, mapping field names to their definitions.


--- Component data types

--- @class SectionComponentData @Represents the structure of a validated infobox section for SectionComponent.
--- @field label string|nil The label text for the section. Optional.
--- @field columns number|nil The number of columns in the section. Optional.
--- @field content string|nil The HTML content of the section. Optional.
--- @field items table<ItemComponentData>|nil The items in the section. Optional.
--- @field sections table<SectionComponentData>|nil The sections in the section. Optional.
--- @field class string|nil An additional HTML class for the section's container. Optional.

--- @type DataSchemaDefinition @The schema for SectionComponent data.
p.SectionComponentDataSchema = {
    label = { type = "string", required = false, default = nil },
    columns = { type = "number", required = false, default = 1 },
    content = { type = "string", required = false, default = nil },
    items = { type = "table", required = false, default = nil },
    sections = { type = "table", required = false, default = nil },
    class = { type = "string", required = false, default = nil }
}

--- @class ItemComponentData @Represents the structure of a validated infobox item for ItemComponent.
--- @field content string The HTML content of the item.
--- @field label string|nil The label text for the item. Optional.
--- @field class string|nil An additional HTML class for the item's container. Optional.

--- @type DataSchemaDefinition @The schema for ItemComponent data.
p.ItemComponentDataSchema = {
    content = { type = "string", required = true },
    label   = { type = "string", required = false, default = nil },
    class   = { type = "string", required = false, default = nil }
}

return p

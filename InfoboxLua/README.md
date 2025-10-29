# Module:InfoboxLua

An infobox system that uses Lua tables for data-driven rendering. Features collapsible sections, tabbed content, and flexible multi-column layouts. Built as the successor to [Module:InfoboxNeue](https://github.com/The-Star-Citizen-Wikis/SharedModules/tree/master/InfoboxNeue) with improved modularity and maintainability.

## Requirements

- [Extension:Details](https://www.mediawiki.org/wiki/Extension:Details)
- [Extension:TabberNeue](https://www.mediawiki.org/wiki/Extension:TabberNeue)
- [Module:Details](https://github.com/The-Star-Citizen-Wikis/SharedModules/tree/master/Details)

## Installation

1. Copy the entire `InfoboxLua` directory to your wiki's `Module:` namespace
2. Create the following pages:
   - `Module:InfoboxLua`
   - `Module:InfoboxLua/styles.css`
   - `Module:InfoboxLua/Types`
   - `Module:InfoboxLua/Util`
   - `Module:InfoboxLua/Components/Header`
   - `Module:InfoboxLua/Components/Section`
   - `Module:InfoboxLua/Components/Item`
   - `Module:InfoboxLua/Components/Collapsible`
3. Ensure all dependencies are installed

## Usage

### Basic Example

```lua
function p.main( frame )
    local infobox = require( 'Module:InfoboxLua' )
    local args = require( 'Module:Arguments' ).getArgs( frame )
    
    local data = {
        title = args.title,
        subtitle = args.subtitle,
        image = args.image,
        sections = {
            -- Build sections from template args
        }
    }
    
    return infobox.render( data )
end
```

## Data Structure

### Infobox Data

```lua
{
    title = string,              -- Required: Main title
    subtitle = string,           -- Optional: Subtitle text
    image = string|table,        -- Optional: Single image (src or ImageData)
    images = table,              -- Optional: Multiple images (array of ImageData)
    summary = string,            -- Optional: Collapsible summary text
    class = string,              -- Optional: Additional CSS class
    css = table,                 -- Optional: CSS properties {property = value}
    sections = table             -- Optional: Array of SectionData
}
```

### Section Data

```lua
{
    label = string,              -- Optional: Section label
    content = string,            -- Optional: Wikitext content
    columns = number,            -- Optional: Number of columns for items (default: 1)
    items = table,               -- Optional: Array of ItemData
    sections = table,            -- Optional: Nested sections (creates tabs)
    collapsible = boolean,       -- Optional: Make section collapsible
    collapsed = boolean,         -- Optional: Start collapsed (requires collapsible = true)
    class = string               -- Optional: Additional CSS class
}
```

### Item Data

```lua
{
    label = string,              -- Optional: Item label
    content = string,            -- Required: Item content (wikitext)
    class = string               -- Optional: Additional CSS class
}
```

### Image Data

```lua
{
    src = string,                -- Required: Image filename
    overlay = string,            -- Optional: Overlay text on image
    label = string,              -- Optional: Tab label (for multiple images)
    size = number,               -- Optional: Image size in pixels (default: 400)
    class = string               -- Optional: Additional CSS class
}
```

## Components

### Header Component
Displays the title, subtitle, and image(s) at the top of the infobox. Supports single images or tabbed multiple images.

### Section Component
Flexible container for content, items, or nested subsections. Supports collapsible behavior and multi-column layouts.

### Item Component
Simple label-content pair for displaying data. Used within sections.

### Collapsible Component
Generic collapsible functionality with collapse icon and content wrapper. Used by sections and the main infobox content.

## Architecture

```
InfoboxLua/
├── InfoboxLua.lua           # Main entry point
├── styles.css               # Component styles
├── Types.lua                # Type definitions and schemas
├── Util.lua                 # Validation and helper functions
└── Components/
    ├── Header.lua           # Header component
    ├── Section.lua          # Section component
    ├── Item.lua             # Item component
    └── Collapsible.lua      # Collapsible component
```

## Advanced Features

### Nested Sections with Tabs
Sections can contain nested sections, which automatically render as tabs:

```lua
{
    label = 'Cost',
    sections = {
        { label = 'Universe', items = {...} },
        { label = 'Pledge', items = {...} }
    }
}
```

### Collapsible Sections
Any section can be made collapsible:

```lua
{
    label = 'Specifications',
    collapsible = true,
    collapsed = false,  -- Start open
    items = {...}
}
```

### Multi-column Layouts
Items within a section can span multiple columns:

```lua
{
    label = 'Capacity',
    columns = 3,
    items = {
        { label = 'Crew', content = '1' },
        { label = 'Cargo', content = '0 SCU' },
        { label = 'Stowage', content = '1,300 KµSCU' }
    }
}
```

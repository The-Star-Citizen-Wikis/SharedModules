# Module:VehicleHardpoint

This module saves and displays the hardpoints found on a vehicle.

## Requirements
- Semantic MediaWiki
- Extension:Apiunto
- Extension:JsonConfig
- Extension:Tabber
- Module:Arguments
- Module:Common (spairs, formatNum)
- Module:Hatnote
- Module:Tabber
- Module:TNT

## Installation
1. Create `Module:VehicleHardpoint/data.json` with the content found in `data.json` on your wiki 
2. Create `Module:VehicleHardpoint/styles.css` with the content found in `styles.css` on your wiki 
3. Create `Module:VehicleHardpoint/i18n.json` with the content found in `i18n.json` on your wiki
4. Create `Module:VehicleHardpoint`
5. Upload all icons from the `SharedIcons` repository 

## Configuration
All configuration of this module is handled in `data.json`.

### `smw_multilingual_text`
If this flag is set to true, a language suffix is added to the data that is saved to SMW.

### `module_lang`
Manually select the language from the `.tab` page. Also overrides the language suffix that is added to SMW (if active).  
If left empty, the language is guessed based on the content language.

### `icon_prefix`
This prefix is used to generate the icon filenames. The default is `Hardpoints icon` which generates filenames like:   
`Hardpoints icon ICON.svg`

### `icon_name_lowercase`
Set this to false to not lowercase the icon names in the generated file links.

### `template_styles_page`
Link to the hardpoint style sheet, default is: `Module:VehicleHardpoint/styles.css`

### `name_fixes`
A list of item names that are ambiguous. Example:
```
{
  "Beacon": "Beacon (Quantum drive)"
}
```

This maps the item 'Beacon' to the wiki page 'Beacon (Quantum drive)'

### `matches`
This list sorts the hardpoints into pre-defined groups and types.  
The key is matched against the item type, if no match is found for an item, the entries from each `matches` list are checked as regex against the hardpoint name.  
The first match is then used.

### `hardpoint_type_fixes`
List of hardpoint names that should be checked against all matchers to retrieve the correct item type.  
If an item type is found in this list its hardpoint name is run against all `matches` until a match is found.

### `missing_icons`
List of item types that currently have no icon.

### `class_groupings`
This list defines the groups and content listed in the tabber output.  
The first entry of each array is the translation key used in `VehicleHardpoint.tab`.  
The second entry is the list of hardpoint classes listed in the tabber tab. 

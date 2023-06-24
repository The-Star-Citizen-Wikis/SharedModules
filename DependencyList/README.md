# Module:DependencyList

This module generates a list of dependency used by template and module documentation.

## Requirements
- [Semantic MediaWiki](https://www.mediawiki.org/wiki/Extension:Semantic_MediaWiki)
- [Semantic Extra Special Properties](https://github.com/SemanticMediaWiki/SemanticExtraSpecialProperties)
- Modules: Array, Yesno, Paramtest, User error, Hatnote, Hatnote list, Translate

## Installation
1. Create `Module:DependencyList`
2. Upload all icons from the `SharedIcons` repository

Change the message `MediaWiki:scribunto-doc-page-name` to `Module:$1/doc`.

## Configuration
All configuration of this module is handled in `config.json`.

## SMW
When using SMW, [Extension:SemanticExtraSpecialProperties](https://github.com/SemanticMediaWiki/SemanticExtraSpecialProperties) must be installed.

A special `Links to` Attribute is generated using the code below (placed in LocalSettings.php or somewhere there like).

The property should be populated on page edit, or can be manually triggered by the `rebuildData.php` SMW maintenance script.
```php
$sespgLocalDefinitions['_LINKSTO'] = [
    'id'    => '_LINKSTO',
    'type'  => '_wpg',
    'alias' => 'sesp-property-links-to',
    'desc' => 'sesp-property-links-to-desc',
    'label' => 'Links to',
    'callback'  => static function(\SESP\AppFactory $appFactory, \SMW\DIProperty $property, \SMW\SemanticData $semanticData ) {
        $page = $semanticData->getSubject()->getTitle();

        if ( $page === null ) {
            return;
        }

        /** @var \Wikimedia\Rdbms\DBConnRef $con */
        $con = $appFactory->getConnection();

        $where = sprintf(
            'pl.pl_from = %s AND pl.pl_title != %s',
            $page->getArticleID(),
            $con->addQuotes( $page->getDBkey() )
        );

        $res = $con->select(
            [ 'pl' => 'pagelinks', 'page' ],
            [ 'sel_title' => 'pl.pl_title', 'sel_ns' => 'pl.pl_namespace' ],
            [ $where ],
            __METHOD__,
            [ 'DISTINCT' ],
            [ 'page' => [ 'JOIN', 'page_id=pl_from' ] ]
        );

        foreach( $res as $row ) {
            $title = Title::newFromText( $row->sel_title, $row->sel_ns );
            if ( $title !== null && $title->exists() ) {
                $semanticData->addPropertyObjectValue( $property,\SMW\DIWikiPage::newFromTitle( $title ) );
            }
        }
    }
];

$sespgEnabledPropertyList[] = '_LINKSTO';
```

Enable Semantic Data on the Module and Template namespaces:
```php
$smwgNamespacesWithSemanticLinks[NS_TEMPLATE] = true;
$smwgNamespacesWithSemanticLinks[828] = true;
```
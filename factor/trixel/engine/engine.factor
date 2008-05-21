USING: accessors combinators destructors kernel namespaces
trixel.core trixel.resource-cache ;
IN: trixel.engine

TUPLE: trixel-engine trixel brick-cache sprite-cache ;

SYMBOL: +engine+

: engine ( -- engine ) +engine+ get-global ; inline

M: trixel-engine dispose ( engine -- )
    {
        [ sprite-cache>> dispose ]
        [ brick-cache>> dispose ]
        [ trixel>> [ trixel_finish ] when* ]
    } cleave ;

: find-brick ( name -- brick )
    engine brick-cache>> swap find-resource ;
: find-sprite ( name -- sprite )
    engine sprite-cache>> swap find-resource ;
USING: accessors alarms calendar combinators continuations debugger destructors io kernel
multi-methods namespaces prettyprint qualified trixel.core trixel.resource-cache
ui.gadgets ;
QUALIFIED: syntax
IN: trixel.engine

TUPLE: trixel-engine
    trixel
    brick-cache sprite-cache
    root gadget log-stream tick ;

SYMBOL: +engine+

GENERIC: init-root ( param root -- root )
GENERIC: draw ( thing -- )
GENERIC: gesture ( gesture root -- )
GENERIC: tick ( root -- )

METHOD: gesture { object object }
    2drop ;
METHOD: tick { object }
    drop ;

! until multi-methods merge with core, make the core M: readily accessible
: (M): POSTPONE: syntax:M: ; parsing

: engine-frame-rate 1/30 seconds ; inline

: engine ( -- engine ) +engine+ get ; inline

: (log.) ( thing -- )
    "Exception:\n" write
    [ error. ]
    [ "\n" write . ] bi
    "\nCall stack:\n" write
    .c
    "\nData stack:\n" write
    .s
    "\nRetain stack:\n" write
    .r
    "\n---\n" write ;

: (log) ( thing -- )
    engine [ log-stream>> [ [ (log.) ] with-output-stream* ] [ drop ] if* ] [ (log.) ] if* ;

: (engine-tick) ( -- )
    [
        engine
        [ root>> tick ]
        [ gadget>> relayout-1 ] bi
    ] [ (log) ] recover ;

: start-engine ( -- )
    engine
    [ (engine-tick) ] engine-frame-rate every >>tick
    drop ;

: stop-engine ( -- )
    engine
    [ tick>> [ cancel-alarm ] when* ]
    [ f >>tick drop ] bi ;

syntax:M: trixel-engine dispose ( engine -- )
    stop-engine
    {
        [ sprite-cache>> dispose ]
        [ brick-cache>> dispose ]
        [ trixel>> [ trixel_finish ] when* ]
        [ root>> [ dispose ] when* ]
    } cleave ;

: find-brick ( name -- brick )
    engine brick-cache>> swap find-resource ;
: find-sprite ( name -- sprite )
    engine sprite-cache>> swap find-resource ;


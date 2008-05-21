USING: accessors combinators continuations kernel namespaces
trixel.core trixel.engine trixel.engine.init trixel.resource-cache trixel.resource-cache.mock ;
IN: trixel.engine.mock

: init-mock-engine ( -- )
    trixel-engine new
    f >>trixel
    mock-resource <resource-cache> >>brick-cache
    mock-resource <resource-cache> >>sprite-cache
    +engine+ set-global ;

: with-mock-engine ( quot -- )
    init-mock-engine
    [ finish-engine ] [ ] cleanup ;

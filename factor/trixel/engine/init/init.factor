USING: accessors combinators continuations destructors kernel namespaces
trixel.brick trixel.core trixel.engine trixel.resource-cache trixel.sprite ;
IN: trixel.engine.init

: init-engine ( -- )
    trixel-engine new
    trixel-init-glew trixel-state-init >>trixel
    brick <resource-cache> >>brick-cache
    sprite <resource-cache> >>sprite-cache
    +engine+ set-global ;

: finish-engine ( -- )
    engine dispose
    f +engine+ set-global ;

: with-engine ( quot -- )
    init-engine
    [ finish-engine ] [ ] cleanup ;


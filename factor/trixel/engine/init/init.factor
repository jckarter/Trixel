USING: accessors combinators continuations destructors kernel namespaces
sequences
trixel.brick trixel.core trixel.engine trixel.resource-cache trixel.sprite ;
IN: trixel.engine.init

: init-engine ( -- )
    trixel-engine new
    brick <resource-cache> >>brick-cache
    sprite <resource-cache> >>sprite-cache
    +engine+ set-global ;

: finish-engine ( -- )
    engine dispose
    f +engine+ set-global ;

: with-engine ( quot -- )
    init-engine
    [ finish-engine ] [ ] cleanup ;

: start-engine-display ( -- )
    engine
    { TRIXEL_SMOOTH_SHADING TRIXEL_LIGHTING } trixel-init >>trixel
    brick-cache>> loaded-resources [ prepare-brick drop ] each ;

: stop-engine-display ( -- )
    engine
    [ brick-cache>> loaded-resources [ unprepare-brick drop ] each ]
    [ trixel>> trixel_finish ]
    [ f >>trixel drop ]
    tri ;

USING: accessors destructors kernel multi-methods
trixel.engine trixel.sprite sequences namespaces trixel.viewer-base ;
IN: trixel.sprite-viewer

TUPLE: sprite-viewer < viewer-base
    sprite-cursor ;

METHOD: init-root { object sprite-viewer }
    swap
    [ first find-sprite <sprite-cursor> ]
    [ second start-cursor ] bi >>sprite-cursor
    init-viewer ;

METHOD: draw { sprite-viewer }
    [ set-viewer-matrices ]
    [ sprite-cursor>> cursor-frame draw ] bi ;

METHOD: tick { sprite-viewer }
    sprite-cursor>> advance-cursor drop ;

(M): sprite-viewer dispose
    drop ;


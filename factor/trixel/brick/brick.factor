USING: accessors destructors kernel multi-methods namespaces trixel.core trixel.core.lib
trixel.engine trixel.resource-cache ;
IN: trixel.brick

TUPLE: brick trixel-brick ;

: (path-to-brick) ( name -- path )
    "bricks" "brick" (path-to-resource) ;

: prepare-brick ( brick -- brick )
    engine trixel>> [ over trixel-brick>> swap trixel_prepare_brick ] when* ;

: unprepare-brick ( brick -- brick )
    [ trixel-brick>> trixel_unprepare_brick ] keep ;

(M): brick load-resource ( brick name -- brick )
    (path-to-brick) trixel-read-brick-from-filename
    >>trixel-brick
    prepare-brick ;

(M): brick dispose ( brick -- )
    trixel-brick>> trixel_free_brick ;

METHOD: draw { brick }
    trixel-brick>> trixel_draw_brick ;

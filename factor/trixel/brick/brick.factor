USING: accessors destructors kernel namespaces trixel.core trixel.core.lib
trixel.engine trixel.resource-cache ;
IN: trixel.brick

TUPLE: brick brick ;

: (path-to-brick) ( name -- path )
    "bricks" "brick" (path-to-resource) ;

: prepare-brick ( brick -- brick )
    [ engine trixel>> trixel_prepare_brick ] keep ;

M: brick load-resource ( brick name -- brick )
    (path-to-brick) trixel-read-brick-from-filename prepare-brick
    >>brick ;

M: brick dispose ( brick -- )
    trixel_free_brick ;
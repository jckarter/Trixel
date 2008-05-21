USING: accessors assocs destructors io.encodings.utf8 io.files json.reader kernel
math sequences trixel.engine trixel.resource-cache ;
IN: trixel.sprite

TUPLE: sprite-animation frame-rate frames ;
TUPLE: sprite animations ;

: (path-to-sprite) ( name -- path )
    "sprites" "sprite" (path-to-resource) ;

: (make-animation) ( frame-rate frame-names -- animation )
    [ find-brick ] map sprite-animation boa ;

: (make-animations) ( hash -- animations )
    "animations" swap at [
        [ first2 (make-animation) ] assoc-map
    ] [ "sprite has no animations key" throw ] if* ;

: (sprite-from-hash) ( sprite hash -- sprite )
    (make-animations) >>animations ;

M: sprite load-resource ( sprite name -- sprite )
    (path-to-resource) utf8 file-contents json>
    (sprite-from-hash) ;

: <sprite> ( hash -- sprite )
    sprite new
    swap (sprite-from-hash) ;

M: sprite dispose ( sprite -- )
    drop ;

TUPLE: sprite-cursor sprite animation frame-n frame-time ;

: <sprite-cursor> ( sprite -- cursor )
    sprite-cursor new
    swap >>sprite ;

: start-cursor ( sprite-cursor animation-name -- sprite-cursor )
    over sprite>> animations>> at [
        >>animation
        0 >>frame-n
        0 >>frame-time
    ] [ "sprite does not have animation" throw ] if* ;

: advance-cursor ( sprite-cursor -- sprite-cursor )
    [ 1+ ] change-frame-time
    dup [ frame-time>> ] [ animation>> frame-rate>> ] bi >= [
        0 >>frame-time
        [ 1+ ] change-frame-n
        dup [ frame-n>> ] [ animation>> frames>> length ] bi >= [
            0 >>frame-n
        ] when
    ] when ;

: cursor-frame ( sprite-cursor -- brick )
    [ frame-n>> ] [ animation>> frames>> ] bi nth ;

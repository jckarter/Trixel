USING: accessors assocs destructors io.encodings.utf8 io.files json.reader kernel
sequences sequences.deep trixel.engine trixel.resource-cache ;
IN: trixel.board

TUPLE: board bricks layers-count z-count x-count ;

: (path-to-board) ( name -- path )
    "boards" "board" (path-to-resource) ;

: (find-brick/f) ( name/f -- brick/f )
    XXX brick orientation??
    [ find-brick ] [ f ] if* ;    

: (verify-cubic-truth-of-layers) ( layers -- )
    {
        [ [ length ] map all-equal?
          [ "Layers don't have same number of rows" throw ] unless ]
        [ [ [ length ] map ] map all-equal?
          [ "Layer rows don't have same number of columns" throw ] unless ]
    } cleave

M: board load-resource ( sprite name -- sprite )
    (path-to-board) utf8 file-contents json>
    "layers" swap at {
        [ (verify-cubic-truth-of-layers) ]
        [ length >>layers-count ]
        [ first length >>z-count ]
        [ first first length >>x-count ]
        [ flatten [ (find-brick/f) ] map >>bricks ]
    } cleave ;

M: board dispose ( board -- ) drop ;

: 

: board-brick ( board {x,z,layer} -- brick )

USING: accessors arrays assocs combinators destructors io.encodings.utf8 io.files
json.reader kernel math math.vectors sequences sequences.deep
trixel.engine trixel.resource-cache ;
IN: trixel.board

TUPLE: board bricks layers-count z-count x-count ;

: (path-to-board) ( name -- path )
    "boards" "board" (path-to-resource) ;

: (find-brick/f) ( name/f -- brick/f )
    ! XXX brick orientation??
    [ find-brick ] [ f ] if* ;    

: (verify-cubic-truth-of-layers) ( layers -- )
    {
        [ [ length ] map all-equal?
          [ "Layers don't have same number of rows" throw ] unless ]
        [ [ [ length ] map ] map all-equal?
          [ "Layer rows don't have same number of columns" throw ] unless ]
    } cleave ;

: (flatten-board) ( layers -- flat-layers )
    concat concat ;

: (board-from-hash) ( board hash -- board )
    "layers" swap at {
        [ (verify-cubic-truth-of-layers) ]
        [ length >>layers-count ]
        [ first length >>z-count ]
        [ first first length >>x-count ]
        [ (flatten-board) [ (find-brick/f) ] map >>bricks ]
    } cleave ;

M: board load-resource ( board name -- board )
    (path-to-board) utf8 file-contents json>
    (board-from-hash) ;

: <board> ( hash -- board )
    board new
    swap (board-from-hash) ;

M: board dispose ( board -- ) drop ;

: (board-pitches) ( board -- {1,zpitch,layerpitch} )
    [ drop 1 ]
    [ x-count>> ]
    [ { x-count>> z-count>> } get-slots * ] tri 3array ;

: board-brick ( board {x,z,layer} -- brick )
    over (board-pitches) v* sum swap bricks>> nth ;
    

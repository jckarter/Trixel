USING: accessors destructors kernel multi-methods opengl.gl math
trixel.core trixel.engine sequences namespaces trixel.viewer-base ;
IN: trixel.grid-viewer

TUPLE: grid-viewer < viewer-base
    grid-bricks ;

: (grid-bricks) {
    { "WallCorner" "WallFront" "WallFront" "WallFront" "WallFront" "WallFront" "WallFront" "WallCorner" }
    { "WallFront"  "Earth"     "Earth"     "Earth"     "Earth"     "Earth"     "Earth"     "WallFront"  }
    { "WallFront"  "Earth"     "Blacktop"  "Blacktop"  "Blacktop"  "Blacktop"  "Earth"     "WallFront"  }
    { "WallFront"  "Earth"     "Blacktop"  "Blacktop"  "Blacktop"  "Blacktop"  "Earth"     "WallFront"  }
    { "WallFront"  "Earth"     "Blacktop"  "Blacktop"  "Blacktop"  "Blacktop"  "Earth"     "WallFront"  }
    { "WallFront"  "Earth"     "Blacktop"  "Blacktop"  "Blacktop"  "Blacktop"  "Earth"     "WallFront"  }
    { "WallFront"  "Earth"     "Earth"     "Earth"     "Earth"     "Earth"     "Earth"     "WallFront"  }
    { "WallCorner" "WallFront" "WallFront" "WallFront" "WallFront" "WallFront" "WallFront" "WallCorner" }
} ; inline

: (set-brick-neighbor-flags) ( brick -- brick )
    [
        trixel-brick>> [
            {
                TRIXEL_NEIGHBOR_POSX_FLAG TRIXEL_NEIGHBOR_POSZ_FLAG
                TRIXEL_NEIGHBOR_NEGX_FLAG TRIXEL_NEIGHBOR_NEGZ_FLAG
            } (flags) swap set-trixel_brick-neighbor_flags
        ] [ trixel_update_brick_textures ] bi
    ] keep ;

: make-grid-bricks ( -- bricks )
    (grid-bricks) [ [ find-brick (set-brick-neighbor-flags) ] map ] map ;

METHOD: init-root { object grid-viewer }
    nip make-grid-bricks >>grid-bricks
    init-viewer ;

METHOD: draw { grid-viewer }
    [ set-viewer-matrices ] [
        -56.0 0.0 -56.0 glTranslatef 
        grid-bricks>> [
            [
                draw
                16.0 0.0 0.0 glTranslatef
            ] each
            -16.0 8.0 * 0.0 16.0 glTranslatef
        ] each
    ] bi ;

(M): grid-viewer dispose
    drop ;


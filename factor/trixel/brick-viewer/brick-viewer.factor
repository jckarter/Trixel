USING: accessors destructors kernel math math.order math.vectors multi-methods
opengl.gl trixel.core trixel.engine ui.gadgets sequences namespaces ui.gestures 
combinators ;
IN: trixel.brick-viewer

TUPLE: brick-viewer brick yaw pitch distance ;

METHOD: init-root { object brick-viewer }
    swap find-brick >>brick
    0.0 >>yaw
    0.0 >>pitch
    30.0 >>distance
    engine trixel>>
    [ 0 TRIXEL_LIGHT_PARAM_POSITION { 64.0 32.0 64.0 1.0 } trixel-light-param ]
    [ 0 TRIXEL_LIGHT_PARAM_AMBIENT  {  0.2  0.2  0.2 1.0 } trixel-light-param ]
    [ 0 TRIXEL_LIGHT_PARAM_DIFFUSE  {  0.8  0.8  0.8 1.0 } trixel-light-param ]
    tri ;

<PRIVATE

: NEAR-PLANE 4.0 ; inline
: FAR-PLANE 1024.0 ; inline
: MOUSE-MOTION-SCALE 0.5 ; inline
: KEY-ROTATE-STEP 1.0 ; inline
: DISTANCE-STEP 2.0 ; inline

: (fov-ratio) ( -- fov ) engine gadget>> dim>> dup first2 min v/n ;

: -+ ( x -- -x x )
    dup neg swap ;

: (frustum) ( -- -x x -y y near far )
    (fov-ratio) NEAR-PLANE v*n first2 [ -+ ] bi@ NEAR-PLANE FAR-PLANE ;    

: (set-matrices) ( brick-viewer -- )
    GL_PROJECTION glMatrixMode
    glLoadIdentity
    (frustum) glFrustum
    GL_MODELVIEW glMatrixMode
    glLoadIdentity
    [ >r 0.0 0.0 r> distance>> neg glTranslatef ]
    [ pitch>> 1.0 0.0 0.0 glRotatef ]
    [ yaw>>   0.0 1.0 0.0 glRotatef ]
    tri ;

: (yaw) ( brick-viewer ∆yaw -- )
    swap [ + ] change-yaw drop ;
: (pitch) ( brick-viewer ∆pitch -- )
    swap [ + -90 max 90 min ] change-pitch drop ;
: (zoom) ( brick-viewer ∆distance -- )
    swap [ + 0 max ] change-distance drop ;

SYMBOL: +drag-loc+
: reset-drag-loc ( -- )
    { 0 0 } +drag-loc+ set-global ;
: rel-drag-loc ( -- loc )
    drag-loc
    [ +drag-loc+ get v- ]
    [ +drag-loc+ set-global ] bi ;

PRIVATE>

METHOD: draw { brick-viewer }
    [ (set-matrices) ]
    [ brick>> draw ] bi ;

METHOD: gesture { key-down brick-viewer }
    swap sym>> {
        { "LEFT"  [ KEY-ROTATE-STEP neg (yaw)   ] }
        { "RIGHT" [ KEY-ROTATE-STEP     (yaw)   ] }
        { "DOWN"  [ KEY-ROTATE-STEP neg (pitch) ] }
        { "UP"    [ KEY-ROTATE-STEP     (pitch) ] }
        { "="     [ DISTANCE-STEP   neg (zoom)  ] }
        { "-"     [ DISTANCE-STEP   neg (zoom)  ] }
        [ 2drop ]
    } case ;
METHOD: gesture { button-down brick-viewer }
    2drop reset-drag-loc ;
METHOD: gesture { drag brick-viewer }
    nip rel-drag-loc MOUSE-MOTION-SCALE v*n first2
    [ dupd (yaw) ] [ (pitch) ] bi* ;
METHOD: gesture { mouse-scroll brick-viewer }
    nip scroll-direction get second DISTANCE-STEP * (zoom) ;

(M): brick-viewer dispose
    drop ;


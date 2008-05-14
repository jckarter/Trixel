USING: opengl.demo-support opengl.gl trixel accessors kernel ui.gadgets ui.render
sequences ui math combinators ui.gestures alarms calendar ;
IN: brick-viewer

TUPLE: brick-viewer-gadget brick-paths trixel bricks brickn tick ;

: frame-rate 30.0 4.0 / ; inline

M: brick-viewer-gadget near-plane ( gadget -- z )
    drop 4.0 ;
M: brick-viewer-gadget far-plane ( gadget -- z )
    drop 1024.0 ;
M: brick-viewer-gadget distance-step ( gadget -- dz )
    drop 2.0 ;

: <brick-viewer-gadget> ( brick-path -- brick-viewer-gadget )
    0.0 0.0 40.0 <demo-gadget> {
        (>>brick-paths)
        set-delegate
    } brick-viewer-gadget construct
    0 >>brickn ;

: (update-shaders) ( trixel -- )
    {
        [ TRIXEL_SMOOTH_SHADING TRIXEL_LIGHTING bitor trixel-update-shaders ]
        [ 0 TRIXEL_LIGHT_PARAM_POSITION { 64.0 32.0 64.0 1.0 } trixel-light-param ]
        [ 0 TRIXEL_LIGHT_PARAM_AMBIENT  {  0.2  0.2  0.2 1.0 } trixel-light-param ]
        [ 0 TRIXEL_LIGHT_PARAM_DIFFUSE  {  0.8  0.8  0.8 1.0 } trixel-light-param ]
    } cleave ;

: (next-frame) ( gadget -- )
    [ bricks>> length ]
    [ [ 1+ swap mod ] change-brickn relayout-1 ] bi ;

M: brick-viewer-gadget graft* ( gadget -- )
    trixel-init-glew
    trixel-resources trixel-state-init
    dup (update-shaders) >>trixel
    dup { trixel>> brick-paths>> } get-slots [
        trixel-read-brick-from-filename
        [ swap trixel_prepare_brick ] keep
    ] with map >>bricks
    dup [ (next-frame) ] curry 1.0 frame-rate / seconds every >>tick
    drop ;

M: brick-viewer-gadget ungraft* ( gadget -- )
    [ bricks>> [ [ trixel_free_brick ] each ] when* ]
    [ trixel>> [ trixel_state_free ] when* ] 
    [ tick>> [ cancel-alarm ] when* ] tri ;
    
M: brick-viewer-gadget pref-dim* ( gadget -- dim )
    drop { 640 480 } ;
    
M: brick-viewer-gadget draw-gadget* ( gadget -- )
    GL_STENCIL_TEST glDisable
    GL_DEPTH_TEST glEnable
    0.2 0.2 0.2 1.0 glClearColor
    GL_COLOR_BUFFER_BIT GL_DEPTH_BUFFER_BIT bitor glClear
    [ demo-gadget-set-matrices ]
    [
        dup trixel>> [
            { brickn>> bricks>> } get-slots nth trixel_draw_brick
        ] with-trixel-draw
    ] bi
    glGetError drop ;

brick-viewer-gadget H{
    { T{ key-down f f "r" } [ trixel>> (update-shaders) ] }
} set-gestures

: brick-viewer-window ( path -- )
    [ <brick-viewer-gadget> "Brick Viewer" open-window ] with-ui ;

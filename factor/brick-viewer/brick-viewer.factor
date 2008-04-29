USING: opengl.demo-support opengl.gl trixel accessors kernel ui.gadgets ui.render
sequences ui math combinators ;
IN: brick-viewer

TUPLE: brick-viewer-gadget brick-path trixel brick ;

M: brick-viewer-gadget near-plane ( gadget -- z )
    drop 4.0 ;
M: brick-viewer-gadget far-plane ( gadget -- z )
    drop 1024.0 ;
M: brick-viewer-gadget distance-step ( gadget -- dz )
    drop 2.0 ;

: <brick-viewer-gadget> ( brick-path -- brick-viewer-gadget )
    0.0 0.0 40.0 <demo-gadget> {
        (>>brick-path)
        set-delegate
    } brick-viewer-gadget construct ;

M: brick-viewer-gadget graft* ( gadget -- )
    [ trixel_init_glew drop ] with-trixel-error
    "/Users/joe/Documents/Code/Trixel" [ trixel_state_init ] with-trixel-error
    dup {
        [ { "TRIXEL_SMOOTH_SHADING" "TRIXEL_LIGHTING" } trixel-update-shaders ]
        [ 0 TRIXEL_LIGHT_PARAM_POSITION { 64.0 32.0 64.0 1.0 } trixel-light-param ]
        [ 0 TRIXEL_LIGHT_PARAM_AMBIENT  {  0.2  0.2  0.2 1.0 } trixel-light-param ]
        [ 0 TRIXEL_LIGHT_PARAM_DIFFUSE  {  0.8  0.8  0.8 1.0 } trixel-light-param ]
    } cleave
    >>trixel
    dup brick-path>> t [ trixel_read_brick_from_filename ]
    with-trixel-error >>brick
    drop ;

M: brick-viewer-gadget ungraft* ( gadget -- )
    [ brick>> [ trixel_free_brick ] when* ]
    [ trixel>> [ trixel_state_free ] when* ] bi ;
    
M: brick-viewer-gadget pref-dim* ( gadget -- dim )
    drop { 640 480 } ;
    
: (reset-opengl-state) ( -- )
    0 glUseProgram
    GL_TEXTURE0 glActiveTexture ;

M: brick-viewer-gadget draw-gadget* ( gadget -- )
    GL_STENCIL_TEST glDisable
    GL_DEPTH_TEST glEnable
    0.2 0.2 0.2 1.0 glClearColor
    GL_COLOR_BUFFER_BIT GL_DEPTH_BUFFER_BIT bitor glClear
    [ demo-gadget-set-matrices ]
    [
        { trixel>> brick>> } get-slots trixel_draw_brick
    ] bi
    (reset-opengl-state)
    glGetError drop ;

: brick-viewer-window ( path -- )
    [ [ <brick-viewer-gadget> ] keep open-window ] with-ui ;

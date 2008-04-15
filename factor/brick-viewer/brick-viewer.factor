USING: opengl.demo-support opengl.gl trixel ;
IN: brick-viewer

TUPLE: brick-viewer-gadget brick-path trixel brick ;

: <brick-viewer-gadget> ( brick-path -- brick-viewer-gadget )
    0.0 0.0 128.0 <demo-gadget> {
        (>>brick-path)
        set-delegate
    } brick-viewer-gadget construct ;

M: brick-viewer-gadget graft* ( gadget -- )
    [ trixel_init_glew ] with-trixel-error
    "." [ trixel_state_init ] with-trixel-error
    dup { "TRIXEL_LIGHTING" "TRIXEL_SMOOTH_SHADING" } trixel-update-shaders 
    >>trixel
    dup >>brick-path t [ trixel_read_brick_from_filename ]
    with-trixel-error >>brick
    drop ;

M: brick-viewer-gadget ungraft* ( gadget -- )
    { trixel>> brick>> } get-slots
    trixel_free_brick
    trixel_state_free ;
    
M: brick-viewer-gadget pref-dim* ( gadget -- dim )
    drop { 640 480 } ;
    
: (reset-opengl-state) ( -- )
    0 glUseProgram
    GL_TEXTURE0 glActiveTexture ;

M: brick-viewer-gadget draw-gadget* ( gadget -- )
    [ { trixel>> dim>> } get-slots first2 trixel_reshape ]
    [
        GL_MODELVIEW glMatrixMode glLoadIdentity
        { trixel>> brick>> } get-slots trixel_draw_brick
    ] bi
    reset-opengl-state ;

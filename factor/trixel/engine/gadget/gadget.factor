USING: accessors continuations kernel math opengl.gl trixel.engine
trixel.engine.init trixel.core ui ui.gadgets ui.gadgets.panes
ui.gadgets.scrollers ui.gestures ui.render ;
IN: trixel.engine.gadget

TUPLE: engine-gadget root-class param ;

: <engine-gadget> ( root-class param -- gadget )
    engine-gadget construct-gadget
    swap >>param
    swap >>root-class ;

: (open-log-window) ( -- )
    engine
    <scrolling-pane> [ <scroller> "engine log" open-window ] keep
    <pane-stream> >>log-stream
    drop ;

M: engine-gadget graft* ( gadget -- )
    init-engine
    start-engine-display
    start-engine
    (open-log-window)
    engine
    over >>gadget
    swap { param>> root-class>> } get-slots new init-root >>root
    drop ;

M: engine-gadget ungraft* ( gadget -- )
    drop
    stop-engine
    stop-engine-display
    finish-engine ;

: (set-up-opengl-state) ( -- )
    GL_STENCIL_TEST glDisable
    GL_DEPTH_TEST glEnable
    GL_COLOR_BUFFER_BIT GL_DEPTH_BUFFER_BIT bitor glClear ;

M: engine-gadget draw-gadget* ( gadget -- )
    drop
    (set-up-opengl-state)
    engine
    [ dup root>> [ draw ] when* ]
    [ (log) ] recover
    trixel>> trixel_finish_draw ;

M: engine-gadget handle-gesture* ( gadget gesture delegate -- pass? )
    drop nip
    [ engine root>> [ gesture ] [ drop ] if* ]
    [ drop (log) ] recover
    f ;

M: engine-gadget pref-dim* ( gadget -- dim )
    drop { 1024 768 } ;

: engine-window ( root-class param -- )
    [ <engine-gadget> "trixel" open-window ] with-ui ;

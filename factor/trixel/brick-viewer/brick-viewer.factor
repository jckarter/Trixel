USING: accessors destructors kernel multi-methods
trixel.engine sequences namespaces trixel.viewer-base ;
IN: trixel.brick-viewer

TUPLE: brick-viewer < viewer-base
    brick ;

METHOD: init-root { object brick-viewer }
    swap find-brick >>brick
    init-viewer ;

METHOD: draw { brick-viewer }
    [ set-viewer-matrices ]
    [ brick>> draw ] bi ;

(M): brick-viewer dispose
    drop ;


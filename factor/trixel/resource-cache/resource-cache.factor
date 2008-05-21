USING: accessors assocs destructors hashtables kernel namespaces sequences trixel.core.lib ;
IN: trixel.resource-cache

GENERIC# load-resource 1 ( resource filename -- resource )

: (path-to-resource) ( name directory ext -- path )
    swap
    [ trixel-resource-path % "/" % % "/" % % "." % % ] "" make ;

TUPLE: resource-cache resource-class loaded-resources ;

: <resource-cache> ( resource-class -- resource-cache )
    resource-cache new 
    swap >>resource-class
    1000 <hashtable> >>loaded-resources ;

: (find-resource-in-cache) ( resource-cache name -- resource/f )
    swap loaded-resources>> at ;

: (load-resource-into-cache) ( resource-cache name -- resource )
    swap
    [ resource-class>> new swap load-resource dup ]
    [ loaded-resources>> set-at ] 2bi ;

: find-resource ( resource-cache name -- resource )
    2dup (find-resource-in-cache)
    [ 2nip ]
    [ (load-resource-into-cache) ] if* ;

: unload-resource ( resource-cache name -- )
    swap loaded-resources>>
    [ at dispose ]
    [ delete-at ] 2bi ;

: loaded-resource-names ( resource-cache -- names )
    loaded-resources>> keys ;

M: resource-cache dispose ( resource-cache -- )
    dup loaded-resource-names [ unload-resource ] with each ;
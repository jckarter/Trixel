USING: accessors assocs continuations destructors hashtables kernel namespaces
sequences trixel.core.lib ;
IN: trixel.resource-cache

GENERIC# load-resource 1 ( resource filename -- resource )

TUPLE: find-resource-error resource-class name error ;
C: <find-resource-error> find-resource-error

: (path-to-resource) ( name directory ext -- path )
    -rot
    [ trixel-resource-path % "/media/" % % "/" % % "." % % ] "" make ;

TUPLE: resource-cache resource-class loaded-resources ;

: <resource-cache> ( resource-class -- resource-cache )
    resource-cache new 
    swap >>resource-class
    1000 <hashtable> >>loaded-resources ;

: (find-resource-in-cache) ( resource-cache name -- resource/f )
    swap loaded-resources>> at ;

: new-resource ( class name -- resource )
    [ [ new ] dip load-resource ]
    [ <find-resource-error> throw ] recover ;

: (load-resource-into-cache) ( resource-cache name -- resource )
    [ [ resource-class>> ] dip new-resource dup ]
    [ swap loaded-resources>> set-at ] 2bi ;

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
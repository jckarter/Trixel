USING: accessors assocs continuations hashtables kernel sequences ;
IN: trixel.resource-cache

TUPLE: resource-not-found-exception kind name ;
C: <resource-not-found-exception> resource-not-found-exception

TUPLE: resource-cache load-quot loaded-resources ;

: <resource-cache> ( load-quot -- resource-cache )
    resource-cache new 
    swap >>load-quot 
    1000 <hashtable> >>loaded-resources ;

: (find-resource-in-cache) ( resource-cache name -- resource/f )
    swap loaded-resources>> at ;

: (load-resource-into-cache) ( resource-cache name -- resource )
    swap
    [ load-quot>> call dup ]
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
USING: combinators continuations kernel sorting tools.test trixel.resource-cache ;
IN: trixel.resource-cache.tests

TUPLE: fake-resource name ;
C: <fake-resource> fake-resource

: load-fake-resource ( name -- resource )
    <fake-resource> ;
    
M: fake-resource dispose ( resource -- )
    drop ;

{
    t
    { "bar" "bas" "foo" }
    { "bar" "bas" }
    { }
} [
    [ load-fake-resource ] <resource-cache>
    {
        [ "foo" find-resource ]
        [ "foo" find-resource eq? ]
        [ "bar" find-resource drop ]
        [ "bas" find-resource drop ]
        [ loaded-resource-names natural-sort ]
        [ "foo" unload-resource ]
        [ loaded-resource-names natural-sort ]
        [ dispose ]
        [ loaded-resource-names natural-sort ]
    } cleave
] unit-test
USING: accessors combinators destructors kernel sorting tools.test
trixel.resource-cache trixel.resource-cache.mock ;
IN: trixel.resource-cache.tests

{
    t
    { "bar" "bas" "foo" }
    { "bar" "bas" }
    { }
} [
    mock-resource <resource-cache>
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
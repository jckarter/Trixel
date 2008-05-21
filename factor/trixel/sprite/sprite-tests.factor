USING: accessors kernel math tools.test trixel.engine.mock trixel.sprite ;
IN: trixel.sprite.tests

: current-frame ( cursor -- name cursor )
    [ cursor-frame name>> ] keep ;

[
    {
        "still" "still"
        "a" "b" "a"
        "c" "c" "c" "d" "d" "d" "e" "e" "e" "c"
    } [
        H{ { "animations" H{
            { "still" { 0 { "still" } } }
            { "ab" { 1 { "a" "b" } } }
            { "cde" { 3 { "c" "d" "e" } } }
        } } } <sprite> <sprite-cursor>
        
        "still" start-cursor current-frame
        advance-cursor current-frame
        
        "ab" start-cursor current-frame
        2 [ advance-cursor current-frame ] times
        
        "cde" start-cursor current-frame
        9 [ advance-cursor current-frame ] times
        
        drop
    ] unit-test
] with-mock-engine
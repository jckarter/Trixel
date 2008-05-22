USING: accessors combinators kernel math tools.test trixel.engine.mock trixel.board ;
IN: trixel.board.tests

[
    {
        2 3 2
        "a" "b" "d" "g"
        f
    } [
        H{ { "layers" {
            {
                { "a" "b" "c" }
                { "d" "e" f   }
            } {
                { "g" "h" "i" }
                { "j" "k" "l" }
            }
        } } } <board> {
            [ layers-count>> ]
            [ x-count>> ]
            [ z-count>> ]
            [ { 0 0 0 } board-brick name>> ]
            [ { 1 0 0 } board-brick name>> ]
            [ { 0 1 0 } board-brick name>> ]
            [ { 0 0 1 } board-brick name>> ]
            [ { 2 1 0 } board-brick ]
        } cleave
    ] unit-test
] with-mock-engine
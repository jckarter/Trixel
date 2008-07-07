USING: alien.c-types combinators kernel trixel.engine trixel.core ;
IN: trixel.superbrick

TUPLE: superbrick bricks brick-dim dim (pitches) ;

: (superbrick-from-hash) ( superbrick hash -- superbrick )
    {
        [ "brick-dim" swap at >>brick-dim ]
        [ "dim" swap at >>dim ]
        [ "bricks" swap at (find-bricks) >>bricks ]
    } cleave (calculate-pitches) ;

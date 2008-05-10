USING: alien combinators kernel system io.files ;
IN: trixel

: trixel-resources "/Users/joe/Documents/Code/Trixel" ; inline

"trixel" {
    { [ os macosx? ] [ trixel-resources "lib/libtrixel.dylib" append-path "cdecl" add-library ] }
    { [ t ] [ "FIXME: other platforms" throw ] }
} cond


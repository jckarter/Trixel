USING: alien combinators kernel system io.files ;
IN: trixel.core.lib

: trixel-resource-path "work/trixel/resource" resource-path ; inline

"trixel" {
    { [ os macosx? ] [ trixel-resource-path "libtrixel.dylib" append-path "cdecl" add-library ] }
    { [ t ] [ "FIXME: other platforms" throw ] }
} cond


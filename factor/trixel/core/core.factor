USING: alien alien.syntax macros kernel opengl.gl system combinators sequences
libc alien.c-types alien.strings math io.encodings.utf8 trixel.core.lib
continuations words quotations ;
IN: trixel.core

LIBRARY: trixel

C-STRUCT: point3
    { "float" "x" }
    { "float" "y" }
    { "float" "z" }
    ;

C-STRUCT: int3
    { "int" "x" }
    { "int" "y" }
    { "int" "z" }
    ;

TYPEDEF: void* trixel_state

C-STRUCT: voxmap
    { "int3"     "dimensions" }
    { "uchar[1]" "data" }
    ;

C-STRUCT: trixel_brick
    { "point3"       "dimensions" }
    { "point3"       "dimensions_inv" }
    { "point3"       "normal_translate" }
    { "point3"       "normal_scale" }
    { "GLuint"       "palette_texture" }
    { "GLuint"       "voxmap_texture" }
    { "GLuint"       "normal_texture" }
    { "GLuint"       "vertex_buffer" }
    { "GLuint"       "num_vertices" }
    { "int"          "neighbor_flags" }
    { "trixel_state" "t" }
    { "uchar[1024]"  "palette_data" }
    { "voxmap"       "v" }
    ;

: TRIXEL_SAVE_COORDINATES 1 ; inline
: TRIXEL_SURFACE_ONLY     2 ; inline
: TRIXEL_LIGHTING         4 ; inline
: TRIXEL_SMOOTH_SHADING   8 ; inline

: TRIXEL_LIGHT_PARAM_POSITION 0 ; inline
: TRIXEL_LIGHT_PARAM_AMBIENT  1 ; inline
: TRIXEL_LIGHT_PARAM_DIFFUSE  2 ; inline

: TRIXEL_NEIGHBOR_POSX 0 ; inline
: TRIXEL_NEIGHBOR_POSY 1 ; inline
: TRIXEL_NEIGHBOR_POSZ 2 ; inline
: TRIXEL_NEIGHBOR_NEGX 3 ; inline
: TRIXEL_NEIGHBOR_NEGY 4 ; inline
: TRIXEL_NEIGHBOR_NEGZ 5 ; inline

: TRIXEL_NEIGHBOR_POSX_FLAG  1 ; inline
: TRIXEL_NEIGHBOR_POSY_FLAG  2 ; inline
: TRIXEL_NEIGHBOR_POSZ_FLAG  4 ; inline
: TRIXEL_NEIGHBOR_NEGX_FLAG  8 ; inline
: TRIXEL_NEIGHBOR_NEGY_FLAG 16 ; inline
: TRIXEL_NEIGHBOR_NEGZ_FLAG 32 ; inline

FUNCTION: trixel_state trixel_state_init ( char* resource_path, char** out_error_message ) ;
FUNCTION: bool trixel_init_glew ( char** out_error_message ) ;
FUNCTION: trixel_state trixel_init_opengl ( char* resource_path, int viewport_width, int viewport_height, int shader_flags, char** out_error_message ) ;
FUNCTION: void trixel_reshape ( trixel_state t, int viewport_width, int viewport_height ) ;
FUNCTION: int trixel_update_shaders ( trixel_state t, int shader_flags, char** out_error_message ) ;

FUNCTION: void trixel_finish ( trixel_state t ) ;

FUNCTION: trixel_brick* trixel_read_brick ( void* data, size_t data_length, char** out_error_message ) ;
FUNCTION: trixel_brick* trixel_make_solid_brick ( int w, int h, int d, char** out_error_message ) ;
FUNCTION: trixel_brick* trixel_make_empty_brick ( int w, int h, int d, char** out_error_message ) ;
FUNCTION: trixel_brick* trixel_copy_brick ( trixel_brick* brick, char** out_error_message ) ;
FUNCTION: void trixel_free_brick ( trixel_brick* brick ) ;
FUNCTION: void* trixel_write_brick ( trixel_brick* brick, size_t* out_data_length ) ;

FUNCTION: uint trixel_optimize_brick_palette ( trixel_brick* brick ) ;
FUNCTION: uchar* trixel_insert_brick_palette_color ( trixel_brick* brick, int color ) ;
FUNCTION: void trixel_remove_brick_palette_color ( trixel_brick* brick, int color ) ;

FUNCTION: void trixel_prepare_brick ( trixel_brick* brick, trixel_state t ) ;
FUNCTION: void trixel_unprepare_brick ( trixel_brick* brick ) ;
FUNCTION: bool trixel_is_brick_prepared ( trixel_brick* brick ) ;
FUNCTION: void trixel_update_brick_textures ( trixel_brick* brick ) ;

FUNCTION: void trixel_draw_from_brick ( trixel_brick* brick ) ;
FUNCTION: void trixel_draw_brick ( trixel_brick* brick ) ;
FUNCTION: void trixel_finish_draw ( trixel_state t ) ;

FUNCTION: char* trixel_resource_filename ( trixel_state t, char* filename ) ;

FUNCTION: char* contents_from_filename ( char* filename, size_t* out_length ) ;

FUNCTION: trixel_brick* trixel_read_brick_from_filename ( char* filename, char** out_error_message ) ;

FUNCTION: void trixel_light_param ( trixel_state t, GLuint light, int param, GLfloat* param_value ) ;

FUNCTION: void trixel_only_free_brick ( trixel_brick* brick ) ;
FUNCTION: void trixel_state_free ( trixel_state t ) ;

: with-trixel-error ( quot -- )
    f <void*> swap keep *void*
    [ utf8 alien>string throw ]
    when* ; inline

: with-trixel-draw ( t quot -- )
    [ dip ] [ trixel_finish_draw ] [ ] cleanup ; inline

: trixel-init-glew ( -- )
    [ trixel_init_glew drop ] with-trixel-error ;
: trixel-read-brick-from-filename ( filename -- brick )
    [ trixel_read_brick_from_filename ] with-trixel-error ;
: trixel-light-param ( t light param value -- )
    >c-float-array trixel_light_param ; inline
: trixel-state-init ( -- t )
    trixel-resource-path [ trixel_state_init ] with-trixel-error ;

MACRO: (flags) ( flag-words -- int )
    0 [ execute bitor ] reduce 1quotation ;

: trixel-update-shaders ( t flags -- )
    (flags) [ trixel_update_shaders drop ] with-trixel-error ;

: trixel-init ( flags -- t )
    trixel-init-glew trixel-state-init
    [ swap trixel-update-shaders ] keep ;

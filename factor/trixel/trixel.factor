USING: alien alien.syntax kernel opengl.gl ;
IN: trixel

<< "trixel" {
    { [ macosx? ] [ "libtrixel.dylib" "cdecl" add-library ] }
    { [ windows? ] [ "trixel.dll" "cdecl" add-library ] }
    { [ unix? ] [ "libtrixel.so" "cdecl" add-library ] }
    { [ t ] [ drop ] }
} cond >>

LIBRARY: trixel

C-STRUCT: point3
    { "float" "x" }
    { "float" "y" }
    { "float" "z" }
    ;

C-STRUCT: trixel_brick
    { "point3" "dimensions" }
    { "point3" "dimensions_inv" }
    { "point3" "normal_translate" }
    { "point3" "normal_scale" }
    { "uchar*" "palette_data" }
    { "uchar*" "voxmap_data" }
    { "GLuint" "palette_texture" }
    { "GLuint" "voxmap_texture" }
    { "GLuint" "normal_texture" }
    { "GLuint" "vertex_buffer" }
    ;

TYPEDEF: void* trixel_state

FUNCTION: trixel_state trixel_init_opengl ( char* resource_path, int viewport_width, int viewport_height, char** shader_flags, char** out_error_message ) ;
FUNCTION: void trixel_reshape ( trixel_state t, int viewport_width, int viewport_height ) ;
FUNCTION: int trixel_update_shaders ( trixel_state t, char** shader_flags, char** out_error_message ) ;

FUNCTION: void trixel_finish ( trixel_state t ) ;

FUNCTION: trixel_brick* trixel_read_brick ( void* data, size_t data_length, bool prepare, char** out_error_message ) ;
FUNCTION: trixel_brick* trixel_make_solid_brick ( int w, int h, int d, bool prepare, char** out_error_message ) ;
FUNCTION: trixel_brick* trixel_make_empty_brick ( int w, int h, int d, bool prepare, char** out_error_message ) ;
FUNCTION: trixel_brick* trixel_copy_brick ( trixel_brick* brick, bool prepare, char** out_error_message ) ;
FUNCTION: void trixel_free_brick ( trixel_brick* brick ) ;
FUNCTION: void* trixel_write_brick ( trixel_brick* brick, size_t* out_data_length ) ;

FUNCTION: uint trixel_optimize_brick_palette ( trixel_brick* brick ) ;
FUNCTION: uchar* trixel_insert_brick_palette_color ( trixel_brick* brick, int color ) ;
FUNCTION: void trixel_remove_brick_palette_color ( trixel_brick* brick, int color ) ;

FUNCTION: void trixel_prepare_brick ( trixel_brick* brick ) ;
FUNCTION: void trixel_unprepare_brick ( trixel_brick* brick ) ;
FUNCTION: bool trixel_is_brick_prepared ( trixel_brick* brick ) ;
FUNCTION: void trixel_update_brick_textures ( trixel_brick* brick ) ;

FUNCTION: void trixel_draw_from_brick ( trixel_state t, trixel_brick* brick ) ;
FUNCTION: void trixel_draw_brick ( trixel_state t, trixel_brick* brick ) ;

FUNCTION: char* trixel_resource_filename ( trixel_state t, char* filename ) ;

FUNCTION: char* contents_from_filename ( char* filename, size_t* out_length ) ;

FUNCTION: trixel_brick* trixel_read_brick_from_filename ( char* filename, bool prepare, char** out_error_message ) ;

FUNCTION: void trixel_light_param ( trixel_state t, GLuint light, char* param_name, GLfloat* param_value ) ;

FUNCTION: void trixel_only_free_brick ( trixel_brick* brick ) ;
FUNCTION: void trixel_only_free ( trixel_state t ) ;
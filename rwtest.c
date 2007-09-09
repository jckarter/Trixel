#include "trixel.h"
#include <stdio.h>
#include <errno.h>
#include <string.h>

int
main(int argc, char * argv[])
{
    char *error_message;
    
    if(argc < 2) {
        asprintf(&error_message, "Usage: %s foo.brick", argv[0]);
        goto error;
    }

    char * write_filename;
    asprintf(&write_filename, "%s.rewrite", argv[1]);

    trixel_brick * brick = trixel_read_brick_from_filename(argv[1], false, &error_message);
    if(!brick)
        goto error;
    
    size_t data_length;
    void * data = trixel_write_brick(brick, &data_length);
    
    FILE * out = fopen(write_filename, "wb");
    if(!out) {
        error_message = strdup(strerror(errno));
        goto error;
    }
    fwrite(data, data_length, 1, out);
    fclose(out);
    printf("Wrote %s\n", write_filename);
    
    return 0;
    
error:
    fprintf(stderr, "%s\n", error_message);
    return 1;
}
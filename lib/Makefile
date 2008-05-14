.PHONY: clean

CFLAGS += -std=c99 `sdl-config --cflags` -I/opt/local/include -g
LDFLAGS += -L/opt/local/lib `sdl-config --libs` -framework OpenGL -framework Cocoa -lglew

libtrixel.dylib: trixel.o glsl_sm4.o voxmap.o
	$(CC) -o $@ $^ $(CFLAGS) $(LDFLAGS) -dynamiclib

clean:
	rm -f libtrixel.dylib *.o

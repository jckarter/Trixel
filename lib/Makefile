.PHONY: clean

CFLAGS += -arch x86_64 -std=c99 `sdl-config --cflags` -I/opt/local/include -g
LDFLAGS += -L/opt/local/lib -framework OpenGL -framework Cocoa -lglew
SDL_LDFLAGS += `sdl-config --libs`

libtrixel.dylib: trixel.o glsl_sm4.o voxmap.o arbfvp.o
	$(CC) -o $@ $^ $(CFLAGS) $(LDFLAGS) -dynamiclib

clean:
	rm -f libtrixel.dylib *.o

voxtest: libtrixel.dylib voxtest.o
	$(CC) -o $@ $^ $(CFLAGS) $(SDL_LDFLAGS) $(LDFLAGS)

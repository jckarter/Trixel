CFLAGS += -std=c99 `sdl-config --cflags` -I/opt/local/include -g -O3
LDFLAGS += -L/opt/local/lib `sdl-config --libs` -framework OpenGL -framework Cocoa -lglew

voxtest: voxtest.c
	$(CC) -o $@ $^ $(CFLAGS) $(LDFLAGS)

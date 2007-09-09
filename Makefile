CFLAGS += -std=c99 `sdl-config --cflags` -I/opt/local/include -g
LDFLAGS += -L/opt/local/lib `sdl-config --libs` -framework OpenGL -framework Cocoa -lglew

voxtest: voxtest.o trixel.o
	$(CC) -o $@ $^ $(CFLAGS) $(LDFLAGS)

rwtest: rwtest.o trixel.o
	$(CC) -o $@ $^ $(CFLAGS) $(LDFLAGS)

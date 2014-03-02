
SOURCES=GDNSContext.m GDNSUtil.m
FRAMEWORKS:= -framework Foundation -framework CFNetwork
LIBRARIES:= -lobjc -lresolv
CFLAGS=$(EXTRA_CFLAGS) -Wall -Werror -g -v $(SOURCES)
LDFLAGS=-static $(EXTRA_LDFLAGS) $(LIBRARIES) $(FRAMEWORKS)
OUT=ios-getdns.a

all: $(SOURCES) $(OUT)

$(OUT): $(SOURCES)
	echo "done."

.m.o:
	echo "hi"
	$(CC) -c -Wall $< -o $@

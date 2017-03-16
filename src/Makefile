CC = `"$(R_HOME)/bin/R" CMD config CC`
CFLAGS = `"$(R_HOME)/bin/R" CMD config CFLAGS`

supervisor: supervisor.c
	$(CC) $(CFLAGS) supervisor.c -o supervisor

all: supervisor

clean:
	rm -rf supervisor supervisor.dSYM supervisor.exe

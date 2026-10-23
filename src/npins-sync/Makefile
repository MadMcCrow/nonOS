CC = cc
CFLAGS = -Wall -Wextra -Werror -Wfatal-errors
SRC = $(wildcard *.c)
HEADERS = $(wildcard *.h)
PROGRAM = npins-sync

$(PROGRAM): $(SRC) $(HEADERS)
	$(CC) $(CFLAGS) $(SRC) -o $(PROGRAM)

clean:
	rm -f $(PROGRAM)

.PHONY: clean

/**
 * This is the adaptation of a shell script, rewritten in C because C is actually more readable
 *
 */
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

// our includes
#include "./npins.h"
#include "./dir.h"


/** print usage string */
int usage(char** argv, bool uc_incompatible) {
    if (uc_incompatible)
    {
        fprintf(stderr, "Error: exactly one of -u or -c is required\n");
    }
    fprintf(stderr, "Usage: %s [-f] [-d directory] (-u url/branch | -c channel) \n", argv[0]);
    exit(1);
    return 1;
}

int main(int argc, char *argv[])
{
    int opt;
    int force = 0;

    const char *path = NULL;
    const char* value = NULL;
    char selected = '\0';

    while ((opt = getopt(argc, argv, "fd:u:c:")) != -1) {
        switch (opt) {
        case 'f':
            force=1;
            break;
        case 'd':
            path = optarg;
            break;
        case 'u':
        case 'c':
            if (selected != '\0') {
                return usage(argv, true);
            }
            selected = (char)opt;
            value = optarg;
            break;
        default:
            return usage(argv, false);
        }
    }

    if (selected == '\0') {
        return usage(argv, true);
    }

    // initialize if this directory is empty
    int dir_status = directory_status(path);
    if (dir_status == -1) {
        fprintf(stderr, "directory %s does not exist, we cannot run \n", path);
        return 1;
    }
    // or initialize it if empty
    else if (dir_status == 0)
    {
        npins_init(path, value, selected == 'c');
    }

    if (npins_update(path) != 0)
    {
        if (force == 1)
        {
            directory_clear(path);
            npins_init(path, value , selected == 'c');
        }
        else
        {
             fprintf(stderr, "npins update failed, check content of %s, or rerun with -f\n", path);
        }
    }

    return 0;
}

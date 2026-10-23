/** detect and manage directories  */
#ifndef DIR_H
#define DIR_H

#include <stdio.h>
#include <dirent.h>
#include <stdlib.h>
#include <string.h>
#include <dirent.h>
#include <unistd.h>
#include <sys/stat.h>
#include <limits.h>

#define _XOPEN_SOURCE 700

static inline int directory_status(const char *path)
{
    DIR *dir = opendir(path);
    if (dir == NULL)
        return -1;  // Error: cannot open directory

    struct dirent *entry;
    while ((entry = readdir(dir)) != NULL) {
        if (entry->d_name[0] != '.' ||
            (entry->d_name[1] != '\0' &&
             (entry->d_name[1] != '.' ||
              entry->d_name[2] != '\0'))) {
            closedir(dir);
            return 0;  // Not empty
        }
    }

    closedir(dir);
    return 1;  // Empty
}


static inline int directory_clear(const char *path)
{
    DIR *dir = opendir(path);
    if (dir == NULL) {
        perror(path);
        return -1;
    }

    struct dirent *entry;
    int result = 0;

    while ((entry = readdir(dir)) != NULL) {
        if (strcmp(entry->d_name, ".") == 0 ||
            strcmp(entry->d_name, "..") == 0) {
            continue;
        }

        char fullpath[PATH_MAX];

        int n = snprintf(fullpath, sizeof(fullpath),
                         "%s/%s", path, entry->d_name);

        if (n < 0 || (size_t)n >= sizeof(fullpath)) {
            fprintf(stderr, "Path too long\n");
            result = -1;
            continue;
        }

        struct stat st;
        if (lstat(fullpath, &st) == -1) {
            perror(fullpath);
            result = -1;
            continue;
        }

        if (S_ISDIR(st.st_mode)) {
            if (directory_clear(fullpath) == -1) {
                result = -1;
                continue;
            }

            if (rmdir(fullpath) == -1) {
                perror(fullpath);
                result = -1;
            }
        } else {
            if (unlink(fullpath) == -1) {
                perror(fullpath);
                result = -1;
            }
        }
    }

    closedir(dir);
    return result;
}

#endif

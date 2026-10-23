/** npins commands */
#ifndef NPINS_H
#define NPINS_H

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/wait.h>


static inline void split_url(const char url[], char base[], char branch[])
{
    const char *slash = strrchr(url, '/');
    if (slash == NULL) {
        base[0] = '\0';
        strcpy(branch, url);
        return;
    }
    size_t base_len = (size_t)(slash - url) + 1;
    memcpy(base, url, base_len);
    base[base_len] = '\0';
    strcpy(branch, slash + 1);
}


static inline int run_npins(const char *options[], int num)
{
    pid_t pid = fork();

    if (pid == -1) {
        perror("fork");
        return -1;
    }

    // build string
    char npins[] = "npins";
    char* argv[num+1];
    argv[0] = npins;
    for (int n = 0; n < num; n++)
    {
        argv[n+1] = (char *) options[n]; // cast the const away
    }

    if (pid == 0) {
        execvp(argv[0], argv);
        perror("execvp");
        _exit(127);
    }

    // Parent: wait for the child to finish
    int status;

    if (waitpid(pid, &status, 0) == -1) {
        perror("waitpid");
        printf("Failed to launch or wait for npins\n");
        return -1;
    }

    if (WIFEXITED(status)) {
        int result = WEXITSTATUS(status);
        if (result != 0)
        {
            printf("npins returned with ERROR code %d\n", result);
        }
        else
        {
            printf("Success\n");
        }
        return result;
    }

    if (WIFSIGNALED(status)) {
        printf("npins was terminated by a signal : %d\n", status);
        return 128 + WTERMSIG(status);
    }
    return -1;
}

static inline int npins_init(const char* path, const char* source, bool is_channel)
{
    // bare init
    const char *opt1[3] = { "-d", path, "--bare" };
    if (run_npins(opt1, 3) != 0)
    {
        return 1;
    }
    // add nixpkgs
    if (is_channel)
    {
        const char *opt2[5] = { "-d", path, "add", "channel", source };
        return run_npins(opt2, 5);
    }
    // else
    {
        char* url = NULL;
        char* branch = NULL;
        split_url(source, url, branch);
        const char *opt2[7] = { "-d", path, "add", "git", url, "--branch", branch };
        return run_npins(opt2, 7);
    }
}

static inline int npins_update(const char* path)
{
    const char *options[3] = { "-d", path, "update" };
    return run_npins(options, 3);
}

#endif

#include <cstdio>
#include <stdio.h>
#include <signal.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/time.h>
#include <sys/resource.h>
#include <sys/wait.h>

#include "shell.hh"

int yyparse(void);

void Shell::prompt() {
    if (isatty(0)) {
        printf("myshell>");
    }
    fflush(stdout);
}

extern "C" void ctrlC(int sig) {
    fflush(stdout);
    printf("\n");
    Shell::prompt();
}

extern "C" void zombie(int sig) {
    int pid = wait3(0, 0, NULL);

    while (waitpid(-1, NULL, WNOHANG) > 0) {
        printf("[%d] exited.\n", pid);
    }
}

int main(int argc, char **argv) {
    
    // 2.1: ctrl-c
    struct sigaction sa_ctrl;
    sa_ctrl.sa_handler = ctrlC;
    sigemptyset(&sa_ctrl.sa_mask);
    sa_ctrl.sa_flags = SA_RESTART;

    // env-var :: $
    std::string s = std::to_string(getpid());
    setenv("$", s.c_str(), 1);

    // env-var :: SHELL
    char real_path[256];
    realpath(argv[0], real_path);
    setenv("SHELL", real_path, 1);

    if (sigaction(SIGINT, &sa_ctrl, NULL)) {
        perror("sigaction");
        exit(2);
    }

    // 2.2: zombie process
    struct sigaction sigzombie;

    sigzombie.sa_handler = zombie;
    sigemptyset(&sigzombie.sa_mask);
    sigzombie.sa_flags = SA_RESTART;

    if (sigaction(SIGCHLD, &sigzombie, NULL)) {
        perror("sigaction");
        exit(-1);
    }

  Shell::prompt();
  yyparse();
}

Command Shell::_currentCommand;

/*
 * CS252: Shell project
 *
 * Template file.
 * You will need to add more code here to execute the command table.
 *
 * NOTE: You are responsible for fixing any bugs this code may have!
 *
 * DO NOT PUT THIS PROJECT IN A PUBLIC REPOSITORY LIKE GIT. IF YOU WANT 
 * TO MAKE IT PUBLICALLY AVAILABLE YOU NEED TO REMOVE ANY SKELETON CODE 
 * AND REWRITE YOUR PROJECT SO IT IMPLEMENTS FUNCTIONALITY DIFFERENT THAN
 * WHAT IS SPECIFIED IN THE HANDOUT. WE OFTEN REUSE PART OF THE PROJECTS FROM  
 * SEMESTER TO SEMESTER AND PUTTING YOUR CODE IN A PUBLIC REPOSITORY
 * MAY FACILITATE ACADEMIC DISHONESTY.
 */

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <sys/types.h>
#include <fcntl.h>
#include <fstream>

#include <iostream>
#include <unistd.h>
#include <sys/wait.h>
#include <string>
#include <vector>

#include "command.hh"
#include "shell.hh"

using namespace std;

Command::Command() {
    // Initialize a new vector of Simple Commands
    _simpleCommands = std::vector<SimpleCommand *>();

    _outFile = NULL;
    _inFile = NULL;
    _errFile = NULL;
    _background = false;
    _append = false;
}

void Command::insertSimpleCommand( SimpleCommand * simpleCommand ) {
    // add the simple command to the vector
    _simpleCommands.push_back(simpleCommand);
}

void Command::clear() {
    // deallocate all the simple commands in the command vector
    for (auto simpleCommand : _simpleCommands) {
        delete simpleCommand;
    }

    // remove all references to the simple commands we've deallocated
    // (basically just sets the size to 0)
    _simpleCommands.clear();

    if ( _errFile == _outFile ) {
        _errFile = NULL;
    }

    if ( _outFile ) {
        delete _outFile;
    }
    _outFile = NULL;

    if ( _inFile ) {
        delete _inFile;
    }
    _inFile = NULL;

    if ( _errFile ) {
        delete _errFile;
    }
    _errFile = NULL;

    _background = false;
}

void Command::print() {
    printf("\n\n");
    printf("              COMMAND TABLE                \n");
    printf("\n");
    printf("  #   Simple Commands\n");
    printf("  --- ----------------------------------------------------------\n");

    int i = 0;
    // iterate over the simple commands and print them nicely
    for ( auto & simpleCommand : _simpleCommands ) {
        printf("  %-3d ", i++ );
        simpleCommand->print();
    }

    printf( "\n\n" );
    printf( "  Output       Input        Error        Background\n" );
    printf( "  ------------ ------------ ------------ ------------\n" );
    printf( "  %-12s %-12s %-12s %-12s\n",
            _outFile?_outFile->c_str():"default",
            _inFile?_inFile->c_str():"default",
            _errFile?_errFile->c_str():"default",
            _background?"YES":"NO");
    printf( "\n\n" );
}

bool Command::builtinChild(int n) { 
    // printenv
    if (strcmp(_simpleCommands[n]->_arguments[0]->c_str(), "printenv") == 0) {
        
        int i = 0;
        while (environ[i]) {
            printf("%s\n", environ[i]);
            i++;
        }
        return true;
    }
    return false;
}

bool Command::builtin(int n) { // n = index of command list
    int env;
    // setenv A B
    if (strcmp(_simpleCommands[n]->_arguments[0]->c_str(), "setenv") == 0) {
        env = setenv(_simpleCommands[n]->_arguments[1]->c_str(), _simpleCommands[n]->_arguments[2]->c_str(), 1);
        if (env != 0) {
            perror("setenv");
        }
        clear();
        Shell::prompt();
        return true;
    }

    // unsetenv A
    if (strcmp(_simpleCommands[n]->_arguments[0]->c_str(), "unsetenv") == 0) {
        env = unsetenv(_simpleCommands[n]->_arguments[1]->c_str());
        if (env != 0) {
            perror("unsetenv");
        }
        clear();
        Shell::prompt();
        return true;
    }
    
    // cd A
    if (strcmp(_simpleCommands[n]->_arguments[0]->c_str(), "cd") == 0) {
        int err;
        if (_simpleCommands[n]->_arguments[1]) {
            if (strncmp(_simpleCommands[n]->_arguments[1]->c_str(), "${HOME}", 7) == 0) {
                err = chdir(getenv("HOME"));
            } else {
                err = chdir(_simpleCommands[n]->_arguments[1]->c_str());
            }

            if (err < 0) {
                perror("cd");
                fprintf(stderr,"cd: can't cd to %s\n",_simpleCommands[0]->_arguments[1]->c_str());
            }

        } else {
            chdir(getenv("HOME"));
        }
        clear();
        Shell::prompt();
        return true;
    }
    return false;
}

void Command::execute() {
    // Don't do anything if there are no simple commands
    if ( _simpleCommands.size() == 0 ) {
        Shell::prompt();
        return;
    }

    // Print contents of Command data structure
    //print();

    // Add execution here
    // For every simple command fork a new process
    // Setup i/o redirection
    // and call exec

    // save default input, output, and error to change during redirection
    // and restore again
    
    // default in/out/err files 
    int defin = dup(0);
    int defout = dup(1);
    int deferr = dup(2);

    // file descriptors
    int fdin = 0;
    int fdout = 0;
    int fderr = 0;
    
    // return value of fork()
    int ret;

    if (_inFile) {
        fdin = open(_inFile->c_str(), O_RDONLY);
    } else {
        fdin = dup(defin);
    }
    if (_errFile) {
        if (_append) {
            fderr = open(_errFile->c_str(), O_WRONLY | O_APPEND | O_CREAT, 0600);
        } else {
            fderr = open(_errFile->c_str(), O_WRONLY | O_CREAT | O_TRUNC, 0600);
        }
    } else {
        fderr = dup(deferr);
    }
    dup2(fderr, 2);
    close(fderr);
        
    for (size_t i = 0; i < _simpleCommands.size(); i++) {
    
        // redirect input
        dup2(fdin, 0);
        close(fdin);

        // setup output
        // if last command, direct to stdout
        if (i == _simpleCommands.size() - 1) {
            if (_outFile) {
                if (_append) {
                    fdout = open(_outFile->c_str(), O_WRONLY | O_APPEND | O_CREAT, 0600);
                } else {
                    fdout = open(_outFile->c_str(), O_WRONLY | O_CREAT | O_TRUNC, 0600);
                }
            // it not last command, use default output
           } else {
                fdout = dup(defout);
           }

           int n = _simpleCommands[i]->_arguments.size();
           char * c = strdup(_simpleCommands[i]->_arguments[n-1]->c_str()); 
           setenv("_", c, 1);
            
        // if not last simple command, create pipe
        } else {
            int fdpipe[2];
            pipe(fdpipe);
            fdout = fdpipe[1];
            fdin = fdpipe[0];
        }

        // redirect output to fdout (fdpipe[1])
        dup2(fdout, 1);
        close(fdout);

        // setenv, unsetenv, cd
        if (builtin(i)) {
            return;
        }

        // create child process
        ret = fork();

        if (ret == 0) {

            // printenv
            if (builtinChild(i)) {
                return;
            }

            // convert vector to char** for execvp
            size_t argsize = _simpleCommands[i]->_arguments.size();
            char ** args = new char * [argsize + 1];
            for (size_t j = 0; j < argsize; j++) {
                args[j] = const_cast<char *>(_simpleCommands[i]->_arguments[j]->c_str());
                args[j][strlen(_simpleCommands[i]->_arguments[j]->c_str())] = '\0';
            }
            args[argsize] = NULL;

            // child
            execvp(args[0], args);
            //perror("execvp");
            _exit(1);

        } else if (ret < 0) {
            perror("fork");
            exit(1);
        }   
        //parent shell continue
    } // end for

    // restore in/out defaults
    dup2(defin, 0);
    dup2(defout, 1);
    dup2(deferr, 2);
    close(defin);
    close(defout);
    close(deferr);

    if (!_background) {
        // wait for last command
        int status;
        waitpid(ret, &status, 0);
        std::string str = std::to_string(WEXITSTATUS(status));
        setenv("?", str.c_str(), 1);
    } else {
        std::string str = std::to_string(ret);
        setenv("!", str.c_str(), 1);
    }

    // Clear to prepare for next command
    clear();

    // Print new prompt
    Shell::prompt();
}

SimpleCommand * Command::_currentSimpleCommand;

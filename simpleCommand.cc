#include <cstdio>
#include <cstdlib>

#include <iostream>

#include "simpleCommand.hh"

SimpleCommand::SimpleCommand() {
  _arguments = std::vector<std::string *>();
}

SimpleCommand::~SimpleCommand() {
  // iterate over all the arguments and delete them
  for (auto & arg : _arguments) {
    delete arg;
  }
}
/*
char * simpleCommand::expand(char * argument) {
    char * arg = strdup(argument);
    char * hasDollar = strchr(arg, '$');
    char * hasBrace1 = strchr(arg, '{');

    char * newstr = (char *)malloc(sizeof(argument) + 50);
    char * tempstr = newstr;

    if (hasDollar && hasBrace1) {
        while (*arg != '$') {
            *tempstr = *arg;
            *tempstr++;
            *arg++;
        }
        *tempstr = '\0';

        while (hasDollar) {
            if (hasDollar[1] == '{' && hasDollar[2] == '}') {
                char * tmp = hasDollar + 2;
                char * envvar = (char *)malloc(20);
                char * envvartmp = envvar;

                while (*tmp != '}') {
                    *envvartmp = *tmp;
                    *envvartmp++;
                    *tmp++;
                }
                *envvartmp = '\0';

                char * result = getenv(envvar);
                strcat(newstr, result);

                while (*(arg-1) != '}') {
                    arg++;
                }

                char * buffer = (char *)malloc(20);
                char * tmpbuffer = buffer;

                while (*arg && *arg != '$') {
                    *tmpbuffer = *arg;
                    *tmpbuffer++;
                    arg++;
                }
                *tmpbuffer = '\0';
                strcat(newstr, buffer);
            }
            hasDollar++;
            hasDollar = strchr(hasDollar, '$');
        }
        argument = strdup(newstr);
        return argument;
    }
    return NULL;
}
*/
void SimpleCommand::insertArgument( std::string * argument ) {
  // simply add the argument to the vector
  _arguments.push_back(argument);
}

// Print out the simple command
void SimpleCommand::print() {
  for (auto & arg : _arguments) {
    std::cout << "\"" << *arg << "\" \t";
  }
  // effectively the same as printf("\n\n");
  std::cout << std::endl;
}

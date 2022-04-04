
/*
 * CS-252
 * shell.y: parser for shell
 *
 * This parser compiles the following grammar:
 *
 *	cmd [arg]* [> filename]
 *
 * you must extend it to understand the complete shell grammar
 *
 */

%code requires 
{
#include <sys/types.h>
#include <string>
#include <string.h>
#include <regex.h>
#include <dirent.h>
#include <algorithm>

#if __cplusplus > 199711L
#define register      // Deprecated in C++11 so remove the keyword
#endif
#define MAXFILENAME 1024
}

%union
{
  char        *string_val;
  // Example of using a c++ type in yacc
  std::string *cpp_string;
}

%token <cpp_string> WORD
%token NOTOKEN GREAT NEWLINE PIPE LESS GREATGREAT GREATAND GREATGREATAND TWOGREAT AMPERSAND

%{
//#define yylex yylex
#include <cstdio>
#include <stdio.h>
#include <string.h>
#include <regex.h>
#include <dirent.h>
#include <unistd.h>
#include "shell.hh"
#include "command.hh"
#include <string>

void yyerror(const char * s);
int yylex();
void expandWildcardsIfNecessary(std::string * arg);
void expandWildcard(char * prefix, char * suffix);
int compare(char *file1, char *file2);
static std::vector<char *> sortargument = std::vector<char *>();

%}

%%

goal:
  commands
  ;

commands:
  command
  | commands command
  ;

command: simple_command
       ;

simple_command:	
  pipe_list io_modifier_list background_opt NEWLINE {
    //printf("   Yacc: Execute command\n");
    Shell::_currentCommand.execute();
  }
  | NEWLINE 
  | error NEWLINE { yyerrok; }
  ;

pipe_list:
    pipe_list PIPE command_and_args
    | command_and_args
    ;

command_and_args:
  command_word argument_list {
    Shell::_currentCommand.
    insertSimpleCommand( Command::_currentSimpleCommand );
  }
  ;

argument_list:
  argument_list argument
  | /* can be empty */
  ;

argument:
  WORD {
    //printf("   Yacc: insert argument \"%s\"\n", $1->c_str());
    //Command::_currentSimpleCommand->insertArgument( $1 );
        expandWildcardsIfNecessary($1);  
        //delete($1);
    }
  ;

command_word:
  WORD {
    //printf("   Yacc: insert command \"%s\"\n", $1->c_str());
    // 2.3: exit
    if (strcmp($1->c_str(), "exit") == 0) {
        printf("Good bye!!\n");
        exit(1);
    }
    Command::_currentSimpleCommand = new SimpleCommand();
    Command::_currentSimpleCommand->insertArgument( $1 );
  }
  ;

iomodifier_opt:
  GREAT WORD {
    //printf("   Yacc: insert output \"%s\"\n", $2->c_str());
    if (Shell::_currentCommand._outFile != NULL) {
        printf("Ambiguous output redirect.\n");
        exit(0);
    }
    Shell::_currentCommand._outFile = $2;
  }
  | LESS WORD {
    //printf("   Yacc: insert input \"%s\"\n", $2->c_str());
    if (Shell::_currentCommand._inFile != NULL) {
        printf("Ambiguous output redirect.\n");
        exit(0);
    }
    Shell::_currentCommand._inFile = $2;
  }
  | GREATGREAT WORD {
    //printf("   Yacc: insert output \"%s\"\n", $2->c_str());
    if (Shell::_currentCommand._outFile != NULL) {
        printf("Ambiguous output redirect.\n");
        exit(0);
    }
    Shell::_currentCommand._outFile = $2;
    Shell::_currentCommand._append = true;
  }
  | GREATGREATAND WORD {
    //printf("   Yacc: insert output \"%s\"\n", $2->c_str());
    if (Shell::_currentCommand._outFile != NULL) {
        printf("Ambiguous output redirect.\n");
        exit(0);
    }
    if (Shell::_currentCommand._errFile != NULL) {
        printf("Ambiguous output redirect.\n");
        exit(0);
    }
    Shell::_currentCommand._outFile = $2;
    Shell::_currentCommand._errFile = $2;
    Shell::_currentCommand._append = true;
  }
  | GREATAND WORD {
    //printf("   Yacc: insert output \"%s\"\n", $2->c_str());
    if (Shell::_currentCommand._outFile != NULL) {
        printf("Ambiguous output redirect.\n");
        exit(0);
    }
    if (Shell::_currentCommand._errFile != NULL) {
        printf("Ambiguous output redirect.\n");
        exit(0);
    }
    Shell::_currentCommand._outFile = $2;
    Shell::_currentCommand._errFile = $2; 
  }
  | TWOGREAT WORD {
    //printf("   Yacc: insert output \"%s\"\n", $2->c_str());
    if (Shell::_currentCommand._errFile != NULL) {
        printf("Ambiguous output redirect.\n");
        exit(0);
    }
    Shell::_currentCommand._errFile = $2;
  }
  ;

io_modifier_list:
    io_modifier_list iomodifier_opt
    | // empty
    ;

background_opt:
    AMPERSAND {
        //printf("    Yacc: background true\n");
        Shell::_currentCommand._background = true;
    }
    | // empty
    ;

%%

int compare(const void *file1, const void *file2) {
    const char *f1 = *(const char **)file1;
    const char *f2 = *(const char **)file2;
    return strcmp(f1, f2);
}

void
yyerror(const char * s)
{
  fprintf(stderr,"%s", s);
}

int maxentries = 20;
int numentries = 0;
char **entries;

void expandWildcardsIfNecessary(std::string * arg) {
    char * newarg = (char *)malloc(arg->length()+1);
    strcpy(newarg, arg->c_str());
    maxentries = 20;
    numentries = 0;
    entries = (char **)malloc(maxentries * sizeof(char *));

    if (strchr(newarg, '*') || strchr(newarg, '?')) {
        expandWildcard(NULL, newarg);

        if (numentries == 0) {
            Command::_currentSimpleCommand->insertArgument(arg);
            return;
        }
        qsort(entries, numentries, sizeof(char *), compare);

        for (int i = 0; i < numentries; i++) {
            std::string * str = new std::string(entries[i]);
            Command::_currentSimpleCommand->insertArgument(str);
        }

    } else {
        Command::_currentSimpleCommand->insertArgument(arg);
    }
    //free(newarg); free(entries);
    return;
}

void expandWildcard(char * prefix, char * suffix) {
    char * tmp = suffix;
    char * save = (char *)malloc(strlen(suffix) + 10);
    char * dir = save;

    if (tmp[0] == '/') {
        *(save++) = *(tmp++);
    }

    while (*tmp != '/' && *tmp) {
        *(save++) = *(tmp++);
    }
    *save = '\0';

    if (strchr(dir, '*') || strchr(dir, '?')) {
        if (!prefix && suffix[0] == '/') {
            prefix = strdup("/");
            dir++;
        }

        char * reg = (char *)malloc(2 * strlen(suffix) + 10);
        char * a = dir;
        char * r = reg;

        *r = '^';
        r++;
        while (*a) {
            if (*a == '*') { *r = '.'; r++; *r = '*'; r++; }
			else if (*a == '?') { *r = '.'; r++; }
			else if (*a == '.') { *r = '\\'; r++; *r = '.'; r++; }
			else { *r = *a; r++; }
			a++;
        }
        *r = '$'; r++; *r = '\0'; 

        regex_t re;
        int expbuf = regcomp(&re, reg, REG_EXTENDED|REG_NOSUB);

        char * filetoopen = strdup((prefix)?prefix:".");
        DIR * directory = opendir(filetoopen);
        if (directory == NULL) {
            perror("opendir");
            return;
        }
        struct dirent * ent;
        regmatch_t found;

        while ((ent = readdir(directory)) != NULL) {
            if (!regexec(&re, ent->d_name, 1, &found, 0)) {

                if (*tmp) {

                    if (ent->d_type == DT_DIR) {
                        char * numprefix = (char *)malloc(150);

                        if (!strcmp(filetoopen, ".")) {
                            numprefix = strdup(ent->d_name);

                        } else if (!strcmp(filetoopen, "/")) {
                            sprintf(numprefix, "%s%s", filetoopen, ent->d_name);

                        } else {
                            sprintf(numprefix, "%s/%s", filetoopen, ent->d_name);
                        }
                        expandWildcard(numprefix, (*tmp == '/')?++tmp:tmp);
                    }

                } else {
                    if (numentries == maxentries) {
                        maxentries *= 2;
                        entries = (char **)realloc(entries, maxentries * sizeof(char *));
                    }
                    char * argument = (char *)malloc(100);
                    argument[0] = '\0';

                    if (prefix) {
                        sprintf(argument, "%s/%s", prefix, ent->d_name);
                    } 

                    if (ent->d_name[0] == '.') {
                        if (suffix[0] == '.') {
                            entries[numentries++] = (argument[0] != '\0')?strdup(argument):strdup(ent->d_name);
                        }
                    } else {
                        entries[numentries++] = (argument[0] != '\0')?strdup(argument):strdup(ent->d_name);
                    }
                }
            }
        }
        closedir(directory);

    } else {
        char * finalprefix = (char *)malloc(100);
        if (prefix) {
            sprintf(finalprefix, "%s/%s", prefix, dir);

        } else {
            finalprefix = strdup(dir);
        }
        if (*tmp) {
            expandWildcard(finalprefix, ++tmp);
        }
    }

   // free(save); free(entries);
//free(reg); free(numprefix); free(filetoopen);     
}


#if 0
main()
{
  yyparse();
}
#endif

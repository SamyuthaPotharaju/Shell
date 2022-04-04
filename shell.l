
/*
 *
 * CS-252 
 * shell.l: lexical analyzer for shell
 * You have to extend it.
 *
 */

%{

#include <string.h>
#include <cstring>
#include "y.tab.hh"
#include <stdlib.h>
#include <stdio.h>
#include "unistd.h"
#include "shell.hh"

#ifndef MAXPATHLEN
#define MAXPATHLEN 2048

#endif

extern int returncode;
extern int exclamationvar;
extern std::string lastargument;

extern char ** environ;

static  void yyunput (int c,char *buf_ptr  );

void myunputc(int c) {
    unput(c);
}

////////////  Start added code ///////////


extern "C" char * read_line();

int mygetc(FILE * f) {
  static char *p;
  char ch;

     if (!isatty(0)) {
  // stdin is not a tty. Call real getc
    return getc(f);
  }

  // stdin is a tty. Call our read_line.
  if (p==NULL || *p == 0) {
    char * s = read_line();
    p = s;
  }

  ch = *p;
  p++;

  return ch;
}

#undef getc
#define getc(f) mygetc(f)

/////////// End added code ///////////


%}

%option noyywrap

%%

\n {
    return NEWLINE;
}

[ \t] {
    /* Discard spaces and tabs */
}

">" {
    return GREAT;
}

"|" {
    return PIPE;
}

"<" {
    return LESS;
}

"2>" {
    return TWOGREAT;
}

">&" {
    return GREATAND;
}

">>" {
    return GREATGREAT;
}

">>&" {
    return GREATGREATAND;
}

"&" {
    return AMPERSAND;
}

~[^\n]* {
    // 3.2 tilde expansion
    //printf("tilde");
    std::string str = std::string(yytext);
    std::string homedir = getenv("HOME");

    if (str.size() == 2) {
        yylval.cpp_string = new std::string(homedir);

    } else {
        if (str[1] == '/') {
            str = homedir + str.substr(1, str.size()-1);
        } else {
            str = std::string("/homes/") + str.substr(1, str.size()-1);
        }
        yylval.cpp_string = new std::string(str);
    }
    return WORD;
}


\$\{[^\n]*\}([^ \n]*|$\{[^\n]*\})* { 
    // 3.1 env var expansion
    
    std::string str = std::string(yytext);
    std::string finalstr = "";
    //printf("start::: %s\n", str.c_str()); ///
    
    while (str.find('$') != -1) {
        finalstr += str.substr(0, str.find('$'));
        //printf("result: %s\n", finalstr.c_str()); ///
        int pos = str.find('$');

        if (str[pos+1] == '{') {
            std::size_t end = str.find('}');
            std::string component;

            if (end != -1) {
                component = str.substr(pos+2, end-pos-2);
                //printf("component: %s\n", component.c_str()); ///

                if (getenv(component.c_str())) {
                    finalstr += getenv(component.c_str());
                } else {
                    finalstr += component;
                }
                str = str.substr(end+1, -1);
            }
        }
       //printf("final str ::: %s\n", finalstr.c_str()); ///
    }
    finalstr += str;
    yylval.cpp_string = new std::string(finalstr);
    return WORD; 
}

\`[^\n\"]*\`|\$\([^\n\"]*\) {    
    // 2.8: subshell
    // '...' or $(...)

    std::string cmd = std::string(yytext);

    // remove $()
    if (cmd.find('$') != -1) {
        cmd = cmd.substr(2, cmd.size() - 3);
    // remove ''
    } else {
        cmd = cmd.substr(1, cmd.size() - 2);
    }

    // parent creates two pipes
    int pin[2], pout[2];
    pipe(pin);
    pipe(pout);

   // parent writes to pin[1]
    write(pin[1], cmd.c_str(), cmd.size());
    write(pin[1], "\n", 1);
    write(pin[1], "exit\n", 5);
    close(pin[1]);
    //close(pout[0]);

    // parent creates child process
    int ret = fork();

    if (ret == 0) {

        // in child redirect
        dup2(pin[0], 0);
        dup2(pout[1], 1);

        // execute shell
        execvp("/proc/self/exe", NULL);
        _exit(1);

    } else if (ret < 0) {
        perror("fork");
        exit(1);
    }
    close(pin[0]);
    close(pout[1]);

    // parent reads output from pout[0], writes to buffer
    int size = 4096;
    char * buffer = (char *)malloc(size);
    char c;
    int i = 0;

    while (read(pout[0], &c, 1)) {
        //printf("while");
        //printf("%c", c);
        if (c == '\n') {
            buffer[i] = ' ';
        } else {
            buffer[i] = c;
        }
        i++;
    }
    buffer[i] = '\0';
    close(pout[0]);

    // put chars in buffer back into lex in reverse order
    for (int j = i - 12; j >= 0; j--) {
        //printf("for");
        myunputc(buffer[j]);
    }
}

source([\ ])[^ \t\n][^ \t\n]* {
    // 2.6 source
    //printf("regex recognising");
    std::string filename = yytext;
    // remove 'source ' to get file name
    filename = filename.substr(7, filename.size() - 7);
    FILE * fp = fopen(filename.c_str(), "r");

    // create buffer if file exists
    if (fp != NULL) {
        YY_BUFFER_STATE state = yy_create_buffer(fp, YY_BUF_SIZE);
        // buffer then parse
        yypush_buffer_state(state);
        yyparse();
        // pop from state stack
        yypop_buffer_state();
        fclose(fp);

    } else {
        exit(1);
    }
}

[\"][^\n\"]*[\"] {
    // 2.4: quotes

    std::string quote = yytext;
    quote = quote.substr(1, quote.length()-2);
    yylval.cpp_string = new std::string(quote);
    return WORD;
}

([^ \t\n<>\|\&\"\(\)]|\\.)+ {
    // 2.5: escaping
    
    char * line = strdup(yytext);
    std::string str = "";

    for (int i = 0; line[i] != '\0'; i++) {
        if (!(line[i] == '\\' && line[i + 1] != ' ')) {
            str += line[i];
        }
    }
    yylval.cpp_string = new std::string(str);
    str.clear();
    
    return WORD;
}

[^ \|<&>\t\n][^ \|<&>\t\n]* {
    /* Assume that file names have only alpha chars */
    yylval.cpp_string = new std::string(yytext);
    return WORD;
}

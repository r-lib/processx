// gcc -Wall -std=gnu99 supervisor.c -o supervisor && ./supervisor
//
// Using C99 in R package:
// http://stackoverflow.com/questions/35198301/how-use-the-option-std-c99-for-installing-r-packages


#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <limits.h>
#include <fcntl.h>
#include <sys/types.h>
#include <signal.h>

#ifdef WIN32
#include <process.h>
#endif

#define MIN(a,b) ((a<b)?a:b)
#define MAX(a,b) ((a>b)?a:b)


// Constants ------------------------------------------------------------------

// Size of stdin input buffer
#define buf_len 256
// Maximum number of children to keep track of
#define max_children 2048
// Milliseconds to sleep in polling loop
#define poll_ms 1000
// Input event buffer size, used in Windows.
// Will read this many console events before blocking.
#define input_buf_size 1024

// Globals --------------------------------------------------------------------

// Child processes to track
int children[max_children];
int n_children = 0;

// Utility functions ----------------------------------------------------------

// Cross-platform sleep function
#ifdef WIN32
#include <windows.h>
#elif _POSIX_C_SOURCE >= 199309L
#include <time.h>   // for nanosleep
#else
#include <unistd.h> // for usleep
#endif

void sleep_ms(int milliseconds) {
#ifdef WIN32
    Sleep(milliseconds);
#elif _POSIX_C_SOURCE >= 199309L
    struct timespec ts;
    ts.tv_sec = milliseconds / 1000;
    ts.tv_nsec = (milliseconds % 1000) * 1000000;
    nanosleep(&ts, NULL);
#else
    usleep(milliseconds * 1000);
#endif
}


// Windows process management functions
#ifdef WIN32
// TODO
void kill(pid_t pid, int signal) {

}

// TODO
// http://stackoverflow.com/questions/185254/how-can-a-win32-process-get-the-pid-of-its-parent
int getppid() {
    return 0;
}


//
void configure_stdin(HANDLE h_input) {
    DWORD handle_type = GetFileType(h_input);

    if (handle_type == FILE_TYPE_CHAR) {

        DWORD lpmode;
        GetConsoleMode(h_input, &lpmode);
        printf("Console mode: %04x\n", (int)lpmode);

        // Disable line input
        lpmode = lpmode &
                 ~ENABLE_LINE_INPUT &
                 ~ENABLE_ECHO_INPUT;
        printf("Setting console mode to: %04x\n", (int)lpmode);

        // Only listen for character input events
        if (!SetConsoleMode(h_input, lpmode)) {
            printf("Unable to set console mode. %d", (int)GetLastError());
            exit(1);
        }

    } else if (handle_type == FILE_TYPE_PIPE) {
        // No need to do anything
    } else if (handle_type == FILE_TYPE_DISK) {
        printf("Don't know how to handle FILE_TYPE_DISK.");
        exit(1);
    } else {
        printf("Unknown input type.");
        exit(1);
    }
}


// If there's a complete line of text, put that line in buffer, and return the
// number of characters. Otherwise, return NULL.
char* get_line_nonblock(char* buf, int max_chars, HANDLE h_input) {
    // Check what type of thing we're reading from
    DWORD input_type = GetFileType(h_input);

    // Debugging info
    char* input_type_name;
    switch(input_type) {
        case FILE_TYPE_CHAR:
            input_type_name = "FILE_TYPE_CHAR (console)";
            break;
        case FILE_TYPE_DISK:
            input_type_name = "FILE_TYPE_DISK";
            break;
        case FILE_TYPE_PIPE:
            input_type_name = "FILE_TYPE_PIPE";
            break;
        default:
            input_type_name = "Unknown";
    }


    if (input_type == FILE_TYPE_CHAR) {
        // Attempt to read enough to fill the buffer
        DWORD num_peeked;
        INPUT_RECORD in_record_buf[input_buf_size];
        char input_char_buf[input_buf_size];
        int input_char_buf_n = 0;

        // First use PeekConsoleInput to make sure some char is available,
        // because ReadConsoleInput will block if there's no input.
        if (!PeekConsoleInput(h_input, in_record_buf, input_buf_size, &num_peeked)) {
            printf("Error peeking at console input.");
            exit(1);            
        };

        if (num_peeked == 0) {
            printf("0 events in console buffer.\n");
            return NULL;
        }

        BOOL found_newline = FALSE;

        int i;
        for (i=0; i<num_peeked; i++) {
            // We're looking for key down events where the value is not 0.
            // (Special keys like Shift will have AsciiChar value of 0.)
            if (in_record_buf[i].EventType == KEY_EVENT &&
                in_record_buf[i].Event.KeyEvent.bKeyDown &&
                in_record_buf[i].Event.KeyEvent.uChar.AsciiChar != 0) 
            {
                // Store the character in input_char_buf. If there's a \n, then
                // copy in_record_buf (up to the \n) to buf.
                char c = in_record_buf[i].Event.KeyEvent.uChar.AsciiChar;

                if (c == '\r') {
                    found_newline = TRUE;
                    input_char_buf[input_char_buf_n] = '\n';
                    input_char_buf_n++;
                    break;
                } else {
                    input_char_buf[input_char_buf_n] = c;
                    input_char_buf_n++;
                }

                // TODO: Make sure not to overflow input_buf_n. Block if we
                // hit the maximum?
            }
        }


        if (found_newline) {
            // This is the number of events up to and including the '\n'
            DWORD num_events_read = i+1;
            DWORD num_events_read2;
            // Clear out console buffer up to the '\n' event
            if (!ReadConsoleInput(h_input, in_record_buf, num_events_read , &num_events_read2)) {
                printf("Error reading console input.");
                exit(1);            
            }

            // Place the content in buf
            snprintf(buf, MIN(input_char_buf_n, max_chars), "%s", input_char_buf);
            return buf;

        } else {
            return NULL;
        }

    } else if (input_type == FILE_TYPE_PIPE) {
        DWORD num_peeked;
        char input_char_buf[input_buf_size];
        int input_char_buf_n = 0;

        if (!PeekNamedPipe(h_input, input_char_buf, input_buf_size, &num_peeked, NULL, NULL)) {
            printf("Error peeking at pipe input.");
            exit(1);
        };

        BOOL found_newline = FALSE;
        for (int i=0; i<num_peeked; i++) {
            if (input_char_buf[i] == '\r' || input_char_buf[i] == '\n') {
                found_newline = TRUE;
            }
            input_char_buf_n++;
        }

        DWORD num_read;
        if (found_newline) {
            // Clear out pipe
            if (!ReadFile(h_input, input_char_buf, input_char_buf_n, &num_read, NULL)) {
                printf("Error reading pipe input.");
                exit(1);
            }

            // Place the content in buf
            snprintf(buf, MIN(input_char_buf_n, max_chars), "%s", input_char_buf);
            return buf;

        } else {
            return NULL;
        }

    } else {
        printf("Unsupported input type: %s", input_type_name);
    }

    return buf;
}


void sendCtrlC(int pid) {
    printf("sending ctrl+c to pid %d", pid);
    FreeConsole();

    if (AttachConsole(pid)) {
        GenerateConsoleCtrlEvent(CTRL_C_EVENT, 0);
    } else {
        printf("Error attaching to console for PID: %d\n", pid);
    }
}
#endif // WIN32


// Given a string of format "102", return 102. If conversion fails because it
// is out of range, or because the string can't be parsed, return 0.
int extract_pid(char* buf, int len) {
    long pid = strtol(buf, NULL, 10);

    // Out of range: errno is ERANGE if it's out of range for a long. We're
    // going to cast to int, so we also need to make sure that it's within
    // range for int.
    if (errno == ERANGE || pid > INT_MAX || pid < INT_MIN) {
        return 0;
    }

    return (int)pid;
}


// Check if a process is running. Returns 1 if yes, 0 if no.
int pid_is_running(pid_t pid) {
    int res = kill(pid, 0);
    if (res == -1 && errno == ESRCH) {
        return 0;
    }
    return 1;
}

// TODO: First try a soft kill, then wait for 5 seconds, then do hard kill if
// still alive.

// Send SIGTERM to all children.
void kill_children() {
    printf("Sending SIGTERM to children: ");
    for (int i=0; i<n_children; i++) {
        printf("%d ", children[i]);

        #ifdef WIN32
        // In Windows, try sending a Ctrl-C in addition to the SIGTERM
        sendCtrlC(children[i]);
        #endif
        kill(children[i], SIGTERM);
    }
}


static void sig_handler(int signum) {
    char* signame;
    if (signum == SIGTERM)
        signame = "SIGTERM";
    else if (signum == SIGINT)
        signame = "SIGINT";
    else
        signame = "Unkown signal";
    printf("%s received.\n", signame);

    kill_children();

    printf("\n");
    exit(0);
}


// Remove an element from an array and shift all items down. The last item
// gets a 0. Returns new length of array.
int remove_element(int* ar, int len, int idx) {
    for (int i=idx; i<len-1; i++) {
        ar[i] = ar[i+1];
    }
    ar[len-1] = 0;
    return len-1;
}




int main() {
    printf("PID: %d\n", getpid());
    int parent_pid = getppid();
    printf("Parent PID: %d\n", parent_pid);

    // stdin input buffer
    char readbuf[buf_len];

    // Make stdin nonblocking
    #ifdef WIN32
    HANDLE h_stdin = GetStdHandle(STD_INPUT_HANDLE); 
    if (h_stdin == INVALID_HANDLE_VALUE) {
        printf("Unable to get stdin handle.");
        exit(1);
    }

    configure_stdin(h_stdin);

    #else
    fcntl(STDIN_FILENO, F_SETFL, O_NONBLOCK);
    #endif


    // Register signal handler
    #ifdef WIN32
    signal(SIGINT, sig_handler);
    signal(SIGTERM, sig_handler);
    #else
    struct sigaction sa;
    sa.sa_handler = sig_handler;
    sigemptyset(&sa.sa_mask);
    if (sigaction(SIGINT, &sa, NULL)  == -1 ||
        sigaction(SIGTERM, &sa, NULL) == -1) {
        printf("Error setting up signal handler.\n");
        exit(1);
    }
    #endif


    // Poll
    while(1) {
        // TODO: Handle case where multiple PIDs are entered in one cycle.
        // Look for any new processes IDs from stdin
        char* res;

        #ifdef WIN32
        res = get_line_nonblock(readbuf, buf_len, h_stdin);   
        #else
        res = fgets(readbuf, buf_len, stdin);
        #endif
        if (res != NULL) {
            int pid = extract_pid(readbuf, buf_len);
            if (pid != 0) {
                if (n_children == max_children) {
                    printf(
                        "Number of child processes to watch has exceeded limit of %d.",
                        max_children
                    );
                } else {
                    children[n_children] = pid;
                    n_children++;
                }
            }
        }

        // Remove any children from list that are no longer running.
        for (int i=0; i<n_children; i++) {
            if (pid_is_running(children[i])) {
                printf("Running: %d ", children[i]);
            } else {
                n_children = remove_element(children, n_children, i);
            }
        }
        printf("\n");

        // Check that parent is still running. If not, kill children.
        if (!pid_is_running(parent_pid)) {
            printf("Parent (%d) killed.\n", parent_pid);
            kill_children();
            printf("\nExiting.\n");
            return 0;
        }

        sleep_ms(poll_ms);
    }

    return 0;
}

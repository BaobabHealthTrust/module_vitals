//
// webserver.c
//
// Simple HTTP server sample for sanos
//

#include <stdio.h>
#include <string.h>
#include <time.h>
#include <sys/stat.h>
#include <dirent.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <regex.h>
#include <termios.h>
#include <stdlib.h>
#include <fcntl.h>

#define SERVER "webserver/1.0"
#define PROTOCOL "HTTP/1.0"
#define RFC1123FMT "%a, %d %b %Y %H:%M:%S GMT"
#define PORT 3000

#define MAX_ERROR_MSG 0x1000

#define BAUDRATE B9600            

float weight;
float height;
float bmi;

// Start BP MACHINE variables
int bp_fd,bp_c,bp_res,bp_result;
struct termios bp_oldtio,bp_newtio;

char *bp_dev,*bp_ph,*bp_msg;
const int bp_buf_max = 512;    // 256;
int bp_baudrate = 9600;  // default

char bp_buf[512];

char bp_eolchar = '\n';
int bp_timeout = 5000;

unsigned char start[16]    = {0x16, 0x16, 0x01, 0x30, 0x20, 0x02, 0x53, 0x54, 0x03, 0x07};
unsigned char stop[16]     = {0x16, 0x16, 0x01, 0x30, 0x20, 0x02, 0x53, 0x50, 0x03, 0x03};
unsigned char bp[16]       = {0x16, 0x16, 0x01, 0x30, 0x20, 0x02, 0x52, 0x42, 0x03, 0x10};
unsigned char pulse[16]    = {0x16, 0x16, 0x01, 0x30, 0x20, 0x02, 0x52, 0x50, 0x03, 0x10};

// End BP MACHINE variables

//
int serialport_flush(int fd)
{
    sleep(2); //required to make flush work, for some reason
    return tcflush(fd, TCIOFLUSH);
}

// takes the string name of the serial port (e.g. "/dev/tty.usbserial","COM1")
// and a baud rate (bps) and connects to that port at that speed and 8N1.
// opens the port in fully raw mode so you can send binary data.
// returns valid fd, or -1 on error
int serialport_init(const char* serialport, int baud)
{
    struct termios toptions;
    int fd;
    
    //fd = open(serialport, O_RDWR | O_NOCTTY | O_NDELAY);
    fd = open(serialport, O_RDWR | O_NONBLOCK );
    
    if (fd == -1)  {
        perror("serialport_init: Unable to open port ");
        return -1;
    }
    
    //int iflags = TIOCM_DTR;
    //ioctl(fd, TIOCMBIS, &iflags);     // turn on DTR
    //ioctl(fd, TIOCMBIC, &iflags);    // turn off DTR

    if (tcgetattr(fd, &toptions) < 0) {
        perror("serialport_init: Couldn't get term attributes");
        return -1;
    }
    speed_t brate = baud; // let you override switch below if needed
    switch(baud) {
    case 4800:   brate=B4800;   break;
    case 9600:   brate=B9600;   break;
#ifdef B14400
    case 14400:  brate=B14400;  break;
#endif
    case 19200:  brate=B19200;  break;
#ifdef B28800
    case 28800:  brate=B28800;  break;
#endif
    case 38400:  brate=B38400;  break;
    case 57600:  brate=B57600;  break;
    case 115200: brate=B115200; break;
    }
    cfsetispeed(&toptions, brate);
    cfsetospeed(&toptions, brate);

    // 8N1
    toptions.c_cflag &= ~PARENB;
    toptions.c_cflag &= ~CSTOPB;
    toptions.c_cflag &= ~CSIZE;
    toptions.c_cflag |= CS8;
    // no flow control
    toptions.c_cflag &= ~CRTSCTS;

    //toptions.c_cflag &= ~HUPCL; // disable hang-up-on-close to avoid reset

    toptions.c_cflag |= CREAD | CLOCAL;  // turn on READ & ignore ctrl lines
    toptions.c_iflag &= ~(IXON | IXOFF | IXANY); // turn off s/w flow ctrl

    toptions.c_lflag &= ~(ICANON | ECHO | ECHOE | ISIG); // make raw
    toptions.c_oflag &= ~OPOST; // make raw

    // see: http://unixwiz.net/techtips/termios-vmin-vtime.html
    toptions.c_cc[VMIN]  = 0;
    toptions.c_cc[VTIME] = 0;
    //toptions.c_cc[VTIME] = 20;
    
    tcsetattr(fd, TCSANOW, &toptions);
    if( tcsetattr(fd, TCSAFLUSH, &toptions) < 0) {
        perror("init_serialport: Couldn't set term attributes");
        return -1;
    }

    return fd;
}

//
int serialport_read_until(int fd, char* buf, char until, int buf_max, int timeout)
{
    char b[1];  // read expects an array, so we give it a 1-byte array
    int i=0;
    do { 
        int n = read(fd, b, 1);  // read a char at a time
        if( n==-1) return -1;    // couldn't read
        if( n==0 ) {
            usleep( 1 * 1000 );  // wait 1 msec try again
            timeout--;
            continue;
        }
#ifdef SERIALPORTDEBUG  
        printf("serialport_read_until: i=%d, n=%d b='%c'\n",i,n,b[0]); // debug
#endif
        buf[i] = b[0]; 
        i++;
    } while( b[0] != until && i < buf_max && timeout>0 );

    buf[i] = 0;  // null terminate the string
    
    return 0;
}

/* Compile the regular expression described by "regex_text" into
   "r". */

static int compile_regex (regex_t * r, const char * regex_text)
{
    int status = regcomp (r, regex_text, REG_EXTENDED|REG_NEWLINE);
    if (status != 0) {
	char error_message[MAX_ERROR_MSG];
	regerror (status, r, error_message, MAX_ERROR_MSG);
        printf ("Regex error compiling '%s': %s\n",
                 regex_text, error_message);
        return 1;
    }
    return 0;
}

/*
  Match the string in "to_match" against the compiled regular
  expression in "r".
 */

static int match_regex (regex_t * r, const char * to_match)
{
    /* "P" is a pointer into the string which points to the end of the
       previous match. */
    const char * p = to_match;
    /* "N_matches" is the maximum number of matches allowed. */
    const int n_matches = 10;
    /* "M" contains the matches found. */
    regmatch_t m[n_matches];

    while (1) {
        int i = 0;
        int nomatch = regexec (r, p, n_matches, m, 0);
        if (nomatch) {
            printf ("No more matches.\n");
            return nomatch;
        } else {
            return 1;
        }
                
        p += m[0].rm_eo;
    }
    return 0;
}

char *get_mime_type(char *name)
{
  char *ext = strrchr(name, '.');
  if (!ext) return NULL;
  if (strcmp(ext, ".html") == 0 || strcmp(ext, ".htm") == 0) return "text/html";
  if (strcmp(ext, ".jpg") == 0 || strcmp(ext, ".jpeg") == 0) return "image/jpeg";
  if (strcmp(ext, ".gif") == 0) return "image/gif";
  if (strcmp(ext, ".png") == 0) return "image/png";
  if (strcmp(ext, ".css") == 0) return "text/css";
  if (strcmp(ext, ".au") == 0) return "audio/basic";
  if (strcmp(ext, ".wav") == 0) return "audio/wav";
  if (strcmp(ext, ".avi") == 0) return "video/x-msvideo";
  if (strcmp(ext, ".mpeg") == 0 || strcmp(ext, ".mpg") == 0) return "video/mpeg";
  if (strcmp(ext, ".mp3") == 0) return "audio/mpeg";
  return NULL;
}

int strcicmp(char const *a, char const *b)
{
    for (;; a++, b++) {
        int d = tolower(*a) - tolower(*b);
        if (d != 0 || !*a)
            return d;
    }
}

// You must free the result if result is non-NULL.
char *str_replace(char *orig, char *rep, char *with) {
    char *result; // the return string
    char *ins;    // the next insert point
    char *tmp;    // varies
    int len_rep;  // length of rep
    int len_with; // length of with
    int len_front; // distance between rep and end of last rep
    int count;    // number of replacements

    if (!orig)
        return NULL;
    if (!rep)
        rep = "";
    len_rep = strlen(rep);
    if (!with)
        with = "";
    len_with = strlen(with);

    ins = orig;
    for (count = 0; tmp = strstr(ins, rep); ++count) {
        ins = tmp + len_rep;
    }

    // first time through the loop, all the variable are set correctly
    // from here on,
    //    tmp points to the end of the result string
    //    ins points to the next occurrence of rep in orig
    //    orig points to the remainder of orig after "end of rep"
    tmp = result = malloc(strlen(orig) + (len_with - len_rep) * count + 1);

    if (!result)
        return NULL;

    while (count--) {
        ins = strstr(orig, rep);
        len_front = ins - orig;
        tmp = strncpy(tmp, orig, len_front) + len_front;
        tmp = strcpy(tmp, with) + len_with;
        orig += len_front + len_rep; // move to next "end of rep"
    }
    strcpy(tmp, orig);
    return result;
}

void send_headers(FILE *f, int status, char *title, char *extra, char *mime, 
                  int length, time_t date)
{
  time_t now;
  char timebuf[128];

  fprintf(f, "%s %d %s\r\n", PROTOCOL, status, title);
  fprintf(f, "Server: %s\r\n", SERVER);
  now = time(NULL);
  strftime(timebuf, sizeof(timebuf), RFC1123FMT, gmtime(&now));
  fprintf(f, "Date: %s\r\n", timebuf);
  if (extra) fprintf(f, "%s\r\n", extra);
  if (mime) fprintf(f, "Content-Type: %s\r\n", mime);
  if (length >= 0) fprintf(f, "Content-Length: %d\r\n", length);
  if (date != -1)
  {
    strftime(timebuf, sizeof(timebuf), RFC1123FMT, gmtime(&date));
    fprintf(f, "Last-Modified: %s\r\n", timebuf);
  }
  fprintf(f, "Connection: close\r\n");
  fprintf(f, "\r\n");
}

void send_error(FILE *f, int status, char *title, char *extra, char *text)
{
  send_headers(f, status, title, extra, "text/html", -1, -1);
  fprintf(f, "<HTML><HEAD><TITLE>%d %s</TITLE></HEAD>\r\n", status, title);
  fprintf(f, "<BODY><H4>%d %s</H4>\r\n", status, title);
  fprintf(f, "%s\r\n", text);
  fprintf(f, "</BODY></HTML>\r\n");
}

char* readFile(char* filename)
{
    FILE* file = fopen(filename,"r");
    if(file == NULL)
    {
        return NULL;
    }

    fseek(file, 0, SEEK_END);
    long int size = ftell(file);
    rewind(file);

    char* content = calloc(size + 1, 1);

    fread(content,1,size,file);

    return content;
}

void send_index_page(FILE *f, int status, char *title, char *extra, char *text, char *link)
{
  char cwd[1024];
  
  // Get current directory
  getcwd(cwd, sizeof(cwd));
  
  send_headers(f, status, title, extra, "text/html", -1, -1);
  // fprintf(f, "\r\n");
  
  char * data = readFile("wizard.html");
  
  char * result = str_replace(data, "<<destination_url>>", link);
  
  fputs(result, f);
}

void send_json(FILE *f, int status, char *title, char *extra, char *text)
{
  send_headers(f, status, title, extra, "application/json", -1, -1);
  fprintf(f, "%s\r\n", text);
}

void send_text(FILE *f, int status, char *title, char *extra, char *text)
{
  send_headers(f, status, title, extra, "text/plain", -1, -1);
  fprintf(f, "%s\r\n", text);
}

void send_file(FILE *f, char *path, struct stat *statbuf)
{
  char data[4096];
  int n;

  FILE *file = fopen(path, "r");
  if (!file)
    send_error(f, 403, "Forbidden", NULL, "Access denied.");
  else
  {
    int length = S_ISREG(statbuf->st_mode) ? statbuf->st_size : -1;
    send_headers(f, 200, "OK", NULL, get_mime_type(path), length, statbuf->st_mtime);

    while ((n = fread(data, 1, sizeof(data), file)) > 0) fwrite(data, 1, n, f);
    fclose(file);
  }
}

int process(FILE *f)
{
  char buf[4096];
  char *method;
  char *path;
  char *protocol;
  struct stat statbuf;
  char pathbuf[4096];
  int len;

  if (!fgets(buf, sizeof(buf), f)) return -1;
  printf("URL: %s", buf);

  method = strtok(buf, " ");
  path = strtok(NULL, " ");
  protocol = strtok(NULL, "\r");
  if (!method || !path || !protocol) return -1;

  fseek(f, 0, SEEK_CUR); // Force change of stream direction

  if (strcasecmp(method, "GET") != 0)
    send_error(f, 501, "Not supported", NULL, "Method is not supported.");
  else if (stat(path, &statbuf) < 0)
    send_error(f, 404, "Not Found", NULL, "File not found.");
  else if (S_ISDIR(statbuf.st_mode))
  {
    len = strlen(path);
    if (len == 0 || path[len - 1] != '/')
    {
      snprintf(pathbuf, sizeof(pathbuf), "Location: %s/", path);
      send_error(f, 302, "Found", pathbuf, "Directories must end with a slash.");
    }
    else
    {
      snprintf(pathbuf, sizeof(pathbuf), "%sindex.html", path);
      if (stat(pathbuf, &statbuf) >= 0)
        send_file(f, pathbuf, &statbuf);
      else
      {
        DIR *dir;
        struct dirent *de;

        send_headers(f, 200, "OK", NULL, "text/html", -1, statbuf.st_mtime);
        fprintf(f, "<HTML><HEAD><TITLE>Index of %s</TITLE></HEAD>\r\n<BODY>", path);
        fprintf(f, "<H4>Index of %s</H4>\r\n<PRE>\n", path);
        fprintf(f, "Name                             Last Modified              Size\r\n");
        fprintf(f, "<HR>\r\n");
        if (len > 1) fprintf(f, "<A HREF=\"..\">..</A>\r\n");

        dir = opendir(path);
        while ((de = readdir(dir)) != NULL)
        {
          char timebuf[32];
          struct tm *tm;

          strcpy(pathbuf, path);
          strcat(pathbuf, de->d_name);

          stat(pathbuf, &statbuf);
          tm = gmtime(&statbuf.st_mtime);
          strftime(timebuf, sizeof(timebuf), "%d-%b-%Y %H:%M:%S", tm);

          fprintf(f, "<A HREF=\"%s%s\">", de->d_name, S_ISDIR(statbuf.st_mode) ? "/" : "");
          fprintf(f, "%s%s", de->d_name, S_ISDIR(statbuf.st_mode) ? "/</A>" : "</A> ");
          if (strlen(de->d_name) < 32) fprintf(f, "%*s", (int) (32 - strlen(de->d_name)), "");
          if (S_ISDIR(statbuf.st_mode))
            fprintf(f, "%s\r\n", timebuf);
          else
            fprintf(f, "%s %10d\r\n", timebuf, (int) statbuf.st_size);
        }
        closedir(dir);

        fprintf(f, "</PRE>\r\n<HR>\r\n<ADDRESS>%s</ADDRESS>\r\n</BODY></HTML>\r\n", SERVER);
      }
    }
  }
  else
    send_file(f, path, &statbuf);

  return 0;
}

int process_request(FILE *f, int s)
{
  char buf[4096];
  char *method;
  char *path;
  char *protocol;
  struct stat statbuf;
  char pathbuf[4096];
  int len;

  if (!fgets(buf, sizeof(buf), f)) return -1;
  printf("URL: %s", buf);

  method = strtok(buf, " ");
  path = strtok(NULL, " ");
  protocol = strtok(NULL, "\r");
  if (!method || !path || !protocol) return -1;

  fseek(f, 0, SEEK_CUR); // Force change of stream direction

  char url[7];
  
  sprintf(url, "%.*s", 7, path); 

  if (strcasecmp(method, "GET") != 0)
    send_error(f, 501, "Not supported", NULL, "Method is not supported.");
  else {
    
    if(strcicmp(path, "/weight") == 0){
        
        char value[255];
        
        sprintf(value, "%f", weight);
        
        send_text(f, 200, "OK", NULL, value);
        
        printf("Get weight\n");
    
    } else if(strcicmp(path, "/height") == 0){
    
        char value[255];
        
        sprintf(value, "%f", height);
        
        send_text(f, 200, "OK", NULL, value);
        
        printf("Get height\n");
    
    } else if(strcicmp(path, "/status") == 0 && bp_dev){
    
        char value[6];
        
        bp_res=write(bp_fd,bp,16);
        
        if(bp_res==-1) {
		    printf("ERROR: Failed to CHECK status\n");
	    } else {
	         
            if( bp_fd == -1 ) error("serial port not opened");
            memset(bp_buf,0,bp_buf_max);  // 
            serialport_read_until(bp_fd, bp_buf, bp_eolchar, bp_buf_max, bp_timeout);
        
	        printf("%s\n", bp_buf);
	        
	        int reading;
	        
            sscanf(bp_buf, "%*30c%3d", &reading);
        
            if(reading == 0){
                sprintf(value, "true");
            } else {
                sprintf(value, "false");
            }
        
	        printf("Status Read!\n");
	    }           
        
        send_text(f, 200, "OK", NULL, value);
    
        printf("Checked status\n");    
    
    } else if(strcicmp(path, "/read") == 0 && bp_dev){
                
        int year;
        int month;
        int day;
        int hour;
        int minute;

        int systolic;
        int diastolic;
        int mean_bp;
        int pulse_rate;
        int inflation_pressure;
        int max_pulse_pressure;

        char value[1024];
        
        printf("Read BP\n");             
        
        bp_res=write(bp_fd,bp,16);
        
        if(bp_res==-1) {
		    printf("ERROR: Failed READING BP\n");
	    } else {
	         
            if( bp_fd == -1 ) error("serial port not opened");
            memset(bp_buf,0,bp_buf_max);  // 
            serialport_read_until(bp_fd, bp_buf, bp_eolchar, bp_buf_max, bp_timeout);
        
	        printf("%s\n", bp_buf);
	        
            sscanf(bp_buf, "%*13c%02d%02d%02d%02d%02d%*11c%3d%*2c%3d%*2c%3d%*2c%3d%*2c%2d%*2c%3d", 
                &year, &month, &day, &hour, &minute, &systolic, &mean_bp, &diastolic, &pulse_rate, &inflation_pressure, &max_pulse_pressure);
        
            sprintf(value, "{\"date\":\"%d-%d-%d %d:%d\",\"systolic pressure\":\"%d\",\"diastolic pressure\":\"%d\",\"mean bp\":\"%d\",\"pulse rate\":\"%d\",\"inflation pressure\":\"%d\",\"max pulse pressure\":\"%d\"}", year, month, day, hour, minute, systolic, diastolic, mean_bp, pulse_rate, inflation_pressure, max_pulse_pressure);
        
	        printf("BP Read!\n");
	    }           
        
        send_json(f, 200, "OK", NULL, value);
        
        printf("Get bp\n");
    
    } else if(strcicmp(path, "/bpstart") == 0 && bp_dev){
    
        char value[255];
        
        printf("Start BP Machine\n");            

        bp_res=write(bp_fd,start,16);

        if(bp_res==-1) {
        
            sprintf(value, "{\"error\":\"Failed STARTING\"}");
        
            printf("ERROR: Failed STARTING\n");
        } else {
            
            if( bp_fd == -1 ) error("serial port not opened");
            memset(bp_buf,0,bp_buf_max);  // 
            serialport_read_until(bp_fd, bp_buf, bp_eolchar, bp_buf_max, bp_timeout);

            sprintf(value, "{\"result\":\"OK\"}");
        
            printf("%s\n", bp_buf);
            
            printf("Started!\n");
        }
		
        send_json(f, 200, "OK", NULL, value);
        
    } else if(strcicmp(path, "/bpstop") == 0 && bp_dev){
    
        char value[255];
        
        printf("Stop BP Machine\n");            

        bp_res=write(bp_fd,stop,16);

        if(bp_res==-1) {
        
            sprintf(value, "{\"error\":\"Failed STOPPING\"}");
        
            printf("ERROR: Failed STOPPING\n");
        } else {
            
            if( bp_fd == -1 ) error("serial port not opened");
            memset(bp_buf,0,bp_buf_max);  // 
            serialport_read_until(bp_fd, bp_buf, bp_eolchar, bp_buf_max, bp_timeout);

            sprintf(value, "{\"result\":\"OK\"}");
        
            printf("%s\n", bp_buf);
            
            printf("Stopped!\n");
        }
		
        send_json(f, 200, "OK", NULL, value);
        
    } else if(strcicmp(path, "/pulse") == 0 && bp_dev){
    
        char value[1024];
        
        printf("Read pulse\n");            

        bp_res=write(bp_fd,pulse,16);

        if(bp_res==-1) {
        
            sprintf(value, "{\"error\":\"Failed reading pulse\"}");
        
            printf("ERROR: Failed reading pulse\n");
        } else {
            
            if( bp_fd == -1 ) error("serial port not opened");
            memset(bp_buf,0,bp_buf_max);  // 
            serialport_read_until(bp_fd, bp_buf, bp_eolchar, bp_buf_max, bp_timeout);

            int count;
            
            char * cmd;
            
            sscanf(bp_buf, "%*28c%3d", &count);
            
            printf("Got %d\n", count);
            
            int i;
            
            int result[count][2];
            
            char string[1024] = "[";
        
            for(i = 0; i < count; i++){            
                int col, row;
                
                sscanf(("%d : %.*s\n", i, 7, bp_buf + 32 + (i * 7) + i), "%3d%*c%3d", &col, &row);
                
                result[i][0] = row;
                result[i][1] = col;
                char substr[10];
                
                if(strlen(string) > 1){
                    
                    sprintf(substr, ",[%d,%d]", row, col);
                
                } else {
                
                    sprintf(substr, "[%d,%d]", row, col);
                
                }
                
                strcat(string, substr);                
            }
            
            strcat(string, "]");
                
            printf("%s\n", string);
        
            sprintf(value, "{\"result\":%s}", string);
        
            printf("%s\n", bp_buf);
            
            printf("Pulse read!\n");
        }
		
        send_json(f, 200, "OK", NULL, value);
        
        printf("Get pulse\n");
    
    } else if(strcicmp(url, "/vitals") == 0){
        
        char * str1 = strstr ( path, "destination=" );

        char link[255];
        
        sprintf(link, "%.*s", (int)(strlen(str1) - strlen("destination=")), str1 + strlen("destination="));
    
        printf("%s\n", link);

        send_index_page(f, 200, "OK", NULL, "", link);
         
    } else {
        send_error(f, 404, "Resource Not Found", NULL, "Resource not found.");
    }
    
  }
  
  return 0;
}

void usage(int argc,char* argv[]) {
	fprintf(stderr,"%s: -s [scale device] -b [bp device]\n",argv[0]);
	exit(1);
}

int main(int argc, char *argv[])
{
  
    // Start SCALE variables
    int scale_fd,scale_c,scale_res;
    struct termios scale_oldtio,scale_newtio;
    char scale_buf[255];
    char *scale_dev,*scale_ph,*scale_msg;
    // End SCALE variables

    scale_dev=scale_ph=scale_msg=NULL;
    
	bp_dev=bp_ph=bp_msg=NULL;
	
    for(scale_c=0;scale_c<argc;scale_c++) {
        if(argv[scale_c][0]=='-')
        switch(argv[scale_c][1]) {
            case 'b':
	            bp_dev=argv[++scale_c];
	            break;
            case 's':
	            scale_dev=argv[++scale_c];
	            break;
            default:
	            usage(argc,argv);
	            break;
        }
    }

    if(!scale_dev && !bp_dev) usage(argc,argv);

    if(scale_dev){
	    printf("DEBUG: Initialising scale device on %s\n",scale_dev);
	    scale_fd = open(scale_dev, O_RDWR | O_NOCTTY ); 
	    if (scale_fd <0) {perror(scale_dev); exit(-1); }
          
	    tcgetattr(scale_fd,&scale_oldtio);
	    bzero(&scale_newtio, sizeof(scale_newtio));

	    scale_newtio.c_cflag = BAUDRATE | CRTSCTS | CS8 | CLOCAL | CREAD;
	    scale_newtio.c_iflag = IGNPAR | ICRNL;         
	    scale_newtio.c_oflag = 0;
             
	    tcflush(scale_fd, TCIFLUSH);
	    tcsetattr(scale_fd,TCSANOW,&scale_newtio);
           
        memset (&bp_buf, '\0', sizeof bp_buf);
    }
    
    if(bp_dev){
            
	    printf("DEBUG: Initialising bp device on %s\n",bp_dev);
	
	    bp_fd = serialport_init(bp_dev, bp_baudrate);
         
    }
    
    int sock;
    struct sockaddr_in sin;

    sock = socket(AF_INET, SOCK_STREAM, 0);

    sin.sin_family = AF_INET;
    sin.sin_addr.s_addr = INADDR_ANY;
    sin.sin_port = htons(PORT);
    bind(sock, (struct sockaddr *) &sin, sizeof(sin));

    listen(sock, 5);
    printf("HTTP server listening on port %d\n", PORT);

    regex_t r;
    const char * regex_text = "W([[:digit:]]+[[:punct:]][[:digit:]]+)[^[:print:]]H([[:digit:]]+[[:punct:]][[:digit:]]+)[^[:print:]]B([[:digit:]]+[[:punct:]][[:digit:]]+)";
    
    while (1)
    {
        int s;
        FILE *f;

        s = accept(sock, NULL, NULL);
        if (s < 0) break;

        f = fdopen(s, "a+");
        process_request(f, s);
        fclose(f);        
        
        if(scale_dev){
		    usleep(1000000);

		    scale_res=read(scale_fd,scale_buf,255); 

		    scale_buf[scale_res]=0;
		    // printf("%s\n",scale_buf);
		    compile_regex(& r, regex_text);
	
            int scale_matched = match_regex(& r, scale_buf);
            regfree (& r);

            if(scale_matched == 1){
                sscanf(scale_buf, "%*cR%*cI0000000000%*cW%f%*cH%f%*cB%f", &weight, &height, &bmi);
            }
        }

    }

    close(sock);
    return 0;
}

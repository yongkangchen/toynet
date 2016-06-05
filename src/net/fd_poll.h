#ifndef fd_poll_h
#define fd_poll_h

#include <stdbool.h>
#include <time.h>

struct event {
	int fd;
	bool read;
	bool write;
};

int poll_create();
void poll_close(int poll_fd);

int poll_add(int poll_fd, int fd);
void poll_del(int poll_fd, int fd);
int poll_mod(int poll_fd, int fd, bool read_enable, bool write_enable);
int poll_wait(int poll_fd, time_t timeout, struct event *fired, int max);

#endif
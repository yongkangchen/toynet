#ifndef fd_poll_h
#define fd_poll_h

#include <stddef.h>
#include <sys/types.h>

int tcp_listen(const char* host, int port, int backlog);
int tcp_accept(int listenfd, char* ip, size_t ip_len, int *port);

int tcp_close(int fd);
int tcp_connect(const char* host, int port);

int tcp_nonblock(int fd, int non_block);
int tcp_keepalive(int fd, int val);
int tcp_nodelay(int fd, int val);
ssize_t tcp_read(int fd, void* buf, size_t count);
ssize_t tcp_write(int fd, const void* buf, size_t count);
#endif
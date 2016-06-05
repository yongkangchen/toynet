#include "tcp.h"

#include <sys/socket.h>
#include <netinet/tcp.h>
#include <netdb.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <stdio.h>
#include <string.h>
#include <fcntl.h>
#include <errno.h>

int tcp_nonblock(int fd, int non_block)
{
    int flags = fcntl(fd, F_GETFL, 0);
    if(flags == -1) return -1;
	if(non_block){
		flags |= O_NONBLOCK;
	}else{
		flags &= ~O_NONBLOCK;
	}
    if(fcntl(fd, F_SETFL, flags) == -1) return -1;
	return 0;
}

int tcp_nodelay(int fd, int val)
{
    if(setsockopt(fd, IPPROTO_TCP, TCP_NODELAY, &val, sizeof(val)) == -1){
        return -1;
    }
    return 0;
}

int tcp_keepalive(int fd, int val)
{
	if(setsockopt(fd, SOL_SOCKET, SO_KEEPALIVE, &val, sizeof(val)) == -1){
		return -1;
	}
	return 0;
}

int tcp_close(int fd)
{
    return close(fd);    
}

int tcp_accept(int listenfd, char* ip, size_t ip_len, int *port)
{
	struct sockaddr_storage sa;
    socklen_t len = sizeof(sa);
    int fd = accept(listenfd, (struct sockaddr*)&sa, &len);
    if(fd < 0)
    {
        return -1;
    }
	
	if (sa.ss_family == AF_INET) {
        struct sockaddr_in *s = (struct sockaddr_in *)&sa;
        if (ip) inet_ntop(AF_INET, (void*)&(s->sin_addr), ip, ip_len);
        if (port) *port = ntohs(s->sin_port);
    } else {
        struct sockaddr_in6 *s = (struct sockaddr_in6 *)&sa;
        if (ip) inet_ntop(AF_INET6,(void*)&(s->sin6_addr), ip, ip_len);
        if (port) *port = ntohs(s->sin6_port);
    }
    return fd;
}

int tcp_listen(const char* host, int port, int backlog)
{
	char portstr[16];
    sprintf(portstr, "%d", port);
	
	struct addrinfo ai_hints;
	memset(&ai_hints, 0, sizeof(ai_hints));
	ai_hints.ai_family = AF_UNSPEC;
	ai_hints.ai_socktype = SOCK_STREAM;
	ai_hints.ai_protocol = IPPROTO_TCP;
	
	struct addrinfo *ai_list = NULL;
	int status = getaddrinfo( host, portstr, &ai_hints, &ai_list );
	if(status != 0){
		return -1;
	}
	
    int fd = socket(ai_list->ai_family, ai_list->ai_socktype, 0);
    if(fd < 0){
		freeaddrinfo( ai_list );
        return -2;
    }

    int on = 1;
    if(setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &on, sizeof(on) ) == -1)
    {
        close(fd);
		freeaddrinfo( ai_list );
        return -3;
    }

    if(bind(fd, (struct sockaddr*) ai_list->ai_addr, ai_list->ai_addrlen) != 0){
        close(fd);
		freeaddrinfo( ai_list );
        return -4;
    }
	
	freeaddrinfo( ai_list );

    if(listen(fd, backlog) == -1){
        close(fd);
        return -5;
    }
    return fd;
}

ssize_t tcp_read(int fd, void* buf, size_t count)
{
    ssize_t nread = read(fd, buf, count);
    if(nread == 0) return -1;
    if(nread < 0)
    {
        if(errno == EINTR || errno == EAGAIN) return 0;
        return -1;
    }
    return nread;
}

ssize_t tcp_write(int fd, const void* buf, size_t count)
{
    ssize_t nwrite = write(fd, buf, count);
    if(nwrite == 0)
    {
        return 0;
    }

    if(nwrite < 0)
    {
        if(errno == EINTR || errno == EAGAIN)
        {
            return 0;
        }
        return -1;
    }
    return nwrite;
}

int tcp_connect(const char* host, int port)
{
    int fd = socket(AF_INET,SOCK_STREAM,0);
    if(fd == -1)
    {
        return -1;
    }

    struct sockaddr_in my_addr;

    my_addr.sin_addr.s_addr = inet_addr(host);
    my_addr.sin_family = AF_INET;
    my_addr.sin_port = htons(port);

    if (connect(fd,(struct sockaddr *)&my_addr,sizeof(struct sockaddr_in)) == -1) {
        return -1;
    }
    return fd;
}
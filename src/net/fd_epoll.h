#ifndef fd_epoll_h
#define fd_epoll_h

#include <unistd.h>
#include <sys/epoll.h>

int poll_create() {
	return epoll_create(1024);
}

void poll_close(int poll_fd) {
	close(poll_fd);
}

int poll_add(int poll_fd, int fd) {
	struct epoll_event ee;
	ee.events = EPOLLIN;
	ee.data.fd = fd;
	if (epoll_ctl(poll_fd, EPOLL_CTL_ADD, fd, &ee) == -1) {
		return -1;
	}
	return 0;
}

void poll_del(int poll_fd, int fd) {
	epoll_ctl(poll_fd, EPOLL_CTL_DEL, fd, NULL);
}

int poll_mod(int poll_fd, int fd, bool read_enable, bool write_enable) {
	struct epoll_event ee;
	ee.events = (read_enable? EPOLLIN : 0) | (write_enable ? EPOLLOUT : 0);
	ee.data.fd = fd;
	if(epoll_ctl(poll_fd, EPOLL_CTL_MOD, fd, &ee) == -1){
		return -1;
	}
	return 0;
}

int poll_wait(int poll_fd, time_t timeout, struct event *fired, int max){
	struct epoll_event events[max];
	int numevents = epoll_wait(poll_fd, events, max, timeout);
	
	int i;
	for (i = 0; i < numevents; i++) {
		fired[i].fd = events[i].data.fd;
		unsigned flag = events[i].events;
		fired[i].write = (flag & EPOLLOUT) != 0;
		fired[i].read = (flag & EPOLLIN) != 0;
	}
	return numevents > 0 ? numevents : 0;
}

#endif

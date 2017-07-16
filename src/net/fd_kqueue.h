#ifndef fd_kqueue_h
#define fd_kqueue_h

#include <unistd.h>
#include <sys/event.h>

int poll_create() {
	return kqueue();
}

void poll_close(int poll_fd) {
	close(poll_fd);
}

int poll_add(int poll_fd, int fd) {
	struct kevent ke;
	
	EV_SET(&ke, fd, EVFILT_READ, EV_ADD, 0, 0, NULL);
	if (kevent(poll_fd, &ke, 1, NULL, 0, NULL) == -1) {
		return -1;
	}
	
	EV_SET(&ke, fd, EVFILT_WRITE, EV_ADD, 0, 0, NULL);
	if (kevent(poll_fd, &ke, 1, NULL, 0, NULL) == -1) {
		EV_SET(&ke, fd, EVFILT_READ, EV_DELETE, 0, 0, NULL);
		kevent(poll_fd, &ke, 1, NULL, 0, NULL);
		return 1;
	}
	
	EV_SET(&ke, fd, EVFILT_WRITE, EV_DISABLE, 0, 0, NULL);
	if (kevent(poll_fd, &ke, 1, NULL, 0, NULL) == -1) {
		poll_del(poll_fd, fd);
		return 1;
	}
	return 0;
}

void poll_del(int poll_fd, int fd) {
	struct kevent ke;
	
	EV_SET(&ke, fd, EVFILT_READ, EV_DELETE, 0, 0, NULL);
	kevent(poll_fd, &ke, 1, NULL, 0, NULL);
	
	EV_SET(&ke, fd, EVFILT_WRITE, EV_DELETE, 0, 0, NULL);
	kevent(poll_fd, &ke, 1, NULL, 0, NULL);
}

int poll_mod(int poll_fd, int fd, bool read_enable, bool write_enable) {
	struct kevent ke;
	
	EV_SET(&ke, fd, EVFILT_WRITE, write_enable ? EV_ENABLE : EV_DISABLE, 0, 0, NULL);
	if (kevent(poll_fd, &ke, 1, NULL, 0, NULL) == -1) {
		return -1;
	}
	
	EV_SET(&ke, fd, EVFILT_READ, read_enable ? EV_ENABLE : EV_DISABLE, 0, 0, NULL);
	if (kevent(poll_fd, &ke, 1, NULL, 0, NULL) == -1) {
		return -1;
	}
	return 0;
}

int poll_wait(int poll_fd, time_t timeout, struct event *fired, int max) {
	struct kevent events[max];
	int numevents = 0;
	
	if(timeout >= 0)
	{
		struct timespec timeout_spec;
		timeout_spec.tv_sec = timeout/1000;
		timeout_spec.tv_nsec = 0;
		numevents = kevent(poll_fd, NULL, 0, events, max, &timeout_spec);
	}
	else{
		numevents = kevent(poll_fd, NULL, 0, events, max, NULL);
	}

	int i;
	for (i = 0; i < numevents; i++) {
		fired[i].fd = events[i].ident;
		unsigned filter = events[i].filter;
		fired[i].write = (filter == EVFILT_WRITE);
		fired[i].read = (filter == EVFILT_READ);
	}
	return numevents > 0 ? numevents: 0;
}

#endif

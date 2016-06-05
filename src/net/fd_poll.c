#include "fd_poll.h"

#ifdef __linux__
#include "fd_epoll.h"
#endif

#if defined(__APPLE__) || defined(__FreeBSD__) || defined(__OpenBSD__) || defined (__NetBSD__)
#include "fd_kqueue.h"
#endif

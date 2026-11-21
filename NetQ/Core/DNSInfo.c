#include "DNSInfo.h"
#include <resolv.h>
#include <string.h>
#include <arpa/inet.h>

int netq_dns_server(int index, char *buf, int len) {
    struct __res_state st;
    memset(&st, 0, sizeof st);
    if (res_ninit(&st) != 0) return 0;
    union res_sockaddr_union u[8];
    memset(u, 0, sizeof u);
    int n = res_getservers(&st, u, 8);
    int ok = 0;
    if (index >= 0 && index < n) {
        if (u[index].sin.sin_family == AF_INET)
            ok = inet_ntop(AF_INET, &u[index].sin.sin_addr, buf, len) != NULL;
        else if (u[index].sin6.sin6_family == AF_INET6)
            ok = inet_ntop(AF_INET6, &u[index].sin6.sin6_addr, buf, len) != NULL;
    }
    res_nclose(&st);
    return ok;
}

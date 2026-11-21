#ifndef DNSInfo_h
#define DNSInfo_h
/// Writes the index-th system DNS resolver address into buf. Returns 1 on success, 0 otherwise.
int netq_dns_server(int index, char *buf, int len);
#endif

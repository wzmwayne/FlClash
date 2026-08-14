#include "libclash_bridge.h"

void (*result_func)(void *invoke_Interface, const char *data);
void (*release_object_func)(void *obj);
void (*free_string_func)(char *data);
void (*protect_func)(void *tun_interface, int fd);
char *(*resolve_process_func)(void *tun_interface, int protocol, const char *source, const char *target, int uid);

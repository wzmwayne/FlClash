#ifndef LIBCLASH_BRIDGE_H
#define LIBCLASH_BRIDGE_H

#ifdef __cplusplus
extern "C" {
#endif

extern void (*result_func)(void *invoke_Interface, const char *data);
extern void (*release_object_func)(void *obj);
extern void (*free_string_func)(char *data);
extern void (*protect_func)(void *tun_interface, int fd);
extern char *(*resolve_process_func)(void *tun_interface, int protocol, const char *source, const char *target, int uid);

#ifdef __cplusplus
}
#endif

#endif

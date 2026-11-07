/* What a program sees of the files in GNOME's thumbnail sandbox, without one.

   LD_PRELOADed by tools/release/bwrap_standin.py into the thumbnailer and
   everything it runs. SANDBOX_VIEW is a colon-separated list of the paths
   the sandbox has (bwrap's binds, /proc, /dev, and the package where it
   stands in for /usr); a file outside them is not there, as in the
   sandbox's own filesystem: opening, listing, reading the link of or
   asking about it fails with ENOENT. The folders above a path the sandbox
   has can be looked at, as the way to it.

   It covers the C library's calls a program makes: what the library does
   inside itself (its own name lookups, say) it does unseen, so
   tools/release/thumbnail_check.py --trace follows the run with strace and
   names whatever still got through.

     cc -shared -fPIC -O2 -o sandbox_view.so sandbox_view.c -ldl
*/
#define _GNU_SOURCE
#include <dirent.h>
#include <dlfcn.h>
#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/statfs.h>
#include <sys/statvfs.h>
#include <sys/syscall.h>
#include <unistd.h>

static int is_seen(const char *given, int dirfd) {
    const char *view = getenv("SANDBOX_VIEW");
    if (!view || !given) return 1;
    char joined[PATH_MAX * 2];
    if (given[0] == '/') {
        snprintf(joined, sizeof joined, "%s", given);
    } else {
        char base[PATH_MAX];
        if (dirfd != AT_FDCWD && dirfd >= 0) {
            char link[64];
            snprintf(link, sizeof link, "/proc/self/fd/%d", dirfd);
            ssize_t n = syscall(SYS_readlink, link, base, sizeof base - 1);
            if (n <= 0) return 1;
            base[n] = 0;
        } else if (!getcwd(base, sizeof base)) {
            return 1;
        }
        snprintf(joined, sizeof joined, "%s/%s", base, given);
    }
    /* Made plain: no "//", ".", "..". Links are left as they are. */
    char path[PATH_MAX * 2];
    size_t at = 0;
    const char *p = joined;
    while (*p) {
        while (*p == '/') p++;
        if (!*p) break;
        const char *end = strchr(p, '/');
        size_t len = end ? (size_t)(end - p) : strlen(p);
        if (len == 1 && p[0] == '.') {
        } else if (len == 2 && p[0] == '.' && p[1] == '.') {
            while (at > 0 && path[at - 1] != '/') at--;
            if (at > 0) at--;
        } else if (at + len + 2 < sizeof path) {
            path[at++] = '/';
            memcpy(path + at, p, len);
            at += len;
        }
        p += len;
    }
    path[at] = 0;
    if (at == 0) return 1;
    const char *place = view;
    while (*place) {
        const char *end = strchr(place, ':');
        size_t len = end ? (size_t)(end - place) : strlen(place);
        while (len > 1 && place[len - 1] == '/') len--;
        if (len > 0) {
            /* In it, or on the way to it. */
            if (strncmp(path, place, len) == 0 && (path[len] == 0 || path[len] == '/'))
                return 1;
            if (at < len && strncmp(place, path, at) == 0 && place[at] == '/') return 1;
        }
        if (!end) break;
        place = end + 1;
    }
    return 0;
}

#define REAL(name) static __typeof__(name) *real_##name; \
    if (!real_##name) real_##name = (__typeof__(name) *)dlsym(RTLD_NEXT, #name)

static int mode_of(int flags, va_list rest) {
    return (flags & O_CREAT) || (flags & __O_TMPFILE) == __O_TMPFILE ? va_arg(rest, int) : 0;
}

int open(const char *path, int flags, ...) {
    REAL(open);
    va_list rest; va_start(rest, flags); int mode = mode_of(flags, rest); va_end(rest);
    if (!is_seen(path, AT_FDCWD)) { errno = ENOENT; return -1; }
    return real_open(path, flags, mode);
}
int open64(const char *path, int flags, ...) {
    REAL(open64);
    va_list rest; va_start(rest, flags); int mode = mode_of(flags, rest); va_end(rest);
    if (!is_seen(path, AT_FDCWD)) { errno = ENOENT; return -1; }
    return real_open64(path, flags, mode);
}
int openat(int dirfd, const char *path, int flags, ...) {
    REAL(openat);
    va_list rest; va_start(rest, flags); int mode = mode_of(flags, rest); va_end(rest);
    if (!is_seen(path, dirfd)) { errno = ENOENT; return -1; }
    return real_openat(dirfd, path, flags, mode);
}
int openat64(int dirfd, const char *path, int flags, ...) {
    REAL(openat64);
    va_list rest; va_start(rest, flags); int mode = mode_of(flags, rest); va_end(rest);
    if (!is_seen(path, dirfd)) { errno = ENOENT; return -1; }
    return real_openat64(dirfd, path, flags, mode);
}
int __open_2(const char *path, int flags) {
    REAL(__open_2);
    if (!is_seen(path, AT_FDCWD)) { errno = ENOENT; return -1; }
    return real___open_2(path, flags);
}
int __open64_2(const char *path, int flags) {
    REAL(__open64_2);
    if (!is_seen(path, AT_FDCWD)) { errno = ENOENT; return -1; }
    return real___open64_2(path, flags);
}
int __openat_2(int dirfd, const char *path, int flags) {
    REAL(__openat_2);
    if (!is_seen(path, dirfd)) { errno = ENOENT; return -1; }
    return real___openat_2(dirfd, path, flags);
}
FILE *fopen(const char *path, const char *mode) {
    REAL(fopen);
    if (!is_seen(path, AT_FDCWD)) { errno = ENOENT; return NULL; }
    return real_fopen(path, mode);
}
FILE *fopen64(const char *path, const char *mode) {
    REAL(fopen64);
    if (!is_seen(path, AT_FDCWD)) { errno = ENOENT; return NULL; }
    return real_fopen64(path, mode);
}
FILE *freopen(const char *path, const char *mode, FILE *stream) {
    REAL(freopen);
    if (path && !is_seen(path, AT_FDCWD)) { errno = ENOENT; return NULL; }
    return real_freopen(path, mode, stream);
}
DIR *opendir(const char *path) {
    REAL(opendir);
    if (!is_seen(path, AT_FDCWD)) { errno = ENOENT; return NULL; }
    return real_opendir(path);
}
int stat(const char *path, struct stat *out) {
    REAL(stat);
    if (!is_seen(path, AT_FDCWD)) { errno = ENOENT; return -1; }
    return real_stat(path, out);
}
int lstat(const char *path, struct stat *out) {
    REAL(lstat);
    if (!is_seen(path, AT_FDCWD)) { errno = ENOENT; return -1; }
    return real_lstat(path, out);
}
int stat64(const char *path, struct stat64 *out) {
    REAL(stat64);
    if (!is_seen(path, AT_FDCWD)) { errno = ENOENT; return -1; }
    return real_stat64(path, out);
}
int lstat64(const char *path, struct stat64 *out) {
    REAL(lstat64);
    if (!is_seen(path, AT_FDCWD)) { errno = ENOENT; return -1; }
    return real_lstat64(path, out);
}
int fstatat(int dirfd, const char *path, struct stat *out, int flags) {
    REAL(fstatat);
    if (path[0] && !is_seen(path, dirfd)) { errno = ENOENT; return -1; }
    return real_fstatat(dirfd, path, out, flags);
}
int fstatat64(int dirfd, const char *path, struct stat64 *out, int flags) {
    REAL(fstatat64);
    if (path[0] && !is_seen(path, dirfd)) { errno = ENOENT; return -1; }
    return real_fstatat64(dirfd, path, out, flags);
}
int statx(int dirfd, const char *path, int flags, unsigned int mask, struct statx *out) {
    REAL(statx);
    if (path[0] && !is_seen(path, dirfd)) { errno = ENOENT; return -1; }
    return real_statx(dirfd, path, flags, mask, out);
}
int access(const char *path, int mode) {
    REAL(access);
    if (!is_seen(path, AT_FDCWD)) { errno = ENOENT; return -1; }
    return real_access(path, mode);
}
int faccessat(int dirfd, const char *path, int mode, int flags) {
    REAL(faccessat);
    if (!is_seen(path, dirfd)) { errno = ENOENT; return -1; }
    return real_faccessat(dirfd, path, mode, flags);
}
ssize_t readlink(const char *path, char *out, size_t size) {
    REAL(readlink);
    if (!is_seen(path, AT_FDCWD)) { errno = ENOENT; return -1; }
    return real_readlink(path, out, size);
}
ssize_t readlinkat(int dirfd, const char *path, char *out, size_t size) {
    REAL(readlinkat);
    if (!is_seen(path, dirfd)) { errno = ENOENT; return -1; }
    return real_readlinkat(dirfd, path, out, size);
}
char *realpath(const char *path, char *out) {
    REAL(realpath);
    if (!is_seen(path, AT_FDCWD)) { errno = ENOENT; return NULL; }
    return real_realpath(path, out);
}
int mkdir(const char *path, mode_t mode) {
    REAL(mkdir);
    if (!is_seen(path, AT_FDCWD)) { errno = ENOENT; return -1; }
    return real_mkdir(path, mode);
}
int execve(const char *path, char *const argv[], char *const envp[]) {
    REAL(execve);
    if (!is_seen(path, AT_FDCWD)) { errno = ENOENT; return -1; }
    return real_execve(path, argv, envp);
}

/* The stat calls of a program built against a C library older than 2.33,
   as Godot's export templates are (they name glibc 2.28). */
int __xstat(int ver, const char *path, struct stat *out) {
    REAL(__xstat);
    if (!is_seen(path, AT_FDCWD)) { errno = ENOENT; return -1; }
    return real___xstat(ver, path, out);
}
int __xstat64(int ver, const char *path, struct stat64 *out) {
    REAL(__xstat64);
    if (!is_seen(path, AT_FDCWD)) { errno = ENOENT; return -1; }
    return real___xstat64(ver, path, out);
}
int __lxstat(int ver, const char *path, struct stat *out) {
    REAL(__lxstat);
    if (!is_seen(path, AT_FDCWD)) { errno = ENOENT; return -1; }
    return real___lxstat(ver, path, out);
}
int __lxstat64(int ver, const char *path, struct stat64 *out) {
    REAL(__lxstat64);
    if (!is_seen(path, AT_FDCWD)) { errno = ENOENT; return -1; }
    return real___lxstat64(ver, path, out);
}
int __fxstatat(int ver, int dirfd, const char *path, struct stat *out, int flags) {
    REAL(__fxstatat);
    if (path[0] && !is_seen(path, dirfd)) { errno = ENOENT; return -1; }
    return real___fxstatat(ver, dirfd, path, out, flags);
}
int __fxstatat64(int ver, int dirfd, const char *path, struct stat64 *out, int flags) {
    REAL(__fxstatat64);
    if (path[0] && !is_seen(path, dirfd)) { errno = ENOENT; return -1; }
    return real___fxstatat64(ver, dirfd, path, out, flags);
}
int statfs(const char *path, struct statfs *out) {
    REAL(statfs);
    if (!is_seen(path, AT_FDCWD)) { errno = ENOENT; return -1; }
    return real_statfs(path, out);
}
int statfs64(const char *path, struct statfs64 *out) {
    REAL(statfs64);
    if (!is_seen(path, AT_FDCWD)) { errno = ENOENT; return -1; }
    return real_statfs64(path, out);
}
int statvfs(const char *path, struct statvfs *out) {
    REAL(statvfs);
    if (!is_seen(path, AT_FDCWD)) { errno = ENOENT; return -1; }
    return real_statvfs(path, out);
}
int statvfs64(const char *path, struct statvfs64 *out) {
    REAL(statvfs64);
    if (!is_seen(path, AT_FDCWD)) { errno = ENOENT; return -1; }
    return real_statvfs64(path, out);
}

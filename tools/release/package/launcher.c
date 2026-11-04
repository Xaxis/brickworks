// The first program a Mac runs of Brickworks.app: it chooses how the app
// draws, then becomes the app (Contents/MacOS/Brickworks, Godot) in the same
// process, so the files Launch Services asks it to open still reach it.
//
// An Intel Mac draws Brickworks through Vulkan on MoltenVK. On a GPU MoltenVK
// cannot use, it does not fail, it aborts: Apple's paravirtual GPU (every
// macOS VM on an Intel host, GitHub's macos-15-intel among them) ended the
// app inside vkCreateInstance, in Metal's newArgumentEncoderWithArguments,
// and with argument buffers off it could not make a buffer of 256 KB. Godot
// falls back to OpenGL only when Vulkan reports an error, so the app closed
// at once with nothing said. On OpenGL the same Mac opens it.
//
// So before Vulkan starts this asks Metal what the GPU is, which creates no
// Vulkan instance, and on a GPU the full renderer cannot run on it starts the
// app on OpenGL (Godot's Compatibility renderer, the one the web build uses),
// saying why in BRICKWORKS_GRAPHICS for the app to tell the person
// (GraphicsMode). Apple silicon draws through Metal itself, paravirtual or
// not, and is left alone.
//
// Not when the person has chosen (Settings, Graphics writes graphics.cfg,
// which Godot reads itself), or names a renderer on the command line.
//
// Built by tools/release.py with zig for both architectures. It links only
// libSystem: Metal and the Objective-C runtime are opened when it runs.
#include <dlfcn.h>
#include <mach-o/dyld.h>
#include <mach/machine.h>
#include <spawn.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

extern char **environ;

// Less than this to work with and Forward+ runs out. Every Mac with a GPU of
// its own, or Intel graphics sharing the Mac's memory, reports a gigabyte or
// more; so does the paravirtual one (1024 MB, though System Information says
// 64 MB of VRAM), which is known by its name.
#define LEAST_WORKING_SET (256ull << 20)

typedef void *id;
typedef void *SEL;

// Why the full renderer cannot run here, or "" when it can.
static void judge(char *why, size_t room) {
    why[0] = 0;
#if !defined(__x86_64__)
    (void)room;
#else
    void *metal = dlopen("/System/Library/Frameworks/Metal.framework/Metal", RTLD_LAZY);
    void *objc = dlopen("/usr/lib/libobjc.A.dylib", RTLD_LAZY);
    id (*create)(void) = metal ? (id (*)(void))dlsym(metal, "MTLCreateSystemDefaultDevice") : NULL;
    void *send = objc ? dlsym(objc, "objc_msgSend") : NULL;
    SEL (*selector)(const char *) = objc ? (SEL (*)(const char *))dlsym(objc, "sel_registerName") : NULL;
    if (!create || !send || !selector) {
        snprintf(why, room, "this Mac has no Metal");
        return;
    }
    id device = create();
    if (!device) {
        snprintf(why, room, "this Mac has no Metal GPU");
        return;
    }
    id (*send_id)(id, SEL) = (id (*)(id, SEL))send;
    const char *(*send_text)(id, SEL) = (const char *(*)(id, SEL))send;
    uint64_t (*send_size)(id, SEL) = (uint64_t (*)(id, SEL))send;
    signed char (*responds)(id, SEL, SEL) = (signed char (*)(id, SEL, SEL))send;
    id named = send_id(device, selector("name"));
    const char *name = named ? send_text(named, selector("UTF8String")) : NULL;
    if (!name) {
        name = "its GPU";
    }
    uint64_t working = 0;
    SEL working_set = selector("recommendedMaxWorkingSetSize");
    if (responds(device, selector("respondsToSelector:"), working_set)) {
        working = send_size(device, working_set);
    }
    if (strstr(name, "Paravirtual")) {
        snprintf(why, room, "%s, %llu MB", name, (unsigned long long)(working >> 20));
    } else if (working > 0 && working < LEAST_WORKING_SET) {
        snprintf(why, room, "%s, only %llu MB", name, (unsigned long long)(working >> 20));
    }
#endif
}

// Whether the person chose how it draws: Settings, Graphics (graphics.cfg),
// or a renderer named on the command line.
static int chosen(int argc, char **argv) {
    for (int i = 1; i < argc; i++) {
        if (!strcmp(argv[i], "--rendering-driver") || !strcmp(argv[i], "--rendering-method")) {
            return 1;
        }
    }
    const char *home = getenv("HOME");
    if (!home) {
        return 0;
    }
    char path[4096];
    snprintf(path, sizeof path,
             "%s/Library/Application Support/Godot/app_userdata/Brickworks/graphics.cfg", home);
    FILE *file = fopen(path, "r");
    if (!file) {
        return 0;
    }
    char line[512];
    int found = 0;
    while (!found && fgets(line, sizeof line, file)) {
        found = strstr(line, "rendering_method") != NULL;
    }
    fclose(file);
    return found;
}

int main(int argc, char **argv) {
    char self[4096];
    uint32_t size = sizeof self;
    if (_NSGetExecutablePath(self, &size) != 0) {
        fprintf(stderr, "Brickworks: cannot tell where it is\n");
        return 1;
    }
    char *slash = strrchr(self, '/');
    if (!slash) {
        return 1;
    }
    char app[4096];
    snprintf(app, sizeof app, "%.*s/Brickworks", (int)(slash - self), self);

    char why[512] = "";
    if (!chosen(argc, argv)) {
        judge(why, sizeof why);
    }
    char **args = calloc((size_t)argc + 3, sizeof *args);
    if (!args) {
        return 1;
    }
    int n = 0;
    args[n++] = app;
    if (why[0]) {
        fprintf(stderr, "Brickworks: the simpler graphics mode (%s)\n", why);
        setenv("BRICKWORKS_GRAPHICS", why, 1);
        args[n++] = "--rendering-driver";
        args[n++] = "opengl3";
    }
    for (int i = 1; i < argc; i++) {
        args[n++] = argv[i];
    }
    args[n] = NULL;

    // Become the app, in this architecture: the slice the GPU was judged for
    // (an Intel slice run under Rosetta stays one).
    posix_spawnattr_t attributes;
    posix_spawnattr_init(&attributes);
    posix_spawnattr_setflags(&attributes, POSIX_SPAWN_SETEXEC);
#if defined(__x86_64__)
    cpu_type_t cpu = CPU_TYPE_X86_64;
#else
    cpu_type_t cpu = CPU_TYPE_ARM64;
#endif
    size_t set = 0;
    posix_spawnattr_setbinpref_np(&attributes, 1, &cpu, &set);
    int failed = posix_spawn(NULL, app, NULL, &attributes, args, environ);
    fprintf(stderr, "Brickworks: could not start %s (error %d)\n", app, failed);
    return 1;
}

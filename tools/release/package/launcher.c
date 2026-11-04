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
// It chooses in graphics.cfg, in the app's own folder, which Godot reads as
// it starts (application/config/project_settings_override), marked as its
// own (graphics/automatic) so that neither the app nor the next start takes
// it for the person's, and takes it away on a GPU the full mode runs on.
// Not on the command line: Godot keeps the files Launch Services opens a new
// app with only when it was started with no arguments
// (godot_application_delegate.mm, get_cmd_argc() == 0), and on the Intel VM
// `open car.ldr` started on --rendering-driver opengl3 opened nothing.
//
// Not when the person has chosen (Settings, Graphics writes the same file,
// unmarked), or names a renderer on the command line.
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
#include <sys/stat.h>
#include <unistd.h>

extern char **environ;

// Less than this to work with and Forward+ runs out. Every Mac with a GPU of
// its own, or Intel graphics sharing the Mac's memory, reports a gigabyte or
// more; so does the paravirtual one (1024 MB, though System Information says
// 64 MB of VRAM), which is known by its name.
#define LEAST_WORKING_SET (256ull << 20)

// The simpler mode as this keeps it: read by Godot as a project setting,
// and by GraphicsMode.chosen as no choice of the person's.
#define OURS "config_version=5\n\n[rendering]\n\nrenderer/rendering_method=\"gl_compatibility\"\n" \
             "\n[brickworks]\n\ngraphics/automatic=true\n"

typedef void *id;
typedef void *SEL;

// Spawning this architecture's slice of [path]: the one the GPU is judged
// for and the app runs as (an Intel slice run under Rosetta stays one).
static void this_slice(posix_spawnattr_t *attributes) {
    posix_spawnattr_init(attributes);
#if defined(__x86_64__)
    cpu_type_t cpu = CPU_TYPE_X86_64;
#else
    cpu_type_t cpu = CPU_TYPE_ARM64;
#endif
    size_t set = 0;
    posix_spawnattr_setbinpref_np(attributes, 1, &cpu, &set);
}

#if defined(__x86_64__)
// Why the full renderer cannot run here, or "" when it can.
static void judge(char *why, size_t room) {
    why[0] = 0;
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
}

// Whether a renderer is named on the command line.
static int renderer_named(int argc, char **argv) {
    for (int i = 1; i < argc; i++) {
        if (!strcmp(argv[i], "--rendering-driver") || !strcmp(argv[i], "--rendering-method")) {
            return 1;
        }
    }
    return 0;
}

// graphics.cfg, in the app's own folder (user://).
static int where_kept(char *path, size_t room) {
    const char *home = getenv("HOME");
    return home && snprintf(path, room,
        "%s/Library/Application Support/Godot/app_userdata/Brickworks/graphics.cfg", home)
        < (int)room;
}

enum { NOBODY, PERSON, LAUNCHER };

// Whose choice graphics.cfg holds: the person's names a rendering method,
// this one's is marked.
static int whose(const char *path) {
    FILE *file = fopen(path, "r");
    if (!file) {
        return NOBODY;
    }
    char line[512];
    int method = 0, ours = 0;
    while (fgets(line, sizeof line, file)) {
        method |= strstr(line, "rendering_method") != NULL;
        ours |= strstr(line, "graphics/automatic=true") != NULL;
    }
    fclose(file);
    return ours ? LAUNCHER : method ? PERSON : NOBODY;
}

// The simpler mode kept for Godot to read, in the folders it would make.
static void keep(char *path) {
    for (char *at = strchr(path + 1, '/'); at; at = strchr(at + 1, '/')) {
        *at = 0;
        mkdir(path, 0755);
        *at = '/';
    }
    char written[4200];
    snprintf(written, sizeof written, "%s.new", path);
    FILE *file = fopen(written, "w");
    if (!file) {
        return;
    }
    int done = fputs(OURS, file) >= 0;
    if (fclose(file) == 0 && done) {
        rename(written, path);
    } else {
        remove(written);
    }
}
#endif

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
#if defined(__x86_64__)
    char kept[4096];
    int who = NOBODY;
    if (!renderer_named(argc, argv) && where_kept(kept, sizeof kept) && (who = whose(kept)) != PERSON) {
        judge(why, sizeof why);
        if (why[0] && who != LAUNCHER) {
            keep(kept);
        } else if (!why[0] && who == LAUNCHER) {
            remove(kept);
        }
    }
#else
    (void)argc;
#endif
    if (why[0]) {
        fprintf(stderr, "Brickworks: the simpler graphics mode (%s)\n", why);
        setenv("BRICKWORKS_GRAPHICS", why, 1);
    }
    argv[0] = app;

    // Become the app, in this architecture.
    posix_spawnattr_t attributes;
    this_slice(&attributes);
    posix_spawnattr_setflags(&attributes, POSIX_SPAWN_SETEXEC);
    int failed = posix_spawn(NULL, app, NULL, &attributes, argv, environ);
    fprintf(stderr, "Brickworks: could not start %s (error %d)\n", app, failed);
    return 1;
}

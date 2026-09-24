/* Relocatable macOS launcher. Bundles the installed Godot runtime for offline play. */
#include <mach-o/dyld.h>
#include <libgen.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
int main(int argc, char **argv) {
    char executable[PATH_MAX], resolved[PATH_MAX], engine[PATH_MAX], pack[PATH_MAX];
    uint32_t size = sizeof(executable);
    if (_NSGetExecutablePath(executable, &size) != 0 || !realpath(executable, resolved)) return 1;
    char *dir = dirname(resolved);
    snprintf(engine, sizeof(engine), "%s/RoadRageEngine", dir);
    snprintf(pack, sizeof(pack), "%s/../Resources/game.pck", dir);
    char **args = calloc((size_t)argc + 4, sizeof(char *));
    if (!args) return 1;
    args[0] = engine; args[1] = "--main-pack"; args[2] = pack;
    for (int i = 1; i < argc; i++) args[i+2] = argv[i];
    execv(engine, args);
    perror("Road Rage could not launch");
    free(args);
    return 1;
}

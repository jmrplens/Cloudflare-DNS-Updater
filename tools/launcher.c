#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/stat.h>
#include <sys/types.h>

#define PAYLOAD_MARKER "---PAYLOAD_START---"

int main(int argc, char *argv[]) {
    char temp_dir[] = "/tmp/cf-updater-XXXXXX";
    if (mkdtemp(temp_dir) == NULL) {
        perror("Failed to create temp directory");
        return 1;
    }

    // Get path to self
    char self_path[1024];
    ssize_t len = readlink("/proc/self/exe", self_path, sizeof(self_path)-1);
    if (len == -1) {
        perror("readlink");
        return 1;
    }
    self_path[len] = '\0';

    // Find payload in self
    FILE *f = fopen(self_path, "rb");
    if (!f) return 1;

    // Search for marker
    char buf[1024];
    long payload_offset = -1;
    while (fgets(buf, sizeof(buf), f)) {
        if (strstr(buf, PAYLOAD_MARKER)) {
            payload_offset = ftell(f);
            break;
        }
    }

    if (payload_offset == -1) {
        fprintf(stderr, "Payload not found!\n");
        fclose(f);
        return 1;
    }

    // Extract payload quietly
    char cmd[2048];
    sprintf(cmd, "tail -c +%ld \"%s\" | tar -xz -C \"%s\"", payload_offset + 1, self_path, temp_dir);
    if (system(cmd) != 0) {
        fprintf(stderr, "Extraction failed\n");
        return 1;
    }
    fclose(f);

    // Build execution command
    // Format: /tmp/.../bin/bash /tmp/.../main.sh [args...]
    char run_cmd[4096];
    sprintf(run_cmd, "export MAKESELF_PWD=\"$PWD\"; \"%s/bin/bash\" \"%s/main.sh\"", temp_dir, temp_dir);
    
    for (int i = 1; i < argc; i++) {
        strcat(run_cmd, " \"");
        strcat(run_cmd, argv[i]);
        strcat(run_cmd, "\"");
    }

    // Execute and wait
    int ret = system(run_cmd);

    // Cleanup
    sprintf(cmd, "rm -rf \"%s\"", temp_dir);
    system(cmd);

    return WEXITSTATUS(ret);
}

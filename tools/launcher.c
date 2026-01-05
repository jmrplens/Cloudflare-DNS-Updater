#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef _WIN32
#include <windows.h>
#include <direct.h>
#define mkdir(path, mode) _mkdir(path)
#define PATH_SEP "\\"
#else
#include <unistd.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <limits.h>
#define PATH_SEP "/"
#ifdef __APPLE__
#include <mach-o/dyld.h>
#else
// Headers for modern Linux path resolution
#include <sys/auxv.h>
#include <elf.h>
#endif
#endif

#ifndef PATH_MAX
#define PATH_MAX 4096
#endif

#define PAYLOAD_MARKER "---PAYLOAD_START---"

void get_self_path(char *buffer, size_t size) {
#ifdef _WIN32
	GetModuleFileNameA(NULL, buffer, (DWORD)size);
#elif defined(__APPLE__)
	uint32_t bsize = (uint32_t)size;
	_NSGetExecutablePath(buffer, &bsize);
#else
	// Modern Linux approach using auxiliary vector to avoid readlink race conditions
	const char *exec_path = (const char *)getauxval(AT_EXECFN);
	if (exec_path) {
		snprintf(buffer, size, "%s", exec_path);
	} else {
		buffer[0] = '\0';
	}
#endif
}

int main(int argc, char *argv[]) {
	char temp_dir[PATH_MAX];
#ifdef _WIN32
	char *tmp = getenv("TEMP");
	snprintf(temp_dir, sizeof(temp_dir), "%s\\cf-updater-%%d", tmp ? tmp : "C:\\Windows\\Temp", getpid());
	mkdir(temp_dir, 0700);
#else
	strncpy(temp_dir, "/tmp/cf-updater-XXXXXX", sizeof(temp_dir) - 1);
	temp_dir[sizeof(temp_dir) - 1] = '\0';
	if (mkdtemp(temp_dir) == NULL) {
		perror("mkdtemp");
		return 1;
	}
#endif

	char self_path[PATH_MAX];
	get_self_path(self_path, sizeof(self_path));

	FILE *f = fopen(self_path, "rb");
	if (!f)
		return 1;

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
	fclose(f);

	// Large enough buffer for commands
	char cmd[PATH_MAX * 2];
	int ret;

#ifdef _WIN32
	snprintf(cmd, sizeof(cmd), "powershell -Command \"$f = [System.IO.File]::OpenRead('%s'); $f.Seek(%ld, [System.IO.SeekOrigin]::Begin); $out = [System.IO.File]::Create('%s\\payload.tar.gz'); $f.CopyTo($out); $f.Close(); $out.Close(); tar -xzf '%s\\payload.tar.gz' -C '%s'\"", self_path, payload_offset, temp_dir, temp_dir, temp_dir);
#else
	snprintf(cmd, sizeof(cmd), "tail -c +%ld \"%s\" | tar -xz -C \"%s\"", payload_offset + 1, self_path, temp_dir);
#endif

	ret = system(cmd);
	if (ret != 0) {
		fprintf(stderr, "Extraction failed with code %d\n", ret);
		return 1;
	}

	char run_cmd[PATH_MAX * 3];
	int offset = 0;
#ifdef _WIN32
	offset = snprintf(run_cmd, sizeof(run_cmd), "set \"MAKESELF_PWD=%%CD%%\" && \"%s\\bin\\bash.exe\" \"%s\\main.sh\"", temp_dir, temp_dir);
#else
	offset = snprintf(run_cmd, sizeof(run_cmd), "export MAKESELF_PWD=\"$PWD\"; \"%s/bin/bash\" \"%s/main.sh\"", temp_dir, temp_dir);
#endif

	for (int i = 1; i < argc && offset < (int)sizeof(run_cmd); i++) {
		offset += snprintf(run_cmd + offset, sizeof(run_cmd) - offset, " \"%s\"", argv[i]);
	}

	ret = system(run_cmd);

#ifdef _WIN32
	snprintf(cmd, sizeof(cmd), "rd /s /q \"%s\"", temp_dir);
#else
	snprintf(cmd, sizeof(cmd), "rm -rf \"%s\"", temp_dir);
#endif
	
	// We ignore cleanup return value as we are already exiting
	int cleanup_ret = system(cmd);
	(void)cleanup_ret;

	return (ret >> 8) & 0xff;
}

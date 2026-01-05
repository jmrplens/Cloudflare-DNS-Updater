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
#endif
#endif

#define PAYLOAD_MARKER "---PAYLOAD_START---"

void get_self_path(char *buffer, size_t size) {
#ifdef _WIN32
	GetModuleFileNameA(NULL, buffer, (DWORD)size);
#elif defined(__APPLE__)
	uint32_t bsize = (uint32_t)size;
	_NSGetExecutablePath(buffer, &bsize);
#else
	if (realpath("/proc/self/exe", buffer) == NULL) {
		buffer[0] = '\0';
	}
#endif
}

int main(int argc, char *argv[]) {
	char temp_dir[512];
#ifdef _WIN32
	char *tmp = getenv("TEMP");
	sprintf(temp_dir, "%s\\cf-updater-%d", tmp ? tmp : "C:\\Windows\\Temp", getpid());
	_mkdir(temp_dir);
#else
	strcpy(temp_dir, "/tmp/cf-updater-XXXXXX");
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

	char cmd[2048];
#ifdef _WIN32
	// On Windows, we assume the payload is a ZIP and we use powershell to extract
	sprintf(cmd, "powershell -Command \"$f = [System.IO.File]::OpenRead('%s'); $f.Seek(%ld, [System.IO.SeekOrigin]::Begin); $out = [System.IO.File]::Create('%s\\payload.tar.gz'); $f.CopyTo($out); $f.Close(); $out.Close(); tar -xzf '%s\\payload.tar.gz' -C '%s'\"", self_path, payload_offset, temp_dir, temp_dir, temp_dir);
#else
	sprintf(cmd, "tail -c +%ld \"%s\" | tar -xz -C \"%s\"", payload_offset + 1, self_path, temp_dir);
#endif

	if (system(cmd) != 0) {
		fprintf(stderr, "Extraction failed\n");
		return 1;
	}

	char run_cmd[4096];
#ifdef _WIN32
	ssprintf(run_cmd, "set \"MAKESELF_PWD=%%CD%%\" && \"%s\\bin\\bash.exe\" \"%s\\main.sh\"", temp_dir, temp_dir);
#else
	sprintf(run_cmd, "export MAKESELF_PWD=\"$PWD\"; \"%s/bin/bash\" \"%s/main.sh\"", temp_dir, temp_dir);
#endif

	for (int i = 1; i < argc; i++) {
		strcat(run_cmd, " \"");
		strcat(run_cmd, argv[i]);
		strcat(run_cmd, "\"");
	}

	int ret = system(run_cmd);

#ifdef _WIN32
	ssprintf(cmd, "rd /s /q \"%s\"", temp_dir);
#else
	ssprintf(cmd, "rm -rf \"%s\"", temp_dir);
#endif
	system(cmd);

	return (ret >> 8) & 0xff;
}
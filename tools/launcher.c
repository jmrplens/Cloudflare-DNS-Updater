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
#include <sys/wait.h>
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

	char cmd[PATH_MAX * 2];
#ifdef _WIN32
	snprintf(cmd, sizeof(cmd), "powershell -Command \"$f = [System.IO.File]::OpenRead('%s'); $f.Seek(%ld, [System.IO.SeekOrigin]::Begin); $out = [System.IO.File]::Create('%s\\payload.tar.gz'); $f.CopyTo($out); $f.Close(); $out.Close(); tar -xzf '%s\\payload.tar.gz' -C '%s'\"", self_path, payload_offset, temp_dir, temp_dir, temp_dir);
#else
	snprintf(cmd, sizeof(cmd), "tail -c +%ld \"%s\" | tar -xz -C \"%s\"", payload_offset + 1, self_path, temp_dir);
#endif

	if (system(cmd) != 0) {
		fprintf(stderr, "Extraction failed\n");
		return 1;
	}

#ifdef _WIN32
	// For Windows, we still use system for simplicity but with better quoting
	char run_cmd[PATH_MAX * 3];
	snprintf(run_cmd, sizeof(run_cmd), "set \"MAKESELF_PWD=%s\" && \"%s\\bin\\bash.exe\" \"%s\\main.sh\"", getcwd(NULL, 0), temp_dir, temp_dir);
	for (int i = 1; i < argc; i++) {
		strncat(run_cmd, " \"", sizeof(run_cmd) - strlen(run_cmd) - 1);
		strncat(run_cmd, argv[i], sizeof(run_cmd) - strlen(run_cmd) - 1);
		strncat(run_cmd, "\"", sizeof(run_cmd) - strlen(run_cmd) - 1);
	}
	int ret = system(run_cmd);
	sprintf(cmd, "rd /s /q \"%s\"", temp_dir);
	system(cmd);
	return (ret >> 8) & 0xff;
#else
	pid_t pid = fork();
	if (pid == 0) {
		// Child: Execute the script safely
		char bash_path[PATH_MAX];
		char script_path[PATH_MAX];
		snprintf(bash_path, sizeof(bash_path), "%s/bin/bash", temp_dir);
		snprintf(script_path, sizeof(script_path), "%s/main.sh", temp_dir);

		char **new_argv = malloc((argc + 2) * sizeof(char *));
		if (!new_argv) exit(1);

		new_argv[0] = bash_path;
		new_argv[1] = script_path;
		for (int i = 1; i < argc; i++) {
			new_argv[i + 1] = argv[i];
		}
		new_argv[argc + 1] = NULL;

		char *cwd = getcwd(NULL, 0);
		if (cwd) {
			setenv("MAKESELF_PWD", cwd, 1);
			free(cwd);
		}

		// Use the absolute path to our bundled bash for maximum security
		// flawfinder: ignore
		execv(bash_path, new_argv);
		perror("execv");
		free(new_argv);
		exit(1);
	} else if (pid > 0) {
		// Parent: Wait for child and cleanup
		int status;
		waitpid(pid, &status, 0);
		snprintf(cmd, sizeof(cmd), "rm -rf \"%s\"", temp_dir);
		system(cmd);
		return WEXITSTATUS(status);
	} else {
		perror("fork");
		return 1;
	}
#endif
}
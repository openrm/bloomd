/*
 * Container entrypoint: the runtime image is distroless (no shell), so this replaces a shell script.
 * Writes the configuration from the BLOOMD_* environment variables to /tmp, then execs bloomd.
 */
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#define CONF_PATH "/tmp/bloomd.conf"

static const char *env_or(const char *name, const char *fallback) {
    const char *value = getenv(name);
    return (value && *value) ? value : fallback;
}

int main(void) {
    FILE *conf = fopen(CONF_PATH, "w");
    if (!conf) {
        perror("entrypoint: cannot write " CONF_PATH);
        return 1;
    }
    fprintf(conf,
            "[bloomd]\n"
            "tcp_port = %s\n"
            "data_dir = %s\n"
            "log_level = %s\n"
            "flush_interval = %s\n"
            "workers = %s\n",
            env_or("BLOOMD_PORT", "8673"),
            env_or("BLOOMD_DATA_DIR", "/data"),
            env_or("BLOOMD_LOG_LEVEL", "INFO"),
            env_or("BLOOMD_FLUSH_INTERVAL", "300"),
            env_or("BLOOMD_WORKERS", "2"));
    if (fclose(conf) != 0) {
        perror("entrypoint: cannot write " CONF_PATH);
        return 1;
    }

    char *argv[] = {"bloomd", "-f", CONF_PATH, NULL};
    execv("/etc/bloomd/bloomd", argv);
    perror("entrypoint: cannot exec /etc/bloomd/bloomd");
    return 1;
}

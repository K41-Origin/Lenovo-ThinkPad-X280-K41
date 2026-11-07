#define _GNU_SOURCE
#define _FILE_OFFSET_BITS 64

#include <errno.h>
#include <fcntl.h>
#include <inttypes.h>
#include <linux/fs.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/stat.h>
#include <sys/sysmacros.h>
#include <unistd.h>

/*
 * Read-only Stage 8 acquisition prototype.
 * It never writes to the device and never invokes another program.
 * The descriptor remains open until stdin reaches EOF.
 */

static int fail(const char *message)
{
    fprintf(stderr, "storage-handle: %s: %s\n", message, strerror(errno));
    return 1;
}

static bool sysfs_attribute_exists(const char *major_minor, const char *attribute)
{
    char path[256];
    int length = snprintf(path, sizeof(path), "/sys/dev/block/%s/%s",
                          major_minor, attribute);
    if (length < 0 || (size_t)length >= sizeof(path))
        return false;
    struct stat status;
    return lstat(path, &status) == 0;
}

static bool read_diskseq(const char *major_minor, uint64_t *value)
{
    char path[256];
    int length = snprintf(path, sizeof(path), "/sys/dev/block/%s/diskseq",
                          major_minor);
    if (length < 0 || (size_t)length >= sizeof(path))
        return false;

    FILE *file = fopen(path, "re");
    if (file == NULL)
        return false;

    char buffer[64];
    bool valid = fgets(buffer, sizeof(buffer), file) != NULL;
    int saved_errno = errno;
    if (fclose(file) != 0)
        valid = false;
    errno = saved_errno;
    if (!valid)
        return false;

    char *end = NULL;
    errno = 0;
    unsigned long long parsed = strtoull(buffer, &end, 10);
    if (errno != 0 || end == buffer || (*end != '\\n' && *end != '\\0'))
        return false;
    *value = (uint64_t)parsed;
    return true;
}

int main(int argc, char **argv)
{
    if (argc != 2 || strcmp(argv[1], "--help") == 0) {
        fprintf(argc == 2 ? stdout : stderr,
                "Usage: storage-handle <whole-disk-device-path>\n"
                "Opens read-only with O_EXCL|O_CLOEXEC|O_NOFOLLOW, reports "
                "descriptor facts, then holds the descriptor until stdin EOF.\n");
        return argc == 2 ? 0 : 2;
    }

    int fd = open(argv[1], O_RDONLY | O_CLOEXEC | O_NOFOLLOW | O_EXCL | O_NONBLOCK);
    if (fd < 0)
        return fail("open failed");

    struct stat status;
    if (fstat(fd, &status) != 0) {
        int result = fail("fstat failed");
        close(fd);
        return result;
    }
    if (!S_ISBLK(status.st_mode)) {
        fprintf(stderr, "storage-handle: candidate is not a block device\n");
        close(fd);
        return 1;
    }

    unsigned int major_number = major(status.st_rdev);
    unsigned int minor_number = minor(status.st_rdev);
    char major_minor[64];
    int length = snprintf(major_minor, sizeof(major_minor), "%u:%u",
                          major_number, minor_number);
    if (length < 0 || (size_t)length >= sizeof(major_minor)) {
        close(fd);
        return 1;
    }

    /* A partition exposes this sysfs attribute; reject it explicitly. */
    if (sysfs_attribute_exists(major_minor, "partition")) {
        fprintf(stderr, "storage-handle: candidate is a partition, not a whole disk\n");
        close(fd);
        return 1;
    }

    uint64_t size_bytes = 0;
    int logical_sector = 0;
    int physical_sector = 0;
    int read_only = 0;
    if (ioctl(fd, BLKGETSIZE64, &size_bytes) != 0 ||
        ioctl(fd, BLKSSZGET, &logical_sector) != 0 ||
        ioctl(fd, BLKPBSZGET, &physical_sector) != 0 ||
        ioctl(fd, BLKROGET, &read_only) != 0) {
        int result = fail("required descriptor ioctl failed");
        close(fd);
        return result;
    }
    if (size_bytes == 0 || logical_sector <= 0 || physical_sector <= 0 ||
        (read_only != 0 && read_only != 1)) {
        fprintf(stderr, "storage-handle: invalid block geometry or read-only state\n");
        close(fd);
        return 1;
    }

    uint64_t diskseq = 0;
    bool diskseq_available = read_diskseq(major_minor, &diskseq);
    bool removable = sysfs_attribute_exists(major_minor, "removable");

    printf("{\"protocol\":1,\"device_path\":\"%s\","
           "\"major\":%u,\"minor\":%u,\"size_bytes\":%" PRIu64 ","
           "\"logical_sector_bytes\":%d,\"physical_sector_bytes\":%d,"
           "\"read_only\":%s,\"removable_attribute_present\":%s,"
           "\"diskseq_available\":%s,\"diskseq\":",
           argv[1], major_number, minor_number, size_bytes, logical_sector,
           physical_sector, read_only ? "true" : "false",
           removable ? "true" : "false", diskseq_available ? "true" : "false");
    if (diskseq_available)
        printf("%" PRIu64, diskseq);
    else
        printf("null");
    printf("}\n");
    if (fflush(stdout) != 0) {
        close(fd);
        return fail("stdout flush failed");
    }

    /* No command channel: stdin EOF is the only normal release mechanism. */
    char byte;
    while (read(STDIN_FILENO, &byte, 1) < 0) {
        if (errno == EINTR)
            continue;
        int result = fail("stdin read failed");
        close(fd);
        return result;
    }
    close(fd);
    return 0;
}

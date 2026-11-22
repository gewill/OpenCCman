#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <string.h>
#include <sys/attr.h>
#include <sys/stat.h>
#include <unistd.h>

static void report(const char *what, int rc) {
  int e = errno;
  printf("  %-34s rc=%d errno=%d %s\n", what, rc, rc < 0 ? e : 0, rc < 0 ? strerror(e) : "");
}
static void put(const char *path, const char *text) {
  int fd = open(path, O_CREAT | O_WRONLY | O_TRUNC, 0600);
  if (fd >= 0) { write(fd, text, strlen(text)); close(fd); }
}
static void show(const char *label, const char *path) {
  char buf[64] = {0};
  struct stat st;
  if (lstat(path, &st) != 0) { printf("  %-34s missing\n", label); return; }
  int fd = open(path, O_RDONLY);
  ssize_t n = fd >= 0 ? read(fd, buf, sizeof buf - 1) : -1;
  if (fd >= 0) close(fd);
  printf("  %-34s %s content=%s\n", label, S_ISDIR(st.st_mode) ? "dir" : "file", n > 0 ? buf : "");
}
int main(int argc, char **argv) {
  for (int i = 1; i < argc; i++) {
    const char *v = argv[i];
    struct attrlist al = {0};
    al.bitmapcount = ATTR_BIT_MAP_COUNT;
    al.volattr = ATTR_VOL_INFO | ATTR_VOL_CAPABILITIES;
    struct { u_int32_t len; vol_capabilities_attr_t caps; } __attribute__((aligned(4), packed)) b;
    printf("%s\n", v);
    if (getattrlist(v, &al, &b, sizeof b, 0) == 0)
      printf("  RENAME_EXCL valid=%d supported=%d\n",
             !!(b.caps.valid[VOL_CAPABILITIES_INTERFACES] & VOL_CAP_INT_RENAME_EXCL),
             !!(b.caps.capabilities[VOL_CAPABILITIES_INTERFACES] & VOL_CAP_INT_RENAME_EXCL));
    char src[1024], absent[1024], existing[1024], dir[1024], reserved[1024];
    snprintf(src, sizeof src, "%s/p-src.txt", v);
    snprintf(absent, sizeof absent, "%s/p-absent.txt", v);
    snprintf(existing, sizeof existing, "%s/p-existing.txt", v);
    snprintf(dir, sizeof dir, "%s/p-dir", v);
    snprintf(reserved, sizeof reserved, "%s/p-reserved.txt", v);
    put(src, "staged"); put(existing, "someone");
    report("renamex_np EXCL -> absent", renamex_np(src, absent, RENAME_EXCL));
    show("  absent after", absent);
    put(src, "staged");
    report("renamex_np EXCL -> existing", renamex_np(src, existing, RENAME_EXCL));
    show("  existing after", existing);
    show("  src after", src);
    put(src, "staged");
    int fd = open(existing, O_CREAT | O_EXCL | O_WRONLY | O_CLOEXEC, 0600);
    report("open O_EXCL existing", fd); if (fd >= 0) close(fd);
    fd = open(reserved, O_CREAT | O_EXCL | O_WRONLY | O_CLOEXEC, 0600);
    report("open O_EXCL absent (reserve)", fd);
    mkdir(dir, 0700);
    report("rename dir -> reserved file", rename(dir, reserved));
    show("  reserved after", reserved);
    if (fd >= 0) close(fd);
    report("rename file -> reserved file", rename(src, reserved));
    show("  reserved after", reserved);
  }
  return 0;
}

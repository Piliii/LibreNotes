#include "my_application.h"

#include <stdio.h>
#include <unistd.h>

int main(int argc, char** argv) {
  g_autoptr(MyApplication) app = my_application_new();
  int exit_code = g_application_run(G_APPLICATION(app), argc, argv);

  // By this point the GTK window is closed and the Flutter engine has
  // already shut down cleanly, so there's nothing left to flush or tear
  // down. Bypass atexit handlers via _exit() instead of returning normally:
  // on some NVIDIA driver versions, libEGL_nvidia registers an atexit EGL
  // teardown that segfaults inside libnvidia-eglcore during normal exit().
  fflush(nullptr);
  _exit(exit_code);
}

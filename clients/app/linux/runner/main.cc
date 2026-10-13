#include "my_application.h"

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

int main(int argc, char** argv) {
  // The global quick-capture hotkey (keybinder -> XGrabKey) only fires under
  // X11/XWayland, and Flutter's native-Wayland key handling can desync (lost
  // key-ups, dead shortcuts). Prefer XWayland when one is available; an
  // explicit GDK_BACKEND from the user still wins (overwrite = 0).
  if (getenv("DISPLAY") != nullptr) setenv("GDK_BACKEND", "x11", 0);

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

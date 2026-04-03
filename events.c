// Passive CGEventTap listener for macOS.
// Runs on a dedicated pthread, writes events to a ring buffer that Julia polls.
#include <CoreGraphics/CoreGraphics.h>
#include <ApplicationServices/ApplicationServices.h>
#include <pthread.h>
#include <stdatomic.h>
#include <unistd.h>

typedef struct {
  int type; double timestamp; double x, y;
  int button, click_count; double scroll_dx, scroll_dy;
  int keycode; unsigned int modifiers;
} E;

#define RING 1024
static E ring[RING];
static _Atomic long long count = 0;
static CFRunLoopRef rl = NULL;
static pthread_t tid = 0;
static volatile int state = 0;

static int mtype(CGEventType t) {
  switch(t) {
  case kCGEventMouseMoved: case kCGEventLeftMouseDragged:
  case kCGEventRightMouseDragged: case kCGEventOtherMouseDragged: return 0;
  case kCGEventLeftMouseDown: case kCGEventRightMouseDown:
  case kCGEventOtherMouseDown: return 1;
  case kCGEventLeftMouseUp: case kCGEventRightMouseUp:
  case kCGEventOtherMouseUp: return 2;
  case kCGEventScrollWheel: return 3;
  case kCGEventKeyDown: return 4;
  case kCGEventKeyUp: return 5;
  case kCGEventFlagsChanged: return 6;
  default: return -1;
  }
}

static int mbtn(CGEventType t) {
  switch(t) {
  case kCGEventLeftMouseDown: case kCGEventLeftMouseUp:
  case kCGEventLeftMouseDragged: return 0;
  case kCGEventRightMouseDown: case kCGEventRightMouseUp:
  case kCGEventRightMouseDragged: return 1;
  default: return 2;
  }
}

static CGEventRef cb(CGEventTapProxy p, CGEventType type, CGEventRef ev, void *u) {
  int t = mtype(type);
  if (t < 0) return ev;
  CGPoint pt = CGEventGetLocation(ev);
  long long n = atomic_load_explicit(&count, memory_order_relaxed);
  int i = (int)(n % RING);
  ring[i] = (E){t, (double)CGEventGetTimestamp(ev)/1e9, pt.x, pt.y, mbtn(type),
    t==1 ? (int)CGEventGetIntegerValueField(ev, kCGMouseEventClickState) : 0,
    t==3 ? (double)CGEventGetIntegerValueField(ev, kCGScrollWheelEventDeltaAxis2) : 0,
    t==3 ? (double)CGEventGetIntegerValueField(ev, kCGScrollWheelEventDeltaAxis1) : 0,
    t>=4 ? (int)CGEventGetIntegerValueField(ev, kCGKeyboardEventKeycode) : 0,
    (unsigned int)CGEventGetFlags(ev)};
  atomic_store_explicit(&count, n+1, memory_order_release);
  return ev;
}

static void *run(void *a) {
  CGEventMask m =
    (1ULL<<kCGEventMouseMoved)|(1ULL<<kCGEventLeftMouseDown)|(1ULL<<kCGEventLeftMouseUp)|
    (1ULL<<kCGEventRightMouseDown)|(1ULL<<kCGEventRightMouseUp)|
    (1ULL<<kCGEventOtherMouseDown)|(1ULL<<kCGEventOtherMouseUp)|
    (1ULL<<kCGEventLeftMouseDragged)|(1ULL<<kCGEventRightMouseDragged)|
    (1ULL<<kCGEventOtherMouseDragged)|(1ULL<<kCGEventScrollWheel)|
    (1ULL<<kCGEventKeyDown)|(1ULL<<kCGEventKeyUp)|(1ULL<<kCGEventFlagsChanged);
  CFMachPortRef tap = CGEventTapCreate(kCGSessionEventTap, kCGHeadInsertEventTap,
    kCGEventTapOptionListenOnly, m, cb, NULL);
  if (!tap) { state = 0; return NULL; }
  CFRunLoopSourceRef s = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0);
  if (!s) { CFRelease(tap); state = 0; return NULL; }
  CFRunLoopRef loop = CFRunLoopGetCurrent();
  rl = loop;
  CFRunLoopAddSource(loop, s, kCFRunLoopCommonModes);
  CGEventTapEnable(tap, true);
  state = 1;
  CFRunLoopRun();
  CGEventTapEnable(tap, false);
  CFRunLoopRemoveSource(loop, s, kCFRunLoopCommonModes);
  CFRelease(s); CFRelease(tap);
  rl = NULL; state = 0;
  return NULL;
}

int ac_start(void) {
  if (state) return -1;
  if (!AXIsProcessTrusted()) return -2;
  state = -1;
  if (pthread_create(&tid, NULL, run, NULL)) { state = 0; return -3; }
  while (state == -1) usleep(1000);
  return state == 1 ? 0 : -4;
}

void ac_stop(void) {
  if (rl) CFRunLoopStop(rl);
  if (tid) { pthread_join(tid, NULL); tid = 0; }
}

E *ac_ring(void) { return ring; }
long long *ac_count(void) { return (long long*)&count; }

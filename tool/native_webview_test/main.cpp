#include "../../windows/runner/webview_runtime.h"
#include <iostream>

int main() {
  bool recovered = false;
  for (int i = 0; i < 10; ++i) {
    if (FAILED(EnsureWebViewApartment(&recovered)) || !recovered) return 1;
    if (FAILED(EnsureWebViewApartment(&recovered)) || recovered) return 2;
    // Emulate a native component leaving this thread uninitialized.
    CoUninitialize();
    APTTYPE type;
    APTTYPEQUALIFIER qualifier;
    if (CoGetApartmentType(&type, &qualifier) != CO_E_NOTINITIALIZED) return 3;
  }
  // An explicitly initialized MTA must not be silently changed to STA.
  if (FAILED(CoInitializeEx(nullptr, COINIT_MULTITHREADED))) return 4;
  const HRESULT status = EnsureWebViewApartment(&recovered);
  CoUninitialize();
  if (status != RPC_E_CHANGED_MODE || recovered) return 5;
  std::cout << "Passed: repeated COM teardown recovery, balanced references, and MTA rejection.\n";
  return 0;
}

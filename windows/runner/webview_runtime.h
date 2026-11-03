#ifndef RUNNER_WEBVIEW_RUNTIME_H_
#define RUNNER_WEBVIEW_RUNTIME_H_

#include <windows.h>
#include <objbase.h>

// Runs on the platform thread. Never add a COM reference when its apartment
// already exists; the runner's final CoUninitialize balances the restored one.
inline HRESULT EnsureWebViewApartment(bool* recovered) {
  *recovered = false;
  APTTYPE apartment = APTTYPE_CURRENT;
  APTTYPEQUALIFIER qualifier = APTTYPEQUALIFIER_NONE;
  HRESULT status = CoGetApartmentType(&apartment, &qualifier);
  if (status == CO_E_NOTINITIALIZED) {
    status = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
    *recovered = SUCCEEDED(status);
    apartment = APTTYPE_STA;
  }
  if (FAILED(status)) return status;
  return apartment == APTTYPE_STA || apartment == APTTYPE_MAINSTA
             ? S_OK
             : RPC_E_CHANGED_MODE;
}

#endif  // RUNNER_WEBVIEW_RUNTIME_H_

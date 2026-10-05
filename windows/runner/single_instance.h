#ifndef JA_WIFI_SINGLE_INSTANCE_H_
#define JA_WIFI_SINGLE_INSTANCE_H_

#include <windows.h>

struct InstanceMutexResult {
  HANDLE handle;
  DWORD error;
};

// Lifetime is the lifetime of the handle, not ownership of a mutex lock.
inline InstanceMutexResult OpenInstanceMutex(const wchar_t* name) {
  ::SetLastError(ERROR_SUCCESS);
  const HANDLE handle = ::CreateMutexExW(nullptr, name, 0, SYNCHRONIZE);
  return {handle, ::GetLastError()};
}

#endif

#include <windows.h>
#include <iostream>
#include <string>
#include "../../windows/runner/single_instance.h"

int main() {
  const std::wstring name = L"Local\\JAWiFiMutexRegression_" +
      std::to_wstring(::GetCurrentProcessId());
  const auto first = OpenInstanceMutex(name.c_str());
  if (!first.handle || first.error == ERROR_ALREADY_EXISTS) return 1;
  const auto second = OpenInstanceMutex(name.c_str());
  if (!second.handle || second.error != ERROR_ALREADY_EXISTS) return 2;
  ::CloseHandle(first.handle);
  const auto third = OpenInstanceMutex(name.c_str());
  if (!third.handle || third.error != ERROR_ALREADY_EXISTS) return 3;
  ::CloseHandle(second.handle);
  ::CloseHandle(third.handle);
  const auto fresh = OpenInstanceMutex(name.c_str());
  if (!fresh.handle || fresh.error == ERROR_ALREADY_EXISTS) return 4;
  ::CloseHandle(fresh.handle);

  // A conflicting kernel object must fail, never permit a duplicate instance.
  const HANDLE event = ::CreateEventW(nullptr, FALSE, FALSE, name.c_str());
  if (!event) return 5;
  const auto collision = OpenInstanceMutex(name.c_str());
  ::CloseHandle(event);
  if (collision.handle || collision.error != ERROR_INVALID_HANDLE) return 6;
  std::cout << "PASS: duplicate, handle lifetime, fresh restart, collision failure\n";
  return 0;
}

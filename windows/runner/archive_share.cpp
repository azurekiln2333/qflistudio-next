// The stock Flutter runner sets _HAS_EXCEPTIONS=0. This translation unit uses
// C++/WinRT error translation and catches every public/coroutine boundary.
#ifdef _HAS_EXCEPTIONS
#undef _HAS_EXCEPTIONS
#endif
#define _HAS_EXCEPTIONS 1

#include "archive_share.h"

#include <roapi.h>
#include <shlobj.h>
#include <shobjidl.h>
#include <winver.h>
#include <winrt/Windows.ApplicationModel.DataTransfer.h>
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Foundation.Collections.h>
#include <winrt/Windows.Storage.h>

#include <cwctype>
#include <filesystem>
#include <optional>
#include <utility>
#include <vector>

namespace {
using winrt::Windows::ApplicationModel::DataTransfer::DataPackageOperation;
using winrt::Windows::ApplicationModel::DataTransfer::DataRequestedEventArgs;
using winrt::Windows::ApplicationModel::DataTransfer::DataTransferManager;
using winrt::Windows::ApplicationModel::DataTransfer::IDataTransferManager;
using winrt::Windows::Storage::IStorageItem;
using winrt::Windows::Storage::StorageFile;
using Result = flutter::MethodResult<flutter::EncodableValue>;
namespace fs = std::filesystem;

std::wstring SafeComponent(std::wstring value) {
  for (auto& character : value) {
    if (std::wstring(L"<>:\"/\\|?*").find(character) != std::wstring::npos) {
      character = L'_';
    }
  }
  while (!value.empty() && std::iswspace(value.back())) value.pop_back();
  while (!value.empty() && value.back() == L'.') value.pop_back();
  if (value.size() > 255) value.resize(255);
  return value;
}

// Match path_provider_windows: RoamingAppData/company/product from the runner's
// VERSIONINFO, not a caller-supplied root or a broad cache-directory grant.
fs::path ShareRoot() {
  std::vector<wchar_t> executable(32768);
  const DWORD length = GetModuleFileNameW(nullptr, executable.data(),
                                         static_cast<DWORD>(executable.size()));
  winrt::check_bool(length != 0 && length < executable.size());
  const std::wstring module(executable.data(), length);
  DWORD unused = 0;
  const DWORD size = GetFileVersionInfoSizeW(module.c_str(), &unused);
  std::vector<BYTE> version(size);
  const bool has_version = size != 0 &&
      GetFileVersionInfoW(module.c_str(), 0, size, version.data()) != FALSE;
  const auto field = [&](const wchar_t* name) -> std::wstring {
    if (!has_version) return {};
    for (const wchar_t* table : {L"040904e4", L"040904b0"}) {
      const std::wstring key = std::wstring(L"\\StringFileInfo\\") + table + L"\\" + name;
      void* value = nullptr;
      UINT count = 0;
      if (VerQueryValueW(version.data(), key.c_str(), &value, &count) && count > 1) {
        return SafeComponent(std::wstring(static_cast<wchar_t*>(value), count - 1));
      }
    }
    return {};
  };
  PWSTR roaming = nullptr;
  winrt::check_hresult(SHGetKnownFolderPath(FOLDERID_RoamingAppData, 0, nullptr, &roaming));
  fs::path root(roaming);
  CoTaskMemFree(roaming);
  const auto company = field(L"CompanyName");
  const auto product = field(L"ProductName");
  if (!company.empty()) root /= company;
  root /= product.empty() ? fs::path(module).stem().wstring() : product;
  return root / L"archive_shares";
}

std::wstring ValidatedArchive(const std::string& utf8_path) {
  const fs::path file(winrt::to_hstring(utf8_path).c_str());
  if (!file.is_absolute() || file != file.lexically_normal() ||
      file.extension() != L".zip") {
    throw winrt::hresult_invalid_argument();
  }
  const fs::path root = ShareRoot();
  const auto relative = file.lexically_relative(root);
  std::vector<std::wstring> parts;
  for (const auto& part : relative) parts.push_back(part.wstring());
  if (parts.size() != 2 || parts[0].rfind(L"share-", 0) != 0 ||
      parts[0].find(L"..") != std::wstring::npos || parts[1] == L".." ||
      parts[1].find(L':') != std::wstring::npos) {
    throw winrt::hresult_invalid_argument();
  }
  // Refuse reparse points at all application-owned levels. The provider hands
  // out a StorageFile for this ZIP only, never its parent directory.
  for (const auto& path : {root, root / parts[0], file}) {
    const DWORD attributes = GetFileAttributesW(path.c_str());
    if (attributes == INVALID_FILE_ATTRIBUTES ||
        (attributes & FILE_ATTRIBUTE_REPARSE_POINT) != 0) {
      throw winrt::hresult_invalid_argument();
    }
  }
  const DWORD attributes = GetFileAttributesW(file.c_str());
  if ((attributes & FILE_ATTRIBUTE_DIRECTORY) != 0) {
    throw winrt::hresult_invalid_argument();
  }
  return file.wstring();
}

struct ShareState {
  explicit ShareState(HWND owner_window) : owner(owner_window) {}
  HWND owner;
  bool disposed = false;
  std::unique_ptr<Result> pending;
  winrt::Windows::Foundation::IAsyncOperation<StorageFile> opening{nullptr};
  DataTransferManager manager{nullptr};
  std::optional<winrt::event_token> requested;

  void Revoke() noexcept {
    if (manager && requested) {
      try { manager.DataRequested(*requested); } catch (...) {}
    }
    requested.reset();
    manager = nullptr;
  }
};

// Called on the HWND's STA. C++/WinRT resumes this coroutine on that apartment.
// State is independent of FlutterWindow and Dispose completes pending replies
// before the messenger is destroyed. No callback captures a raw window owner.
winrt::fire_and_forget PrepareAndShow(std::shared_ptr<ShareState> state,
                                    std::wstring path, winrt::hstring title) {
  try {
    if (!DataTransferManager::IsSupported()) {
      auto result = std::move(state->pending);
      if (result) result->Success(flutter::EncodableValue(false));
      co_return;
    }
    state->opening = StorageFile::GetFileFromPathAsync(path);
    StorageFile file = co_await state->opening;
    state->opening = nullptr;
    if (state->disposed) co_return;
    if (!IsWindow(state->owner)) {
      auto result = std::move(state->pending);
      if (result) result->Error("SHARE_DETACHED", "The share window is closed.");
      co_return;
    }
    state->Revoke();
    auto interop = winrt::get_activation_factory<DataTransferManager,
                                               IDataTransferManagerInterop>();
    winrt::check_hresult(interop->GetForWindow(state->owner,
        winrt::guid_of<IDataTransferManager>(), winrt::put_abi(state->manager)));
    state->requested = state->manager.DataRequested(
        [file, title](const DataTransferManager&, const DataRequestedEventArgs& args) {
          const auto request = args.Request();
          try {
            auto data = request.Data();
            data.Properties().Title(title);
            data.Properties().Description(L"ZIP archive");
            data.RequestedOperation(DataPackageOperation::Copy);
            auto items = winrt::single_threaded_vector<IStorageItem>();
            items.Append(file);
            data.SetStorageItems(items, true);
          } catch (...) {
            try { request.FailWithDisplayText(L"The ZIP could not be shared."); } catch (...) {}
          }
        });
    winrt::check_hresult(interop->ShowShareUIForWindow(state->owner));
    auto result = std::move(state->pending);
    // The OS accepted a real file handoff, not proof of receiver delivery.
    // File and event handler remain alive; do not delete on sheet dismissal.
    if (result) result->Success(flutter::EncodableValue(true));
  } catch (const winrt::hresult_error& error) {
    state->opening = nullptr;
    state->Revoke();
    auto result = std::move(state->pending);
    if (!result || state->disposed) co_return;
    const auto code = error.code();
    if (code == REGDB_E_CLASSNOTREG || code == E_NOINTERFACE ||
        code == E_NOTIMPL || code == HRESULT_FROM_WIN32(ERROR_NOT_SUPPORTED)) {
      result->Success(flutter::EncodableValue(false));
    } else {
      result->Error("SHARE_FAILED", "The ZIP could not be shared.");
    }
  } catch (...) {
    state->opening = nullptr;
    state->Revoke();
    auto result = std::move(state->pending);
    if (result && !state->disposed) result->Error("SHARE_FAILED", "The ZIP could not be shared.");
  }
}
}  // namespace

struct WindowsArchiveShare::Impl {
  explicit Impl(HWND owner) : state(std::make_shared<ShareState>(owner)) {}
  std::shared_ptr<ShareState> state;
};

WindowsArchiveShare::WindowsArchiveShare(HWND owner)
    : impl_(std::make_unique<Impl>(owner)) {}
WindowsArchiveShare::~WindowsArchiveShare() { Dispose(); }

void WindowsArchiveShare::Share(const std::string& path, const std::string& title,
    std::unique_ptr<Result> result) {
  const auto state = impl_->state;
  if (state->disposed) {
    result->Error("SHARE_DETACHED", "The share window is closed.");
    return;
  }
  if (state->pending) {
    result->Error("SHARE_BUSY", "Another archive is being prepared for sharing.");
    return;
  }
  std::wstring validated;
  winrt::hstring share_title;
  try {
    validated = ValidatedArchive(path);
    if (title.size() > 4096) throw winrt::hresult_invalid_argument();
    // Convert the complete UTF-8 value; byte truncation can split a character.
    share_title = winrt::to_hstring(title.empty() ? "ZIP archive" : title);
  } catch (...) {
    result->Error("INVALID_ARGUMENT", "Only prepared ZIP archives may be shared.");
    return;
  }
  state->pending = std::move(result);
  try {
    PrepareAndShow(state, std::move(validated), std::move(share_title));
  } catch (...) {
    // Allocation of a coroutine frame can fail before its body starts.
    auto failed = std::move(state->pending);
    if (failed) failed->Error("SHARE_FAILED", "The ZIP could not be shared.");
  }
}

void WindowsArchiveShare::Dispose() {
  if (!impl_ || impl_->state->disposed) return;
  const auto state = impl_->state;
  state->disposed = true;
  if (state->pending) {
    auto result = std::move(state->pending);
    result->Error("SHARE_DETACHED", "The share window is closed.");
  }
  if (state->opening) {
    try { state->opening.Cancel(); } catch (...) {}
  }
  state->Revoke();
}

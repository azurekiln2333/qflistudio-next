#include "folder_drop.h"

#include <shlobj.h>

#include <string>
#include <utility>

#include "utils.h"

namespace {

// Keeps memory bounded if Dart never starts listening. Explorer drops are user
// actions, so this is far above any realistic burst.
constexpr size_t kMaxPendingBatches = 16;
// Longest path the Win32 Unicode APIs accept without the \\?\ prefix.
constexpr size_t kMaxPathChars = 32767;
// Length at which the extended-length prefix becomes necessary.
constexpr size_t kExtendedPathThreshold = 248;

// Releases a STGMEDIUM exactly once on scope exit.
class StgMediumHolder {
 public:
  StgMediumHolder() { medium_.pUnkForRelease = nullptr; }
  ~StgMediumHolder() { ::ReleaseStgMedium(&medium_); }

  STGMEDIUM* get() { return &medium_; }
  bool has() const { return medium_.tymed != TYMED_NULL; }

 private:
  STGMEDIUM medium_ = {};
};

std::wstring TrimTrailingSeparators(const std::wstring& path) {
  std::wstring trimmed = path;
  while (trimmed.size() > 3 &&
         (trimmed.back() == L'\\' || trimmed.back() == L'/')) {
    trimmed.pop_back();
  }
  return trimmed;
}

// Prefixes \\?\ so paths beyond MAX_PATH can be queried. UNC shares need the
// \\?\UNC\server\share form. Returns the input unchanged when it is already
// prefixed or short enough.
std::wstring ToExtendedPath(const std::wstring& path) {
  if (path.size() < kExtendedPathThreshold) return path;
  if (path.rfind(L"\\\\?\\", 0) == 0) return path;
  if (path.rfind(L"\\\\", 0) == 0) {
    return L"\\\\?\\UNC\\" + path.substr(2);
  }
  return L"\\\\?\\" + path;
}

}  // namespace

FolderDrop::FolderDrop() = default;

FolderDrop::~FolderDrop() { Unregister(); }

bool FolderDrop::Register(HWND hwnd) {
  if (registered_) return true;
  if (hwnd == nullptr) return false;

  // The thread already holds an STA from RoInitialize in main.cpp.
  // OleInitialize returns S_FALSE on an existing apartment and S_OK when it
  // created one; both are successes and both increment the init count, so both
  // must be balanced by OleUninitialize.
  const HRESULT ole = ::OleInitialize(nullptr);
  if (FAILED(ole)) return false;
  owns_ole_ = true;

  const HRESULT hr = ::RegisterDragDrop(hwnd, this);
  if (FAILED(hr)) {
    ::OleUninitialize();
    owns_ole_ = false;
    return false;
  }

  hwnd_ = hwnd;
  registered_ = true;
  return true;
}

void FolderDrop::Unregister() {
  if (registered_ && hwnd_ != nullptr) {
    ::RevokeDragDrop(hwnd_);
    registered_ = false;
    hwnd_ = nullptr;
  }
  if (owns_ole_) {
    ::OleUninitialize();
    owns_ole_ = false;
  }
  pending_.clear();
  emit_ = nullptr;
  reject_ = nullptr;
  ready_ = false;
  accepts_drag_ = false;
}

std::vector<FolderDrop::PendingBatch> FolderDrop::TakePending() {
  std::vector<PendingBatch> taken(pending_.begin(), pending_.end());
  pending_.clear();
  return taken;
}

void FolderDrop::MarkReady() { ready_ = true; }

void FolderDrop::SetCallbacks(EmitCallback emit, RejectCallback reject) {
  emit_ = std::move(emit);
  reject_ = std::move(reject);
}

bool FolderDrop::ReadPaths(IDataObject* data,
                           std::vector<std::string>* folders,
                           int* file_count) {
  if (data == nullptr) return false;

  FORMATETC format = {CF_HDROP, nullptr, DVASPECT_CONTENT, -1, TYMED_HGLOBAL};
  StgMediumHolder holder;
  if (FAILED(data->GetData(&format, holder.get()))) return false;

  STGMEDIUM* medium = holder.get();
  if (medium->tymed != TYMED_HGLOBAL || medium->hGlobal == nullptr) {
    return false;
  }

  // For CF_HDROP the HDROP is the HGLOBAL itself; DragQueryFileW takes it
  // directly and no GlobalLock/GlobalUnlock pair is involved.
  HDROP drop = reinterpret_cast<HDROP>(medium->hGlobal);

  const UINT count = ::DragQueryFileW(drop, 0xFFFFFFFF, nullptr, 0);
  for (UINT index = 0; index < count; ++index) {
    const UINT length = ::DragQueryFileW(drop, index, nullptr, 0);
    if (length == 0 || length > kMaxPathChars) continue;

    std::wstring buffer(static_cast<size_t>(length) + 1, L'\0');
    const UINT copied = ::DragQueryFileW(drop, index, buffer.data(),
                                         static_cast<UINT>(buffer.size()));
    if (copied == 0) continue;
    buffer.resize(copied);

    // A dropped path may be a directory, a file, or a shell virtual item.
    // Reachable UNC paths return attributes like any local path and are kept.
    const std::wstring probe = ToExtendedPath(buffer);
    const DWORD attributes = ::GetFileAttributesW(probe.c_str());
    if (attributes == INVALID_FILE_ATTRIBUTES) continue;

    if ((attributes & FILE_ATTRIBUTE_DIRECTORY) == 0) {
      // Counted so Drop can report that files are unsupported while still
      // keeping any valid folders from the same batch.
      if (file_count != nullptr) ++(*file_count);
      continue;
    }

    const std::string utf8 = Utf8FromUtf16(TrimTrailingSeparators(buffer).c_str());
    if (!utf8.empty() && folders != nullptr) folders->push_back(utf8);
  }

  return true;
}

void FolderDrop::Deliver(const Batch& batch) {
  if (batch.empty()) return;
  // Monotonic per process, not per object, so a recreated window never reuses
  // an id that Dart has already seen.
  static unsigned long long next_id = 0;
  PendingBatch entry;
  entry.id = std::to_string(next_id++);
  entry.paths = batch;
  if (!ready_) {
    while (pending_.size() >= kMaxPendingBatches) pending_.pop_front();
    pending_.push_back(std::move(entry));
    return;
  }
  if (emit_) emit_(entry);
}

HRESULT STDMETHODCALLTYPE FolderDrop::QueryInterface(REFIID riid,
                                                     void** object) {
  if (object == nullptr) return E_INVALIDARG;
  *object = nullptr;
  if (riid == IID_IUnknown || riid == IID_IDropTarget) {
    *object = static_cast<IDropTarget*>(this);
    AddRef();
    return S_OK;
  }
  return E_NOINTERFACE;
}

ULONG STDMETHODCALLTYPE FolderDrop::AddRef() {
  return static_cast<ULONG>(::InterlockedIncrement(&ref_count_));
}

ULONG STDMETHODCALLTYPE FolderDrop::Release() {
  const ULONG remaining =
      static_cast<ULONG>(::InterlockedDecrement(&ref_count_));
  if (remaining == 0) delete this;
  return remaining;
}

HRESULT STDMETHODCALLTYPE FolderDrop::DragEnter(IDataObject* data,
                                                DWORD key_state,
                                                POINTL point,
                                                DWORD* effect) {
  (void)key_state;
  (void)point;
  if (effect == nullptr) return E_INVALIDARG;

  // Only query the offered format during hover. Reading directory attributes
  // here would block feedback on network paths and repeat the work in Drop.
  // File-only payloads still reach Drop, which explains the rejection.
  FORMATETC format = {CF_HDROP, nullptr, DVASPECT_CONTENT, -1, TYMED_HGLOBAL};
  accepts_drag_ = data != nullptr && data->QueryGetData(&format) == S_OK;
  // Never advertise an effect the source does not allow: AND with COPY and
  // leave NONE when the source offered nothing usable.
  *effect = accepts_drag_
                ? (static_cast<DWORD>(*effect) & DROPEFFECT_COPY)
                : DROPEFFECT_NONE;
  return S_OK;
}

HRESULT STDMETHODCALLTYPE FolderDrop::DragOver(DWORD key_state,
                                               POINTL point,
                                               DWORD* effect) {
  (void)key_state;
  (void)point;
  if (effect == nullptr) return E_INVALIDARG;
  // Constrain to COPY using what the source currently permits. No fallback:
  // when the source disallows COPY the answer must stay NONE.
  *effect = accepts_drag_
                ? (static_cast<DWORD>(*effect) & DROPEFFECT_COPY)
                : DROPEFFECT_NONE;
  return S_OK;
}

HRESULT STDMETHODCALLTYPE FolderDrop::DragLeave() {
  accepts_drag_ = false;
  return S_OK;
}

HRESULT STDMETHODCALLTYPE FolderDrop::Drop(IDataObject* data,
                                           DWORD key_state,
                                           POINTL point,
                                           DWORD* effect) {
  (void)key_state;
  (void)point;
  if (effect == nullptr) return E_INVALIDARG;
  // Remember what the source permitted before we overwrite the value.
  const DWORD allowed = static_cast<DWORD>(*effect);
  const bool copy_allowed = (allowed & DROPEFFECT_COPY) != 0;
  *effect = DROPEFFECT_NONE;

  std::vector<std::string> folders;
  int files = 0;
  const bool readable = ReadPaths(data, &folders, &files);
  accepts_drag_ = false;

  if (!readable) {
    if (ready_ && reject_) reject_("无法读取拖入的内容");
    return S_OK;
  }

  if (folders.empty()) {
    if (ready_ && reject_) {
      reject_(files > 0 ? "只能拖入文件夹，不能拖入文件" : "未找到可用的文件夹");
    }
    return S_OK;
  }

  if (!copy_allowed) {
    // The source never offered COPY, so do not claim the drop.
    if (ready_ && reject_) reject_("该来源不允许拖入文件夹");
    return S_OK;
  }

  // A mixed batch keeps the folders and reports the ignored files.
  if (files > 0 && ready_ && reject_) {
    reject_("已忽略拖入的文件，只打开文件夹");
  }

  // COPY is intake semantics only: the source directories are never moved or
  // deleted.
  *effect = DROPEFFECT_COPY;
  Deliver(folders);
  return S_OK;
}

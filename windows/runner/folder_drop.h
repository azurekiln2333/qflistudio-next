#ifndef RUNNER_FOLDER_DROP_H_
#define RUNNER_FOLDER_DROP_H_

#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <ole2.h>
#include <windows.h>

#include <deque>
#include <functional>
#include <string>
#include <vector>

// Receives directories dragged from Explorer onto the Flutter view.
//
// Registered on the Flutter child HWND, not the top-level window, because the
// child covers the whole client area and is the real drop target. Batches are
// queued until Dart calls `takePending`; only then is the channel used to push
// later drops. The adapter never copies, moves or deletes the source folders:
// the OLE effect is COPY purely as intake semantics.
class FolderDrop : public IDropTarget {
 public:
  using Batch = std::vector<std::string>;

  // A captured drop. |id| is unique per process so Dart can ignore repeats.
  struct PendingBatch {
    std::string id;
    Batch paths;
  };

  // Called when a batch arrives while Dart is already listening.
  using EmitCallback = std::function<void(const PendingBatch& batch)>;
  // Called for input the user needs to hear about (ordinary files only).
  using RejectCallback = std::function<void(const std::string& message)>;

  FolderDrop();
  ~FolderDrop();

  // Registers |hwnd| as an OLE drop target. Returns false on failure.
  bool Register(HWND hwnd);
  void Unregister();

  // Batches captured before Dart signalled readiness, oldest first.
  std::vector<PendingBatch> TakePending();

  // Dart started listening; stop queueing and emit directly.
  void MarkReady();

  // Runs |emit| for batches arriving after readiness.
  void SetCallbacks(EmitCallback emit, RejectCallback reject);

  // IUnknown
  HRESULT STDMETHODCALLTYPE QueryInterface(REFIID riid, void** object) override;
  ULONG STDMETHODCALLTYPE AddRef() override;
  ULONG STDMETHODCALLTYPE Release() override;

  // IDropTarget
  HRESULT STDMETHODCALLTYPE DragEnter(IDataObject* data,
                                      DWORD key_state,
                                      POINTL point,
                                      DWORD* effect) override;
  HRESULT STDMETHODCALLTYPE DragOver(DWORD key_state,
                                     POINTL point,
                                     DWORD* effect) override;
  HRESULT STDMETHODCALLTYPE DragLeave() override;
  HRESULT STDMETHODCALLTYPE Drop(IDataObject* data,
                                 DWORD key_state,
                                 POINTL point,
                                 DWORD* effect) override;

 private:
  // Reads CF_HDROP into separate directory and file lists.
  bool ReadPaths(IDataObject* data,
                 std::vector<std::string>* folders,
                 int* file_count);

  void Deliver(const Batch& batch);

  LONG ref_count_ = 1;
  HWND hwnd_ = nullptr;
  bool registered_ = false;
  // True when this object performed a successful OleInitialize. Per the OLE
  // contract every successful call, including S_FALSE, must be balanced.
  bool owns_ole_ = false;
  bool ready_ = false;
  // Set in DragEnter when the payload is an acceptable CF_HDROP, so DragOver
  // can keep advertising COPY without re-reading the data object.
  bool accepts_drag_ = false;

  // Bounded so a long-running app cannot grow without limit if Dart never
  // subscribes. Oldest batches are dropped first.
  std::deque<PendingBatch> pending_;

  EmitCallback emit_;
  RejectCallback reject_;
};

#endif  // RUNNER_FOLDER_DROP_H_

// automatically generated by the FlatBuffers compiler, do not modify


#ifndef FLATBUFFERS_GENERATED_JSERROR_COM_NEWRELIC_MOBILE_FBS_JSERROR_H_
#define FLATBUFFERS_GENERATED_JSERROR_COM_NEWRELIC_MOBILE_FBS_JSERROR_H_

#include "flatbuffers/flatbuffers.h"

// Ensure the included flatbuffers.h is the same version as when this file was
// generated, otherwise it may not be compatible.
static_assert(FLATBUFFERS_VERSION_MAJOR == 23 &&
              FLATBUFFERS_VERSION_MINOR == 1 &&
              FLATBUFFERS_VERSION_REVISION == 21,
             "Non-compatible flatbuffers version included");

namespace com {
namespace newrelic {
namespace mobile {
namespace fbs {
namespace jserror {

struct Frame;
struct FrameBuilder;
struct FrameT;

struct Thread;
struct ThreadBuilder;
struct ThreadT;

struct JsError;
struct JsErrorBuilder;
struct JsErrorT;

struct FrameT : public ::flatbuffers::NativeTable {
  typedef Frame TableType;
  std::string method{};
  std::string fileName{};
  int32_t lineNumber = 0;
  int32_t column = 0;
};

struct Frame FLATBUFFERS_FINAL_CLASS : private ::flatbuffers::Table {
  typedef FrameT NativeTableType;
  typedef FrameBuilder Builder;
  enum FlatBuffersVTableOffset FLATBUFFERS_VTABLE_UNDERLYING_TYPE {
    VT_METHOD = 4,
    VT_FILENAME = 6,
    VT_LINENUMBER = 8,
    VT_COLUMN = 10
  };
  const ::flatbuffers::String *method() const {
    return GetPointer<const ::flatbuffers::String *>(VT_METHOD);
  }
  ::flatbuffers::String *mutable_method() {
    return GetPointer<::flatbuffers::String *>(VT_METHOD);
  }
  const ::flatbuffers::String *fileName() const {
    return GetPointer<const ::flatbuffers::String *>(VT_FILENAME);
  }
  ::flatbuffers::String *mutable_fileName() {
    return GetPointer<::flatbuffers::String *>(VT_FILENAME);
  }
  int32_t lineNumber() const {
    return GetField<int32_t>(VT_LINENUMBER, 0);
  }
  bool mutate_lineNumber(int32_t _lineNumber = 0) {
    return SetField<int32_t>(VT_LINENUMBER, _lineNumber, 0);
  }
  int32_t column() const {
    return GetField<int32_t>(VT_COLUMN, 0);
  }
  bool mutate_column(int32_t _column = 0) {
    return SetField<int32_t>(VT_COLUMN, _column, 0);
  }
  bool Verify(::flatbuffers::Verifier &verifier) const {
    return VerifyTableStart(verifier) &&
           VerifyOffset(verifier, VT_METHOD) &&
           verifier.VerifyString(method()) &&
           VerifyOffset(verifier, VT_FILENAME) &&
           verifier.VerifyString(fileName()) &&
           VerifyField<int32_t>(verifier, VT_LINENUMBER, 4) &&
           VerifyField<int32_t>(verifier, VT_COLUMN, 4) &&
           verifier.EndTable();
  }
  FrameT *UnPack(const ::flatbuffers::resolver_function_t *_resolver = nullptr) const;
  void UnPackTo(FrameT *_o, const ::flatbuffers::resolver_function_t *_resolver = nullptr) const;
  static ::flatbuffers::Offset<Frame> Pack(::flatbuffers::FlatBufferBuilder &_fbb, const FrameT* _o, const ::flatbuffers::rehasher_function_t *_rehasher = nullptr);
};

struct FrameBuilder {
  typedef Frame Table;
  ::flatbuffers::FlatBufferBuilder &fbb_;
  ::flatbuffers::uoffset_t start_;
  void add_method(::flatbuffers::Offset<::flatbuffers::String> method) {
    fbb_.AddOffset(Frame::VT_METHOD, method);
  }
  void add_fileName(::flatbuffers::Offset<::flatbuffers::String> fileName) {
    fbb_.AddOffset(Frame::VT_FILENAME, fileName);
  }
  void add_lineNumber(int32_t lineNumber) {
    fbb_.AddElement<int32_t>(Frame::VT_LINENUMBER, lineNumber, 0);
  }
  void add_column(int32_t column) {
    fbb_.AddElement<int32_t>(Frame::VT_COLUMN, column, 0);
  }
  explicit FrameBuilder(::flatbuffers::FlatBufferBuilder &_fbb)
        : fbb_(_fbb) {
    start_ = fbb_.StartTable();
  }
  ::flatbuffers::Offset<Frame> Finish() {
    const auto end = fbb_.EndTable(start_);
    auto o = ::flatbuffers::Offset<Frame>(end);
    return o;
  }
};

inline ::flatbuffers::Offset<Frame> CreateFrame(
    ::flatbuffers::FlatBufferBuilder &_fbb,
    ::flatbuffers::Offset<::flatbuffers::String> method = 0,
    ::flatbuffers::Offset<::flatbuffers::String> fileName = 0,
    int32_t lineNumber = 0,
    int32_t column = 0) {
  FrameBuilder builder_(_fbb);
  builder_.add_column(column);
  builder_.add_lineNumber(lineNumber);
  builder_.add_fileName(fileName);
  builder_.add_method(method);
  return builder_.Finish();
}

inline ::flatbuffers::Offset<Frame> CreateFrameDirect(
    ::flatbuffers::FlatBufferBuilder &_fbb,
    const char *method = nullptr,
    const char *fileName = nullptr,
    int32_t lineNumber = 0,
    int32_t column = 0) {
  auto method__ = method ? _fbb.CreateString(method) : 0;
  auto fileName__ = fileName ? _fbb.CreateString(fileName) : 0;
  return com::newrelic::mobile::fbs::jserror::CreateFrame(
      _fbb,
      method__,
      fileName__,
      lineNumber,
      column);
}

::flatbuffers::Offset<Frame> CreateFrame(::flatbuffers::FlatBufferBuilder &_fbb, const FrameT *_o, const ::flatbuffers::rehasher_function_t *_rehasher = nullptr);

struct ThreadT : public ::flatbuffers::NativeTable {
  typedef Thread TableType;
  std::vector<std::unique_ptr<com::newrelic::mobile::fbs::jserror::FrameT>> frames{};
  ThreadT() = default;
  ThreadT(const ThreadT &o);
  ThreadT(ThreadT&&) FLATBUFFERS_NOEXCEPT = default;
  ThreadT &operator=(ThreadT o) FLATBUFFERS_NOEXCEPT;
};

struct Thread FLATBUFFERS_FINAL_CLASS : private ::flatbuffers::Table {
  typedef ThreadT NativeTableType;
  typedef ThreadBuilder Builder;
  enum FlatBuffersVTableOffset FLATBUFFERS_VTABLE_UNDERLYING_TYPE {
    VT_FRAMES = 4
  };
  const ::flatbuffers::Vector<::flatbuffers::Offset<com::newrelic::mobile::fbs::jserror::Frame>> *frames() const {
    return GetPointer<const ::flatbuffers::Vector<::flatbuffers::Offset<com::newrelic::mobile::fbs::jserror::Frame>> *>(VT_FRAMES);
  }
  ::flatbuffers::Vector<::flatbuffers::Offset<com::newrelic::mobile::fbs::jserror::Frame>> *mutable_frames() {
    return GetPointer<::flatbuffers::Vector<::flatbuffers::Offset<com::newrelic::mobile::fbs::jserror::Frame>> *>(VT_FRAMES);
  }
  bool Verify(::flatbuffers::Verifier &verifier) const {
    return VerifyTableStart(verifier) &&
           VerifyOffset(verifier, VT_FRAMES) &&
           verifier.VerifyVector(frames()) &&
           verifier.VerifyVectorOfTables(frames()) &&
           verifier.EndTable();
  }
  ThreadT *UnPack(const ::flatbuffers::resolver_function_t *_resolver = nullptr) const;
  void UnPackTo(ThreadT *_o, const ::flatbuffers::resolver_function_t *_resolver = nullptr) const;
  static ::flatbuffers::Offset<Thread> Pack(::flatbuffers::FlatBufferBuilder &_fbb, const ThreadT* _o, const ::flatbuffers::rehasher_function_t *_rehasher = nullptr);
};

struct ThreadBuilder {
  typedef Thread Table;
  ::flatbuffers::FlatBufferBuilder &fbb_;
  ::flatbuffers::uoffset_t start_;
  void add_frames(::flatbuffers::Offset<::flatbuffers::Vector<::flatbuffers::Offset<com::newrelic::mobile::fbs::jserror::Frame>>> frames) {
    fbb_.AddOffset(Thread::VT_FRAMES, frames);
  }
  explicit ThreadBuilder(::flatbuffers::FlatBufferBuilder &_fbb)
        : fbb_(_fbb) {
    start_ = fbb_.StartTable();
  }
  ::flatbuffers::Offset<Thread> Finish() {
    const auto end = fbb_.EndTable(start_);
    auto o = ::flatbuffers::Offset<Thread>(end);
    return o;
  }
};

inline ::flatbuffers::Offset<Thread> CreateThread(
    ::flatbuffers::FlatBufferBuilder &_fbb,
    ::flatbuffers::Offset<::flatbuffers::Vector<::flatbuffers::Offset<com::newrelic::mobile::fbs::jserror::Frame>>> frames = 0) {
  ThreadBuilder builder_(_fbb);
  builder_.add_frames(frames);
  return builder_.Finish();
}

inline ::flatbuffers::Offset<Thread> CreateThreadDirect(
    ::flatbuffers::FlatBufferBuilder &_fbb,
    const std::vector<::flatbuffers::Offset<com::newrelic::mobile::fbs::jserror::Frame>> *frames = nullptr) {
  auto frames__ = frames ? _fbb.CreateVector<::flatbuffers::Offset<com::newrelic::mobile::fbs::jserror::Frame>>(*frames) : 0;
  return com::newrelic::mobile::fbs::jserror::CreateThread(
      _fbb,
      frames__);
}

::flatbuffers::Offset<Thread> CreateThread(::flatbuffers::FlatBufferBuilder &_fbb, const ThreadT *_o, const ::flatbuffers::rehasher_function_t *_rehasher = nullptr);

struct JsErrorT : public ::flatbuffers::NativeTable {
  typedef JsError TableType;
  std::string name{};
  std::string message{};
  bool fatal = false;
  std::unique_ptr<com::newrelic::mobile::fbs::jserror::ThreadT> thread{};
  std::string buildId{};
  std::string bundleId{};
  JsErrorT() = default;
  JsErrorT(const JsErrorT &o);
  JsErrorT(JsErrorT&&) FLATBUFFERS_NOEXCEPT = default;
  JsErrorT &operator=(JsErrorT o) FLATBUFFERS_NOEXCEPT;
};

struct JsError FLATBUFFERS_FINAL_CLASS : private ::flatbuffers::Table {
  typedef JsErrorT NativeTableType;
  typedef JsErrorBuilder Builder;
  enum FlatBuffersVTableOffset FLATBUFFERS_VTABLE_UNDERLYING_TYPE {
    VT_NAME = 4,
    VT_MESSAGE = 6,
    VT_FATAL = 8,
    VT_THREAD = 10,
    VT_BUILDID = 12,
    VT_BUNDLEID = 14
  };
  const ::flatbuffers::String *name() const {
    return GetPointer<const ::flatbuffers::String *>(VT_NAME);
  }
  ::flatbuffers::String *mutable_name() {
    return GetPointer<::flatbuffers::String *>(VT_NAME);
  }
  const ::flatbuffers::String *message() const {
    return GetPointer<const ::flatbuffers::String *>(VT_MESSAGE);
  }
  ::flatbuffers::String *mutable_message() {
    return GetPointer<::flatbuffers::String *>(VT_MESSAGE);
  }
  bool fatal() const {
    return GetField<uint8_t>(VT_FATAL, 0) != 0;
  }
  bool mutate_fatal(bool _fatal = 0) {
    return SetField<uint8_t>(VT_FATAL, static_cast<uint8_t>(_fatal), 0);
  }
  const com::newrelic::mobile::fbs::jserror::Thread *thread() const {
    return GetPointer<const com::newrelic::mobile::fbs::jserror::Thread *>(VT_THREAD);
  }
  com::newrelic::mobile::fbs::jserror::Thread *mutable_thread() {
    return GetPointer<com::newrelic::mobile::fbs::jserror::Thread *>(VT_THREAD);
  }
  const ::flatbuffers::String *buildId() const {
    return GetPointer<const ::flatbuffers::String *>(VT_BUILDID);
  }
  ::flatbuffers::String *mutable_buildId() {
    return GetPointer<::flatbuffers::String *>(VT_BUILDID);
  }
  const ::flatbuffers::String *bundleId() const {
    return GetPointer<const ::flatbuffers::String *>(VT_BUNDLEID);
  }
  ::flatbuffers::String *mutable_bundleId() {
    return GetPointer<::flatbuffers::String *>(VT_BUNDLEID);
  }
  bool Verify(::flatbuffers::Verifier &verifier) const {
    return VerifyTableStart(verifier) &&
           VerifyOffset(verifier, VT_NAME) &&
           verifier.VerifyString(name()) &&
           VerifyOffset(verifier, VT_MESSAGE) &&
           verifier.VerifyString(message()) &&
           VerifyField<uint8_t>(verifier, VT_FATAL, 1) &&
           VerifyOffset(verifier, VT_THREAD) &&
           verifier.VerifyTable(thread()) &&
           VerifyOffset(verifier, VT_BUILDID) &&
           verifier.VerifyString(buildId()) &&
           VerifyOffset(verifier, VT_BUNDLEID) &&
           verifier.VerifyString(bundleId()) &&
           verifier.EndTable();
  }
  JsErrorT *UnPack(const ::flatbuffers::resolver_function_t *_resolver = nullptr) const;
  void UnPackTo(JsErrorT *_o, const ::flatbuffers::resolver_function_t *_resolver = nullptr) const;
  static ::flatbuffers::Offset<JsError> Pack(::flatbuffers::FlatBufferBuilder &_fbb, const JsErrorT* _o, const ::flatbuffers::rehasher_function_t *_rehasher = nullptr);
};

struct JsErrorBuilder {
  typedef JsError Table;
  ::flatbuffers::FlatBufferBuilder &fbb_;
  ::flatbuffers::uoffset_t start_;
  void add_name(::flatbuffers::Offset<::flatbuffers::String> name) {
    fbb_.AddOffset(JsError::VT_NAME, name);
  }
  void add_message(::flatbuffers::Offset<::flatbuffers::String> message) {
    fbb_.AddOffset(JsError::VT_MESSAGE, message);
  }
  void add_fatal(bool fatal) {
    fbb_.AddElement<uint8_t>(JsError::VT_FATAL, static_cast<uint8_t>(fatal), 0);
  }
  void add_thread(::flatbuffers::Offset<com::newrelic::mobile::fbs::jserror::Thread> thread) {
    fbb_.AddOffset(JsError::VT_THREAD, thread);
  }
  void add_buildId(::flatbuffers::Offset<::flatbuffers::String> buildId) {
    fbb_.AddOffset(JsError::VT_BUILDID, buildId);
  }
  void add_bundleId(::flatbuffers::Offset<::flatbuffers::String> bundleId) {
    fbb_.AddOffset(JsError::VT_BUNDLEID, bundleId);
  }
  explicit JsErrorBuilder(::flatbuffers::FlatBufferBuilder &_fbb)
        : fbb_(_fbb) {
    start_ = fbb_.StartTable();
  }
  ::flatbuffers::Offset<JsError> Finish() {
    const auto end = fbb_.EndTable(start_);
    auto o = ::flatbuffers::Offset<JsError>(end);
    return o;
  }
};

inline ::flatbuffers::Offset<JsError> CreateJsError(
    ::flatbuffers::FlatBufferBuilder &_fbb,
    ::flatbuffers::Offset<::flatbuffers::String> name = 0,
    ::flatbuffers::Offset<::flatbuffers::String> message = 0,
    bool fatal = false,
    ::flatbuffers::Offset<com::newrelic::mobile::fbs::jserror::Thread> thread = 0,
    ::flatbuffers::Offset<::flatbuffers::String> buildId = 0,
    ::flatbuffers::Offset<::flatbuffers::String> bundleId = 0) {
  JsErrorBuilder builder_(_fbb);
  builder_.add_bundleId(bundleId);
  builder_.add_buildId(buildId);
  builder_.add_thread(thread);
  builder_.add_message(message);
  builder_.add_name(name);
  builder_.add_fatal(fatal);
  return builder_.Finish();
}

inline ::flatbuffers::Offset<JsError> CreateJsErrorDirect(
    ::flatbuffers::FlatBufferBuilder &_fbb,
    const char *name = nullptr,
    const char *message = nullptr,
    bool fatal = false,
    ::flatbuffers::Offset<com::newrelic::mobile::fbs::jserror::Thread> thread = 0,
    const char *buildId = nullptr,
    const char *bundleId = nullptr) {
  auto name__ = name ? _fbb.CreateString(name) : 0;
  auto message__ = message ? _fbb.CreateString(message) : 0;
  auto buildId__ = buildId ? _fbb.CreateString(buildId) : 0;
  auto bundleId__ = bundleId ? _fbb.CreateString(bundleId) : 0;
  return com::newrelic::mobile::fbs::jserror::CreateJsError(
      _fbb,
      name__,
      message__,
      fatal,
      thread,
      buildId__,
      bundleId__);
}

::flatbuffers::Offset<JsError> CreateJsError(::flatbuffers::FlatBufferBuilder &_fbb, const JsErrorT *_o, const ::flatbuffers::rehasher_function_t *_rehasher = nullptr);

inline FrameT *Frame::UnPack(const ::flatbuffers::resolver_function_t *_resolver) const {
  auto _o = std::unique_ptr<FrameT>(new FrameT());
  UnPackTo(_o.get(), _resolver);
  return _o.release();
}

inline void Frame::UnPackTo(FrameT *_o, const ::flatbuffers::resolver_function_t *_resolver) const {
  (void)_o;
  (void)_resolver;
  { auto _e = method(); if (_e) _o->method = _e->str(); }
  { auto _e = fileName(); if (_e) _o->fileName = _e->str(); }
  { auto _e = lineNumber(); _o->lineNumber = _e; }
  { auto _e = column(); _o->column = _e; }
}

inline ::flatbuffers::Offset<Frame> Frame::Pack(::flatbuffers::FlatBufferBuilder &_fbb, const FrameT* _o, const ::flatbuffers::rehasher_function_t *_rehasher) {
  return CreateFrame(_fbb, _o, _rehasher);
}

inline ::flatbuffers::Offset<Frame> CreateFrame(::flatbuffers::FlatBufferBuilder &_fbb, const FrameT *_o, const ::flatbuffers::rehasher_function_t *_rehasher) {
  (void)_rehasher;
  (void)_o;
  struct _VectorArgs { ::flatbuffers::FlatBufferBuilder *__fbb; const FrameT* __o; const ::flatbuffers::rehasher_function_t *__rehasher; } _va = { &_fbb, _o, _rehasher}; (void)_va;
  auto _method = _o->method.empty() ? 0 : _fbb.CreateString(_o->method);
  auto _fileName = _o->fileName.empty() ? 0 : _fbb.CreateString(_o->fileName);
  auto _lineNumber = _o->lineNumber;
  auto _column = _o->column;
  return com::newrelic::mobile::fbs::jserror::CreateFrame(
      _fbb,
      _method,
      _fileName,
      _lineNumber,
      _column);
}

inline ThreadT::ThreadT(const ThreadT &o) {
  frames.reserve(o.frames.size());
  for (const auto &frames_ : o.frames) { frames.emplace_back((frames_) ? new com::newrelic::mobile::fbs::jserror::FrameT(*frames_) : nullptr); }
}

inline ThreadT &ThreadT::operator=(ThreadT o) FLATBUFFERS_NOEXCEPT {
  std::swap(frames, o.frames);
  return *this;
}

inline ThreadT *Thread::UnPack(const ::flatbuffers::resolver_function_t *_resolver) const {
  auto _o = std::unique_ptr<ThreadT>(new ThreadT());
  UnPackTo(_o.get(), _resolver);
  return _o.release();
}

inline void Thread::UnPackTo(ThreadT *_o, const ::flatbuffers::resolver_function_t *_resolver) const {
  (void)_o;
  (void)_resolver;
  { auto _e = frames(); if (_e) { _o->frames.resize(_e->size()); for (::flatbuffers::uoffset_t _i = 0; _i < _e->size(); _i++) { if(_o->frames[_i]) { _e->Get(_i)->UnPackTo(_o->frames[_i].get(), _resolver); } else { _o->frames[_i] = std::unique_ptr<com::newrelic::mobile::fbs::jserror::FrameT>(_e->Get(_i)->UnPack(_resolver)); }; } } else { _o->frames.resize(0); } }
}

inline ::flatbuffers::Offset<Thread> Thread::Pack(::flatbuffers::FlatBufferBuilder &_fbb, const ThreadT* _o, const ::flatbuffers::rehasher_function_t *_rehasher) {
  return CreateThread(_fbb, _o, _rehasher);
}

inline ::flatbuffers::Offset<Thread> CreateThread(::flatbuffers::FlatBufferBuilder &_fbb, const ThreadT *_o, const ::flatbuffers::rehasher_function_t *_rehasher) {
  (void)_rehasher;
  (void)_o;
  struct _VectorArgs { ::flatbuffers::FlatBufferBuilder *__fbb; const ThreadT* __o; const ::flatbuffers::rehasher_function_t *__rehasher; } _va = { &_fbb, _o, _rehasher}; (void)_va;
  auto _frames = _o->frames.size() ? _fbb.CreateVector<::flatbuffers::Offset<com::newrelic::mobile::fbs::jserror::Frame>> (_o->frames.size(), [](size_t i, _VectorArgs *__va) { return CreateFrame(*__va->__fbb, __va->__o->frames[i].get(), __va->__rehasher); }, &_va ) : 0;
  return com::newrelic::mobile::fbs::jserror::CreateThread(
      _fbb,
      _frames);
}

inline JsErrorT::JsErrorT(const JsErrorT &o)
      : name(o.name),
        message(o.message),
        fatal(o.fatal),
        thread((o.thread) ? new com::newrelic::mobile::fbs::jserror::ThreadT(*o.thread) : nullptr),
        buildId(o.buildId),
        bundleId(o.bundleId) {
}

inline JsErrorT &JsErrorT::operator=(JsErrorT o) FLATBUFFERS_NOEXCEPT {
  std::swap(name, o.name);
  std::swap(message, o.message);
  std::swap(fatal, o.fatal);
  std::swap(thread, o.thread);
  std::swap(buildId, o.buildId);
  std::swap(bundleId, o.bundleId);
  return *this;
}

inline JsErrorT *JsError::UnPack(const ::flatbuffers::resolver_function_t *_resolver) const {
  auto _o = std::unique_ptr<JsErrorT>(new JsErrorT());
  UnPackTo(_o.get(), _resolver);
  return _o.release();
}

inline void JsError::UnPackTo(JsErrorT *_o, const ::flatbuffers::resolver_function_t *_resolver) const {
  (void)_o;
  (void)_resolver;
  { auto _e = name(); if (_e) _o->name = _e->str(); }
  { auto _e = message(); if (_e) _o->message = _e->str(); }
  { auto _e = fatal(); _o->fatal = _e; }
  { auto _e = thread(); if (_e) { if(_o->thread) { _e->UnPackTo(_o->thread.get(), _resolver); } else { _o->thread = std::unique_ptr<com::newrelic::mobile::fbs::jserror::ThreadT>(_e->UnPack(_resolver)); } } else if (_o->thread) { _o->thread.reset(); } }
  { auto _e = buildId(); if (_e) _o->buildId = _e->str(); }
  { auto _e = bundleId(); if (_e) _o->bundleId = _e->str(); }
}

inline ::flatbuffers::Offset<JsError> JsError::Pack(::flatbuffers::FlatBufferBuilder &_fbb, const JsErrorT* _o, const ::flatbuffers::rehasher_function_t *_rehasher) {
  return CreateJsError(_fbb, _o, _rehasher);
}

inline ::flatbuffers::Offset<JsError> CreateJsError(::flatbuffers::FlatBufferBuilder &_fbb, const JsErrorT *_o, const ::flatbuffers::rehasher_function_t *_rehasher) {
  (void)_rehasher;
  (void)_o;
  struct _VectorArgs { ::flatbuffers::FlatBufferBuilder *__fbb; const JsErrorT* __o; const ::flatbuffers::rehasher_function_t *__rehasher; } _va = { &_fbb, _o, _rehasher}; (void)_va;
  auto _name = _o->name.empty() ? 0 : _fbb.CreateString(_o->name);
  auto _message = _o->message.empty() ? 0 : _fbb.CreateString(_o->message);
  auto _fatal = _o->fatal;
  auto _thread = _o->thread ? CreateThread(_fbb, _o->thread.get(), _rehasher) : 0;
  auto _buildId = _o->buildId.empty() ? 0 : _fbb.CreateString(_o->buildId);
  auto _bundleId = _o->bundleId.empty() ? 0 : _fbb.CreateString(_o->bundleId);
  return com::newrelic::mobile::fbs::jserror::CreateJsError(
      _fbb,
      _name,
      _message,
      _fatal,
      _thread,
      _buildId,
      _bundleId);
}

inline const com::newrelic::mobile::fbs::jserror::JsError *GetJsError(const void *buf) {
  return ::flatbuffers::GetRoot<com::newrelic::mobile::fbs::jserror::JsError>(buf);
}

inline const com::newrelic::mobile::fbs::jserror::JsError *GetSizePrefixedJsError(const void *buf) {
  return ::flatbuffers::GetSizePrefixedRoot<com::newrelic::mobile::fbs::jserror::JsError>(buf);
}

inline JsError *GetMutableJsError(void *buf) {
  return ::flatbuffers::GetMutableRoot<JsError>(buf);
}

inline com::newrelic::mobile::fbs::jserror::JsError *GetMutableSizePrefixedJsError(void *buf) {
  return ::flatbuffers::GetMutableSizePrefixedRoot<com::newrelic::mobile::fbs::jserror::JsError>(buf);
}

inline bool VerifyJsErrorBuffer(
    ::flatbuffers::Verifier &verifier) {
  return verifier.VerifyBuffer<com::newrelic::mobile::fbs::jserror::JsError>(nullptr);
}

inline bool VerifySizePrefixedJsErrorBuffer(
    ::flatbuffers::Verifier &verifier) {
  return verifier.VerifySizePrefixedBuffer<com::newrelic::mobile::fbs::jserror::JsError>(nullptr);
}

inline void FinishJsErrorBuffer(
    ::flatbuffers::FlatBufferBuilder &fbb,
    ::flatbuffers::Offset<com::newrelic::mobile::fbs::jserror::JsError> root) {
  fbb.Finish(root);
}

inline void FinishSizePrefixedJsErrorBuffer(
    ::flatbuffers::FlatBufferBuilder &fbb,
    ::flatbuffers::Offset<com::newrelic::mobile::fbs::jserror::JsError> root) {
  fbb.FinishSizePrefixed(root);
}

inline std::unique_ptr<com::newrelic::mobile::fbs::jserror::JsErrorT> UnPackJsError(
    const void *buf,
    const ::flatbuffers::resolver_function_t *res = nullptr) {
  return std::unique_ptr<com::newrelic::mobile::fbs::jserror::JsErrorT>(GetJsError(buf)->UnPack(res));
}

inline std::unique_ptr<com::newrelic::mobile::fbs::jserror::JsErrorT> UnPackSizePrefixedJsError(
    const void *buf,
    const ::flatbuffers::resolver_function_t *res = nullptr) {
  return std::unique_ptr<com::newrelic::mobile::fbs::jserror::JsErrorT>(GetSizePrefixedJsError(buf)->UnPack(res));
}

}  // namespace jserror
}  // namespace fbs
}  // namespace mobile
}  // namespace newrelic
}  // namespace com

#endif  // FLATBUFFERS_GENERATED_JSERROR_COM_NEWRELIC_MOBILE_FBS_JSERROR_H_
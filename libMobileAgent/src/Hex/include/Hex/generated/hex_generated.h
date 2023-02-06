// automatically generated by the FlatBuffers compiler, do not modify


#ifndef FLATBUFFERS_GENERATED_HEX_COM_NEWRELIC_MOBILE_FBS_HEX_H_
#define FLATBUFFERS_GENERATED_HEX_COM_NEWRELIC_MOBILE_FBS_HEX_H_

#include "flatbuffers/flatbuffers.h"

// Ensure the included flatbuffers.h is the same version as when this file was
// generated, otherwise it may not be compatible.
static_assert(FLATBUFFERS_VERSION_MAJOR == 23 &&
              FLATBUFFERS_VERSION_MINOR == 1 &&
              FLATBUFFERS_VERSION_REVISION == 21,
             "Non-compatible flatbuffers version included");

#include "ios_generated.h"

namespace com {
namespace newrelic {
namespace mobile {
namespace fbs {
namespace hex {

struct Frame;
struct FrameBuilder;
struct FrameT;

struct Thread;
struct ThreadBuilder;
struct ThreadT;

struct HandledException;
struct HandledExceptionBuilder;
struct HandledExceptionT;

struct FrameT : public ::flatbuffers::NativeTable {
  typedef Frame TableType;
  std::string value{};
  std::string className{};
  std::string methodName{};
  std::string fileName{};
  int64_t lineNumber = 0;
  uint64_t address = 0;
};

struct Frame FLATBUFFERS_FINAL_CLASS : private ::flatbuffers::Table {
  typedef FrameT NativeTableType;
  typedef FrameBuilder Builder;
  enum FlatBuffersVTableOffset FLATBUFFERS_VTABLE_UNDERLYING_TYPE {
    VT_VALUE = 4,
    VT_CLASSNAME = 6,
    VT_METHODNAME = 8,
    VT_FILENAME = 10,
    VT_LINENUMBER = 12,
    VT_ADDRESS = 14
  };
  const ::flatbuffers::String *value() const {
    return GetPointer<const ::flatbuffers::String *>(VT_VALUE);
  }
  ::flatbuffers::String *mutable_value() {
    return GetPointer<::flatbuffers::String *>(VT_VALUE);
  }
  const ::flatbuffers::String *className() const {
    return GetPointer<const ::flatbuffers::String *>(VT_CLASSNAME);
  }
  ::flatbuffers::String *mutable_className() {
    return GetPointer<::flatbuffers::String *>(VT_CLASSNAME);
  }
  const ::flatbuffers::String *methodName() const {
    return GetPointer<const ::flatbuffers::String *>(VT_METHODNAME);
  }
  ::flatbuffers::String *mutable_methodName() {
    return GetPointer<::flatbuffers::String *>(VT_METHODNAME);
  }
  const ::flatbuffers::String *fileName() const {
    return GetPointer<const ::flatbuffers::String *>(VT_FILENAME);
  }
  ::flatbuffers::String *mutable_fileName() {
    return GetPointer<::flatbuffers::String *>(VT_FILENAME);
  }
  int64_t lineNumber() const {
    return GetField<int64_t>(VT_LINENUMBER, 0);
  }
  bool mutate_lineNumber(int64_t _lineNumber = 0) {
    return SetField<int64_t>(VT_LINENUMBER, _lineNumber, 0);
  }
  uint64_t address() const {
    return GetField<uint64_t>(VT_ADDRESS, 0);
  }
  bool mutate_address(uint64_t _address = 0) {
    return SetField<uint64_t>(VT_ADDRESS, _address, 0);
  }
  bool Verify(::flatbuffers::Verifier &verifier) const {
    return VerifyTableStart(verifier) &&
           VerifyOffset(verifier, VT_VALUE) &&
           verifier.VerifyString(value()) &&
           VerifyOffset(verifier, VT_CLASSNAME) &&
           verifier.VerifyString(className()) &&
           VerifyOffset(verifier, VT_METHODNAME) &&
           verifier.VerifyString(methodName()) &&
           VerifyOffset(verifier, VT_FILENAME) &&
           verifier.VerifyString(fileName()) &&
           VerifyField<int64_t>(verifier, VT_LINENUMBER, 8) &&
           VerifyField<uint64_t>(verifier, VT_ADDRESS, 8) &&
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
  void add_value(::flatbuffers::Offset<::flatbuffers::String> value) {
    fbb_.AddOffset(Frame::VT_VALUE, value);
  }
  void add_className(::flatbuffers::Offset<::flatbuffers::String> className) {
    fbb_.AddOffset(Frame::VT_CLASSNAME, className);
  }
  void add_methodName(::flatbuffers::Offset<::flatbuffers::String> methodName) {
    fbb_.AddOffset(Frame::VT_METHODNAME, methodName);
  }
  void add_fileName(::flatbuffers::Offset<::flatbuffers::String> fileName) {
    fbb_.AddOffset(Frame::VT_FILENAME, fileName);
  }
  void add_lineNumber(int64_t lineNumber) {
    fbb_.AddElement<int64_t>(Frame::VT_LINENUMBER, lineNumber, 0);
  }
  void add_address(uint64_t address) {
    fbb_.AddElement<uint64_t>(Frame::VT_ADDRESS, address, 0);
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
    ::flatbuffers::Offset<::flatbuffers::String> value = 0,
    ::flatbuffers::Offset<::flatbuffers::String> className = 0,
    ::flatbuffers::Offset<::flatbuffers::String> methodName = 0,
    ::flatbuffers::Offset<::flatbuffers::String> fileName = 0,
    int64_t lineNumber = 0,
    uint64_t address = 0) {
  FrameBuilder builder_(_fbb);
  builder_.add_address(address);
  builder_.add_lineNumber(lineNumber);
  builder_.add_fileName(fileName);
  builder_.add_methodName(methodName);
  builder_.add_className(className);
  builder_.add_value(value);
  return builder_.Finish();
}

inline ::flatbuffers::Offset<Frame> CreateFrameDirect(
    ::flatbuffers::FlatBufferBuilder &_fbb,
    const char *value = nullptr,
    const char *className = nullptr,
    const char *methodName = nullptr,
    const char *fileName = nullptr,
    int64_t lineNumber = 0,
    uint64_t address = 0) {
  auto value__ = value ? _fbb.CreateString(value) : 0;
  auto className__ = className ? _fbb.CreateString(className) : 0;
  auto methodName__ = methodName ? _fbb.CreateString(methodName) : 0;
  auto fileName__ = fileName ? _fbb.CreateString(fileName) : 0;
  return com::newrelic::mobile::fbs::hex::CreateFrame(
      _fbb,
      value__,
      className__,
      methodName__,
      fileName__,
      lineNumber,
      address);
}

::flatbuffers::Offset<Frame> CreateFrame(::flatbuffers::FlatBufferBuilder &_fbb, const FrameT *_o, const ::flatbuffers::rehasher_function_t *_rehasher = nullptr);

struct ThreadT : public ::flatbuffers::NativeTable {
  typedef Thread TableType;
  std::vector<std::unique_ptr<com::newrelic::mobile::fbs::hex::FrameT>> frames{};
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
  const ::flatbuffers::Vector<::flatbuffers::Offset<com::newrelic::mobile::fbs::hex::Frame>> *frames() const {
    return GetPointer<const ::flatbuffers::Vector<::flatbuffers::Offset<com::newrelic::mobile::fbs::hex::Frame>> *>(VT_FRAMES);
  }
  ::flatbuffers::Vector<::flatbuffers::Offset<com::newrelic::mobile::fbs::hex::Frame>> *mutable_frames() {
    return GetPointer<::flatbuffers::Vector<::flatbuffers::Offset<com::newrelic::mobile::fbs::hex::Frame>> *>(VT_FRAMES);
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
  void add_frames(::flatbuffers::Offset<::flatbuffers::Vector<::flatbuffers::Offset<com::newrelic::mobile::fbs::hex::Frame>>> frames) {
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
    ::flatbuffers::Offset<::flatbuffers::Vector<::flatbuffers::Offset<com::newrelic::mobile::fbs::hex::Frame>>> frames = 0) {
  ThreadBuilder builder_(_fbb);
  builder_.add_frames(frames);
  return builder_.Finish();
}

inline ::flatbuffers::Offset<Thread> CreateThreadDirect(
    ::flatbuffers::FlatBufferBuilder &_fbb,
    const std::vector<::flatbuffers::Offset<com::newrelic::mobile::fbs::hex::Frame>> *frames = nullptr) {
  auto frames__ = frames ? _fbb.CreateVector<::flatbuffers::Offset<com::newrelic::mobile::fbs::hex::Frame>>(*frames) : 0;
  return com::newrelic::mobile::fbs::hex::CreateThread(
      _fbb,
      frames__);
}

::flatbuffers::Offset<Thread> CreateThread(::flatbuffers::FlatBufferBuilder &_fbb, const ThreadT *_o, const ::flatbuffers::rehasher_function_t *_rehasher = nullptr);

struct HandledExceptionT : public ::flatbuffers::NativeTable {
  typedef HandledException TableType;
  uint64_t appUuidLow = 0;
  uint64_t appUuidHigh = 0;
  std::string sessionId{};
  uint64_t timestampMs = 0;
  std::string name{};
  std::string message{};
  std::string cause{};
  std::vector<std::unique_ptr<com::newrelic::mobile::fbs::hex::ThreadT>> threads{};
  std::vector<std::unique_ptr<com::newrelic::mobile::fbs::ios::LibraryT>> libraries{};
  HandledExceptionT() = default;
  HandledExceptionT(const HandledExceptionT &o);
  HandledExceptionT(HandledExceptionT&&) FLATBUFFERS_NOEXCEPT = default;
  HandledExceptionT &operator=(HandledExceptionT o) FLATBUFFERS_NOEXCEPT;
};

struct HandledException FLATBUFFERS_FINAL_CLASS : private ::flatbuffers::Table {
  typedef HandledExceptionT NativeTableType;
  typedef HandledExceptionBuilder Builder;
  enum FlatBuffersVTableOffset FLATBUFFERS_VTABLE_UNDERLYING_TYPE {
    VT_APPUUIDLOW = 4,
    VT_APPUUIDHIGH = 6,
    VT_SESSIONID = 8,
    VT_TIMESTAMPMS = 10,
    VT_NAME = 12,
    VT_MESSAGE = 14,
    VT_CAUSE = 16,
    VT_THREADS = 18,
    VT_LIBRARIES = 20
  };
  uint64_t appUuidLow() const {
    return GetField<uint64_t>(VT_APPUUIDLOW, 0);
  }
  bool mutate_appUuidLow(uint64_t _appUuidLow = 0) {
    return SetField<uint64_t>(VT_APPUUIDLOW, _appUuidLow, 0);
  }
  uint64_t appUuidHigh() const {
    return GetField<uint64_t>(VT_APPUUIDHIGH, 0);
  }
  bool mutate_appUuidHigh(uint64_t _appUuidHigh = 0) {
    return SetField<uint64_t>(VT_APPUUIDHIGH, _appUuidHigh, 0);
  }
  const ::flatbuffers::String *sessionId() const {
    return GetPointer<const ::flatbuffers::String *>(VT_SESSIONID);
  }
  ::flatbuffers::String *mutable_sessionId() {
    return GetPointer<::flatbuffers::String *>(VT_SESSIONID);
  }
  uint64_t timestampMs() const {
    return GetField<uint64_t>(VT_TIMESTAMPMS, 0);
  }
  bool mutate_timestampMs(uint64_t _timestampMs = 0) {
    return SetField<uint64_t>(VT_TIMESTAMPMS, _timestampMs, 0);
  }
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
  const ::flatbuffers::String *cause() const {
    return GetPointer<const ::flatbuffers::String *>(VT_CAUSE);
  }
  ::flatbuffers::String *mutable_cause() {
    return GetPointer<::flatbuffers::String *>(VT_CAUSE);
  }
  const ::flatbuffers::Vector<::flatbuffers::Offset<com::newrelic::mobile::fbs::hex::Thread>> *threads() const {
    return GetPointer<const ::flatbuffers::Vector<::flatbuffers::Offset<com::newrelic::mobile::fbs::hex::Thread>> *>(VT_THREADS);
  }
  ::flatbuffers::Vector<::flatbuffers::Offset<com::newrelic::mobile::fbs::hex::Thread>> *mutable_threads() {
    return GetPointer<::flatbuffers::Vector<::flatbuffers::Offset<com::newrelic::mobile::fbs::hex::Thread>> *>(VT_THREADS);
  }
  const ::flatbuffers::Vector<::flatbuffers::Offset<com::newrelic::mobile::fbs::ios::Library>> *libraries() const {
    return GetPointer<const ::flatbuffers::Vector<::flatbuffers::Offset<com::newrelic::mobile::fbs::ios::Library>> *>(VT_LIBRARIES);
  }
  ::flatbuffers::Vector<::flatbuffers::Offset<com::newrelic::mobile::fbs::ios::Library>> *mutable_libraries() {
    return GetPointer<::flatbuffers::Vector<::flatbuffers::Offset<com::newrelic::mobile::fbs::ios::Library>> *>(VT_LIBRARIES);
  }
  bool Verify(::flatbuffers::Verifier &verifier) const {
    return VerifyTableStart(verifier) &&
           VerifyField<uint64_t>(verifier, VT_APPUUIDLOW, 8) &&
           VerifyField<uint64_t>(verifier, VT_APPUUIDHIGH, 8) &&
           VerifyOffset(verifier, VT_SESSIONID) &&
           verifier.VerifyString(sessionId()) &&
           VerifyField<uint64_t>(verifier, VT_TIMESTAMPMS, 8) &&
           VerifyOffset(verifier, VT_NAME) &&
           verifier.VerifyString(name()) &&
           VerifyOffset(verifier, VT_MESSAGE) &&
           verifier.VerifyString(message()) &&
           VerifyOffset(verifier, VT_CAUSE) &&
           verifier.VerifyString(cause()) &&
           VerifyOffset(verifier, VT_THREADS) &&
           verifier.VerifyVector(threads()) &&
           verifier.VerifyVectorOfTables(threads()) &&
           VerifyOffset(verifier, VT_LIBRARIES) &&
           verifier.VerifyVector(libraries()) &&
           verifier.VerifyVectorOfTables(libraries()) &&
           verifier.EndTable();
  }
  HandledExceptionT *UnPack(const ::flatbuffers::resolver_function_t *_resolver = nullptr) const;
  void UnPackTo(HandledExceptionT *_o, const ::flatbuffers::resolver_function_t *_resolver = nullptr) const;
  static ::flatbuffers::Offset<HandledException> Pack(::flatbuffers::FlatBufferBuilder &_fbb, const HandledExceptionT* _o, const ::flatbuffers::rehasher_function_t *_rehasher = nullptr);
};

struct HandledExceptionBuilder {
  typedef HandledException Table;
  ::flatbuffers::FlatBufferBuilder &fbb_;
  ::flatbuffers::uoffset_t start_;
  void add_appUuidLow(uint64_t appUuidLow) {
    fbb_.AddElement<uint64_t>(HandledException::VT_APPUUIDLOW, appUuidLow, 0);
  }
  void add_appUuidHigh(uint64_t appUuidHigh) {
    fbb_.AddElement<uint64_t>(HandledException::VT_APPUUIDHIGH, appUuidHigh, 0);
  }
  void add_sessionId(::flatbuffers::Offset<::flatbuffers::String> sessionId) {
    fbb_.AddOffset(HandledException::VT_SESSIONID, sessionId);
  }
  void add_timestampMs(uint64_t timestampMs) {
    fbb_.AddElement<uint64_t>(HandledException::VT_TIMESTAMPMS, timestampMs, 0);
  }
  void add_name(::flatbuffers::Offset<::flatbuffers::String> name) {
    fbb_.AddOffset(HandledException::VT_NAME, name);
  }
  void add_message(::flatbuffers::Offset<::flatbuffers::String> message) {
    fbb_.AddOffset(HandledException::VT_MESSAGE, message);
  }
  void add_cause(::flatbuffers::Offset<::flatbuffers::String> cause) {
    fbb_.AddOffset(HandledException::VT_CAUSE, cause);
  }
  void add_threads(::flatbuffers::Offset<::flatbuffers::Vector<::flatbuffers::Offset<com::newrelic::mobile::fbs::hex::Thread>>> threads) {
    fbb_.AddOffset(HandledException::VT_THREADS, threads);
  }
  void add_libraries(::flatbuffers::Offset<::flatbuffers::Vector<::flatbuffers::Offset<com::newrelic::mobile::fbs::ios::Library>>> libraries) {
    fbb_.AddOffset(HandledException::VT_LIBRARIES, libraries);
  }
  explicit HandledExceptionBuilder(::flatbuffers::FlatBufferBuilder &_fbb)
        : fbb_(_fbb) {
    start_ = fbb_.StartTable();
  }
  ::flatbuffers::Offset<HandledException> Finish() {
    const auto end = fbb_.EndTable(start_);
    auto o = ::flatbuffers::Offset<HandledException>(end);
    return o;
  }
};

inline ::flatbuffers::Offset<HandledException> CreateHandledException(
    ::flatbuffers::FlatBufferBuilder &_fbb,
    uint64_t appUuidLow = 0,
    uint64_t appUuidHigh = 0,
    ::flatbuffers::Offset<::flatbuffers::String> sessionId = 0,
    uint64_t timestampMs = 0,
    ::flatbuffers::Offset<::flatbuffers::String> name = 0,
    ::flatbuffers::Offset<::flatbuffers::String> message = 0,
    ::flatbuffers::Offset<::flatbuffers::String> cause = 0,
    ::flatbuffers::Offset<::flatbuffers::Vector<::flatbuffers::Offset<com::newrelic::mobile::fbs::hex::Thread>>> threads = 0,
    ::flatbuffers::Offset<::flatbuffers::Vector<::flatbuffers::Offset<com::newrelic::mobile::fbs::ios::Library>>> libraries = 0) {
  HandledExceptionBuilder builder_(_fbb);
  builder_.add_timestampMs(timestampMs);
  builder_.add_appUuidHigh(appUuidHigh);
  builder_.add_appUuidLow(appUuidLow);
  builder_.add_libraries(libraries);
  builder_.add_threads(threads);
  builder_.add_cause(cause);
  builder_.add_message(message);
  builder_.add_name(name);
  builder_.add_sessionId(sessionId);
  return builder_.Finish();
}

inline ::flatbuffers::Offset<HandledException> CreateHandledExceptionDirect(
    ::flatbuffers::FlatBufferBuilder &_fbb,
    uint64_t appUuidLow = 0,
    uint64_t appUuidHigh = 0,
    const char *sessionId = nullptr,
    uint64_t timestampMs = 0,
    const char *name = nullptr,
    const char *message = nullptr,
    const char *cause = nullptr,
    const std::vector<::flatbuffers::Offset<com::newrelic::mobile::fbs::hex::Thread>> *threads = nullptr,
    const std::vector<::flatbuffers::Offset<com::newrelic::mobile::fbs::ios::Library>> *libraries = nullptr) {
  auto sessionId__ = sessionId ? _fbb.CreateString(sessionId) : 0;
  auto name__ = name ? _fbb.CreateString(name) : 0;
  auto message__ = message ? _fbb.CreateString(message) : 0;
  auto cause__ = cause ? _fbb.CreateString(cause) : 0;
  auto threads__ = threads ? _fbb.CreateVector<::flatbuffers::Offset<com::newrelic::mobile::fbs::hex::Thread>>(*threads) : 0;
  auto libraries__ = libraries ? _fbb.CreateVector<::flatbuffers::Offset<com::newrelic::mobile::fbs::ios::Library>>(*libraries) : 0;
  return com::newrelic::mobile::fbs::hex::CreateHandledException(
      _fbb,
      appUuidLow,
      appUuidHigh,
      sessionId__,
      timestampMs,
      name__,
      message__,
      cause__,
      threads__,
      libraries__);
}

::flatbuffers::Offset<HandledException> CreateHandledException(::flatbuffers::FlatBufferBuilder &_fbb, const HandledExceptionT *_o, const ::flatbuffers::rehasher_function_t *_rehasher = nullptr);

inline FrameT *Frame::UnPack(const ::flatbuffers::resolver_function_t *_resolver) const {
  auto _o = std::unique_ptr<FrameT>(new FrameT());
  UnPackTo(_o.get(), _resolver);
  return _o.release();
}

inline void Frame::UnPackTo(FrameT *_o, const ::flatbuffers::resolver_function_t *_resolver) const {
  (void)_o;
  (void)_resolver;
  { auto _e = value(); if (_e) _o->value = _e->str(); }
  { auto _e = className(); if (_e) _o->className = _e->str(); }
  { auto _e = methodName(); if (_e) _o->methodName = _e->str(); }
  { auto _e = fileName(); if (_e) _o->fileName = _e->str(); }
  { auto _e = lineNumber(); _o->lineNumber = _e; }
  { auto _e = address(); _o->address = _e; }
}

inline ::flatbuffers::Offset<Frame> Frame::Pack(::flatbuffers::FlatBufferBuilder &_fbb, const FrameT* _o, const ::flatbuffers::rehasher_function_t *_rehasher) {
  return CreateFrame(_fbb, _o, _rehasher);
}

inline ::flatbuffers::Offset<Frame> CreateFrame(::flatbuffers::FlatBufferBuilder &_fbb, const FrameT *_o, const ::flatbuffers::rehasher_function_t *_rehasher) {
  (void)_rehasher;
  (void)_o;
  struct _VectorArgs { ::flatbuffers::FlatBufferBuilder *__fbb; const FrameT* __o; const ::flatbuffers::rehasher_function_t *__rehasher; } _va = { &_fbb, _o, _rehasher}; (void)_va;
  auto _value = _o->value.empty() ? 0 : _fbb.CreateString(_o->value);
  auto _className = _o->className.empty() ? 0 : _fbb.CreateString(_o->className);
  auto _methodName = _o->methodName.empty() ? 0 : _fbb.CreateString(_o->methodName);
  auto _fileName = _o->fileName.empty() ? 0 : _fbb.CreateString(_o->fileName);
  auto _lineNumber = _o->lineNumber;
  auto _address = _o->address;
  return com::newrelic::mobile::fbs::hex::CreateFrame(
      _fbb,
      _value,
      _className,
      _methodName,
      _fileName,
      _lineNumber,
      _address);
}

inline ThreadT::ThreadT(const ThreadT &o) {
  frames.reserve(o.frames.size());
  for (const auto &frames_ : o.frames) { frames.emplace_back((frames_) ? new com::newrelic::mobile::fbs::hex::FrameT(*frames_) : nullptr); }
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
  { auto _e = frames(); if (_e) { _o->frames.resize(_e->size()); for (::flatbuffers::uoffset_t _i = 0; _i < _e->size(); _i++) { if(_o->frames[_i]) { _e->Get(_i)->UnPackTo(_o->frames[_i].get(), _resolver); } else { _o->frames[_i] = std::unique_ptr<com::newrelic::mobile::fbs::hex::FrameT>(_e->Get(_i)->UnPack(_resolver)); }; } } else { _o->frames.resize(0); } }
}

inline ::flatbuffers::Offset<Thread> Thread::Pack(::flatbuffers::FlatBufferBuilder &_fbb, const ThreadT* _o, const ::flatbuffers::rehasher_function_t *_rehasher) {
  return CreateThread(_fbb, _o, _rehasher);
}

inline ::flatbuffers::Offset<Thread> CreateThread(::flatbuffers::FlatBufferBuilder &_fbb, const ThreadT *_o, const ::flatbuffers::rehasher_function_t *_rehasher) {
  (void)_rehasher;
  (void)_o;
  struct _VectorArgs { ::flatbuffers::FlatBufferBuilder *__fbb; const ThreadT* __o; const ::flatbuffers::rehasher_function_t *__rehasher; } _va = { &_fbb, _o, _rehasher}; (void)_va;
  auto _frames = _o->frames.size() ? _fbb.CreateVector<::flatbuffers::Offset<com::newrelic::mobile::fbs::hex::Frame>> (_o->frames.size(), [](size_t i, _VectorArgs *__va) { return CreateFrame(*__va->__fbb, __va->__o->frames[i].get(), __va->__rehasher); }, &_va ) : 0;
  return com::newrelic::mobile::fbs::hex::CreateThread(
      _fbb,
      _frames);
}

inline HandledExceptionT::HandledExceptionT(const HandledExceptionT &o)
      : appUuidLow(o.appUuidLow),
        appUuidHigh(o.appUuidHigh),
        sessionId(o.sessionId),
        timestampMs(o.timestampMs),
        name(o.name),
        message(o.message),
        cause(o.cause) {
  threads.reserve(o.threads.size());
  for (const auto &threads_ : o.threads) { threads.emplace_back((threads_) ? new com::newrelic::mobile::fbs::hex::ThreadT(*threads_) : nullptr); }
  libraries.reserve(o.libraries.size());
  for (const auto &libraries_ : o.libraries) { libraries.emplace_back((libraries_) ? new com::newrelic::mobile::fbs::ios::LibraryT(*libraries_) : nullptr); }
}

inline HandledExceptionT &HandledExceptionT::operator=(HandledExceptionT o) FLATBUFFERS_NOEXCEPT {
  std::swap(appUuidLow, o.appUuidLow);
  std::swap(appUuidHigh, o.appUuidHigh);
  std::swap(sessionId, o.sessionId);
  std::swap(timestampMs, o.timestampMs);
  std::swap(name, o.name);
  std::swap(message, o.message);
  std::swap(cause, o.cause);
  std::swap(threads, o.threads);
  std::swap(libraries, o.libraries);
  return *this;
}

inline HandledExceptionT *HandledException::UnPack(const ::flatbuffers::resolver_function_t *_resolver) const {
  auto _o = std::unique_ptr<HandledExceptionT>(new HandledExceptionT());
  UnPackTo(_o.get(), _resolver);
  return _o.release();
}

inline void HandledException::UnPackTo(HandledExceptionT *_o, const ::flatbuffers::resolver_function_t *_resolver) const {
  (void)_o;
  (void)_resolver;
  { auto _e = appUuidLow(); _o->appUuidLow = _e; }
  { auto _e = appUuidHigh(); _o->appUuidHigh = _e; }
  { auto _e = sessionId(); if (_e) _o->sessionId = _e->str(); }
  { auto _e = timestampMs(); _o->timestampMs = _e; }
  { auto _e = name(); if (_e) _o->name = _e->str(); }
  { auto _e = message(); if (_e) _o->message = _e->str(); }
  { auto _e = cause(); if (_e) _o->cause = _e->str(); }
  { auto _e = threads(); if (_e) { _o->threads.resize(_e->size()); for (::flatbuffers::uoffset_t _i = 0; _i < _e->size(); _i++) { if(_o->threads[_i]) { _e->Get(_i)->UnPackTo(_o->threads[_i].get(), _resolver); } else { _o->threads[_i] = std::unique_ptr<com::newrelic::mobile::fbs::hex::ThreadT>(_e->Get(_i)->UnPack(_resolver)); }; } } else { _o->threads.resize(0); } }
  { auto _e = libraries(); if (_e) { _o->libraries.resize(_e->size()); for (::flatbuffers::uoffset_t _i = 0; _i < _e->size(); _i++) { if(_o->libraries[_i]) { _e->Get(_i)->UnPackTo(_o->libraries[_i].get(), _resolver); } else { _o->libraries[_i] = std::unique_ptr<com::newrelic::mobile::fbs::ios::LibraryT>(_e->Get(_i)->UnPack(_resolver)); }; } } else { _o->libraries.resize(0); } }
}

inline ::flatbuffers::Offset<HandledException> HandledException::Pack(::flatbuffers::FlatBufferBuilder &_fbb, const HandledExceptionT* _o, const ::flatbuffers::rehasher_function_t *_rehasher) {
  return CreateHandledException(_fbb, _o, _rehasher);
}

inline ::flatbuffers::Offset<HandledException> CreateHandledException(::flatbuffers::FlatBufferBuilder &_fbb, const HandledExceptionT *_o, const ::flatbuffers::rehasher_function_t *_rehasher) {
  (void)_rehasher;
  (void)_o;
  struct _VectorArgs { ::flatbuffers::FlatBufferBuilder *__fbb; const HandledExceptionT* __o; const ::flatbuffers::rehasher_function_t *__rehasher; } _va = { &_fbb, _o, _rehasher}; (void)_va;
  auto _appUuidLow = _o->appUuidLow;
  auto _appUuidHigh = _o->appUuidHigh;
  auto _sessionId = _o->sessionId.empty() ? 0 : _fbb.CreateString(_o->sessionId);
  auto _timestampMs = _o->timestampMs;
  auto _name = _o->name.empty() ? 0 : _fbb.CreateString(_o->name);
  auto _message = _o->message.empty() ? 0 : _fbb.CreateString(_o->message);
  auto _cause = _o->cause.empty() ? 0 : _fbb.CreateString(_o->cause);
  auto _threads = _o->threads.size() ? _fbb.CreateVector<::flatbuffers::Offset<com::newrelic::mobile::fbs::hex::Thread>> (_o->threads.size(), [](size_t i, _VectorArgs *__va) { return CreateThread(*__va->__fbb, __va->__o->threads[i].get(), __va->__rehasher); }, &_va ) : 0;
  auto _libraries = _o->libraries.size() ? _fbb.CreateVector<::flatbuffers::Offset<com::newrelic::mobile::fbs::ios::Library>> (_o->libraries.size(), [](size_t i, _VectorArgs *__va) { return CreateLibrary(*__va->__fbb, __va->__o->libraries[i].get(), __va->__rehasher); }, &_va ) : 0;
  return com::newrelic::mobile::fbs::hex::CreateHandledException(
      _fbb,
      _appUuidLow,
      _appUuidHigh,
      _sessionId,
      _timestampMs,
      _name,
      _message,
      _cause,
      _threads,
      _libraries);
}

inline const com::newrelic::mobile::fbs::hex::HandledException *GetHandledException(const void *buf) {
  return ::flatbuffers::GetRoot<com::newrelic::mobile::fbs::hex::HandledException>(buf);
}

inline const com::newrelic::mobile::fbs::hex::HandledException *GetSizePrefixedHandledException(const void *buf) {
  return ::flatbuffers::GetSizePrefixedRoot<com::newrelic::mobile::fbs::hex::HandledException>(buf);
}

inline HandledException *GetMutableHandledException(void *buf) {
  return ::flatbuffers::GetMutableRoot<HandledException>(buf);
}

inline com::newrelic::mobile::fbs::hex::HandledException *GetMutableSizePrefixedHandledException(void *buf) {
  return ::flatbuffers::GetMutableSizePrefixedRoot<com::newrelic::mobile::fbs::hex::HandledException>(buf);
}

inline bool VerifyHandledExceptionBuffer(
    ::flatbuffers::Verifier &verifier) {
  return verifier.VerifyBuffer<com::newrelic::mobile::fbs::hex::HandledException>(nullptr);
}

inline bool VerifySizePrefixedHandledExceptionBuffer(
    ::flatbuffers::Verifier &verifier) {
  return verifier.VerifySizePrefixedBuffer<com::newrelic::mobile::fbs::hex::HandledException>(nullptr);
}

inline void FinishHandledExceptionBuffer(
    ::flatbuffers::FlatBufferBuilder &fbb,
    ::flatbuffers::Offset<com::newrelic::mobile::fbs::hex::HandledException> root) {
  fbb.Finish(root);
}

inline void FinishSizePrefixedHandledExceptionBuffer(
    ::flatbuffers::FlatBufferBuilder &fbb,
    ::flatbuffers::Offset<com::newrelic::mobile::fbs::hex::HandledException> root) {
  fbb.FinishSizePrefixed(root);
}

inline std::unique_ptr<com::newrelic::mobile::fbs::hex::HandledExceptionT> UnPackHandledException(
    const void *buf,
    const ::flatbuffers::resolver_function_t *res = nullptr) {
  return std::unique_ptr<com::newrelic::mobile::fbs::hex::HandledExceptionT>(GetHandledException(buf)->UnPack(res));
}

inline std::unique_ptr<com::newrelic::mobile::fbs::hex::HandledExceptionT> UnPackSizePrefixedHandledException(
    const void *buf,
    const ::flatbuffers::resolver_function_t *res = nullptr) {
  return std::unique_ptr<com::newrelic::mobile::fbs::hex::HandledExceptionT>(GetSizePrefixedHandledException(buf)->UnPack(res));
}

}  // namespace hex
}  // namespace fbs
}  // namespace mobile
}  // namespace newrelic
}  // namespace com

#endif  // FLATBUFFERS_GENERATED_HEX_COM_NEWRELIC_MOBILE_FBS_HEX_H_

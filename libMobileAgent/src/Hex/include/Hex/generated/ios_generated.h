// automatically generated by the FlatBuffers compiler, do not modify


#ifndef FLATBUFFERS_GENERATED_IOS_COM_NEWRELIC_MOBILE_FBS_IOS_H_
#define FLATBUFFERS_GENERATED_IOS_COM_NEWRELIC_MOBILE_FBS_IOS_H_

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
namespace ios {

struct Library;
struct LibraryBuilder;
struct LibraryT;

enum Arch : uint8_t {
  Arch_armv7 = 0,
  Arch_arm64 = 1,
  Arch_MIN = Arch_armv7,
  Arch_MAX = Arch_arm64
};

inline const Arch (&EnumValuesArch())[2] {
  static const Arch values[] = {
    Arch_armv7,
    Arch_arm64
  };
  return values;
}

inline const char * const *EnumNamesArch() {
  static const char * const names[3] = {
    "armv7",
    "arm64",
    nullptr
  };
  return names;
}

inline const char *EnumNameArch(Arch e) {
  if (::flatbuffers::IsOutRange(e, Arch_armv7, Arch_arm64)) return "";
  const size_t index = static_cast<size_t>(e);
  return EnumNamesArch()[index];
}

struct LibraryT : public ::flatbuffers::NativeTable {
  typedef Library TableType;
  uint64_t uuidLow = 0;
  uint64_t uuidHigh = 0;
  uint64_t address = 0;
  bool userLibrary = false;
  com::newrelic::mobile::fbs::ios::Arch arch = com::newrelic::mobile::fbs::ios::Arch_armv7;
  uint64_t size = 0;
  std::string path{};
};

struct Library FLATBUFFERS_FINAL_CLASS : private ::flatbuffers::Table {
  typedef LibraryT NativeTableType;
  typedef LibraryBuilder Builder;
  enum FlatBuffersVTableOffset FLATBUFFERS_VTABLE_UNDERLYING_TYPE {
    VT_UUIDLOW = 4,
    VT_UUIDHIGH = 6,
    VT_ADDRESS = 8,
    VT_USERLIBRARY = 10,
    VT_ARCH = 12,
    VT_SIZE = 14,
    VT_PATH = 16
  };
  uint64_t uuidLow() const {
    return GetField<uint64_t>(VT_UUIDLOW, 0);
  }
  bool mutate_uuidLow(uint64_t _uuidLow = 0) {
    return SetField<uint64_t>(VT_UUIDLOW, _uuidLow, 0);
  }
  uint64_t uuidHigh() const {
    return GetField<uint64_t>(VT_UUIDHIGH, 0);
  }
  bool mutate_uuidHigh(uint64_t _uuidHigh = 0) {
    return SetField<uint64_t>(VT_UUIDHIGH, _uuidHigh, 0);
  }
  uint64_t address() const {
    return GetField<uint64_t>(VT_ADDRESS, 0);
  }
  bool mutate_address(uint64_t _address = 0) {
    return SetField<uint64_t>(VT_ADDRESS, _address, 0);
  }
  bool userLibrary() const {
    return GetField<uint8_t>(VT_USERLIBRARY, 0) != 0;
  }
  bool mutate_userLibrary(bool _userLibrary = 0) {
    return SetField<uint8_t>(VT_USERLIBRARY, static_cast<uint8_t>(_userLibrary), 0);
  }
  com::newrelic::mobile::fbs::ios::Arch arch() const {
    return static_cast<com::newrelic::mobile::fbs::ios::Arch>(GetField<uint8_t>(VT_ARCH, 0));
  }
  bool mutate_arch(com::newrelic::mobile::fbs::ios::Arch _arch = static_cast<com::newrelic::mobile::fbs::ios::Arch>(0)) {
    return SetField<uint8_t>(VT_ARCH, static_cast<uint8_t>(_arch), 0);
  }
  uint64_t size() const {
    return GetField<uint64_t>(VT_SIZE, 0);
  }
  bool mutate_size(uint64_t _size = 0) {
    return SetField<uint64_t>(VT_SIZE, _size, 0);
  }
  const ::flatbuffers::String *path() const {
    return GetPointer<const ::flatbuffers::String *>(VT_PATH);
  }
  ::flatbuffers::String *mutable_path() {
    return GetPointer<::flatbuffers::String *>(VT_PATH);
  }
  bool Verify(::flatbuffers::Verifier &verifier) const {
    return VerifyTableStart(verifier) &&
           VerifyField<uint64_t>(verifier, VT_UUIDLOW, 8) &&
           VerifyField<uint64_t>(verifier, VT_UUIDHIGH, 8) &&
           VerifyField<uint64_t>(verifier, VT_ADDRESS, 8) &&
           VerifyField<uint8_t>(verifier, VT_USERLIBRARY, 1) &&
           VerifyField<uint8_t>(verifier, VT_ARCH, 1) &&
           VerifyField<uint64_t>(verifier, VT_SIZE, 8) &&
           VerifyOffset(verifier, VT_PATH) &&
           verifier.VerifyString(path()) &&
           verifier.EndTable();
  }
  LibraryT *UnPack(const ::flatbuffers::resolver_function_t *_resolver = nullptr) const;
  void UnPackTo(LibraryT *_o, const ::flatbuffers::resolver_function_t *_resolver = nullptr) const;
  static ::flatbuffers::Offset<Library> Pack(::flatbuffers::FlatBufferBuilder &_fbb, const LibraryT* _o, const ::flatbuffers::rehasher_function_t *_rehasher = nullptr);
};

struct LibraryBuilder {
  typedef Library Table;
  ::flatbuffers::FlatBufferBuilder &fbb_;
  ::flatbuffers::uoffset_t start_;
  void add_uuidLow(uint64_t uuidLow) {
    fbb_.AddElement<uint64_t>(Library::VT_UUIDLOW, uuidLow, 0);
  }
  void add_uuidHigh(uint64_t uuidHigh) {
    fbb_.AddElement<uint64_t>(Library::VT_UUIDHIGH, uuidHigh, 0);
  }
  void add_address(uint64_t address) {
    fbb_.AddElement<uint64_t>(Library::VT_ADDRESS, address, 0);
  }
  void add_userLibrary(bool userLibrary) {
    fbb_.AddElement<uint8_t>(Library::VT_USERLIBRARY, static_cast<uint8_t>(userLibrary), 0);
  }
  void add_arch(com::newrelic::mobile::fbs::ios::Arch arch) {
    fbb_.AddElement<uint8_t>(Library::VT_ARCH, static_cast<uint8_t>(arch), 0);
  }
  void add_size(uint64_t size) {
    fbb_.AddElement<uint64_t>(Library::VT_SIZE, size, 0);
  }
  void add_path(::flatbuffers::Offset<::flatbuffers::String> path) {
    fbb_.AddOffset(Library::VT_PATH, path);
  }
  explicit LibraryBuilder(::flatbuffers::FlatBufferBuilder &_fbb)
        : fbb_(_fbb) {
    start_ = fbb_.StartTable();
  }
  ::flatbuffers::Offset<Library> Finish() {
    const auto end = fbb_.EndTable(start_);
    auto o = ::flatbuffers::Offset<Library>(end);
    return o;
  }
};

inline ::flatbuffers::Offset<Library> CreateLibrary(
    ::flatbuffers::FlatBufferBuilder &_fbb,
    uint64_t uuidLow = 0,
    uint64_t uuidHigh = 0,
    uint64_t address = 0,
    bool userLibrary = false,
    com::newrelic::mobile::fbs::ios::Arch arch = com::newrelic::mobile::fbs::ios::Arch_armv7,
    uint64_t size = 0,
    ::flatbuffers::Offset<::flatbuffers::String> path = 0) {
  LibraryBuilder builder_(_fbb);
  builder_.add_size(size);
  builder_.add_address(address);
  builder_.add_uuidHigh(uuidHigh);
  builder_.add_uuidLow(uuidLow);
  builder_.add_path(path);
  builder_.add_arch(arch);
  builder_.add_userLibrary(userLibrary);
  return builder_.Finish();
}

inline ::flatbuffers::Offset<Library> CreateLibraryDirect(
    ::flatbuffers::FlatBufferBuilder &_fbb,
    uint64_t uuidLow = 0,
    uint64_t uuidHigh = 0,
    uint64_t address = 0,
    bool userLibrary = false,
    com::newrelic::mobile::fbs::ios::Arch arch = com::newrelic::mobile::fbs::ios::Arch_armv7,
    uint64_t size = 0,
    const char *path = nullptr) {
  auto path__ = path ? _fbb.CreateString(path) : 0;
  return com::newrelic::mobile::fbs::ios::CreateLibrary(
      _fbb,
      uuidLow,
      uuidHigh,
      address,
      userLibrary,
      arch,
      size,
      path__);
}

::flatbuffers::Offset<Library> CreateLibrary(::flatbuffers::FlatBufferBuilder &_fbb, const LibraryT *_o, const ::flatbuffers::rehasher_function_t *_rehasher = nullptr);

inline LibraryT *Library::UnPack(const ::flatbuffers::resolver_function_t *_resolver) const {
  auto _o = std::unique_ptr<LibraryT>(new LibraryT());
  UnPackTo(_o.get(), _resolver);
  return _o.release();
}

inline void Library::UnPackTo(LibraryT *_o, const ::flatbuffers::resolver_function_t *_resolver) const {
  (void)_o;
  (void)_resolver;
  { auto _e = uuidLow(); _o->uuidLow = _e; }
  { auto _e = uuidHigh(); _o->uuidHigh = _e; }
  { auto _e = address(); _o->address = _e; }
  { auto _e = userLibrary(); _o->userLibrary = _e; }
  { auto _e = arch(); _o->arch = _e; }
  { auto _e = size(); _o->size = _e; }
  { auto _e = path(); if (_e) _o->path = _e->str(); }
}

inline ::flatbuffers::Offset<Library> Library::Pack(::flatbuffers::FlatBufferBuilder &_fbb, const LibraryT* _o, const ::flatbuffers::rehasher_function_t *_rehasher) {
  return CreateLibrary(_fbb, _o, _rehasher);
}

inline ::flatbuffers::Offset<Library> CreateLibrary(::flatbuffers::FlatBufferBuilder &_fbb, const LibraryT *_o, const ::flatbuffers::rehasher_function_t *_rehasher) {
  (void)_rehasher;
  (void)_o;
  struct _VectorArgs { ::flatbuffers::FlatBufferBuilder *__fbb; const LibraryT* __o; const ::flatbuffers::rehasher_function_t *__rehasher; } _va = { &_fbb, _o, _rehasher}; (void)_va;
  auto _uuidLow = _o->uuidLow;
  auto _uuidHigh = _o->uuidHigh;
  auto _address = _o->address;
  auto _userLibrary = _o->userLibrary;
  auto _arch = _o->arch;
  auto _size = _o->size;
  auto _path = _o->path.empty() ? 0 : _fbb.CreateString(_o->path);
  return com::newrelic::mobile::fbs::ios::CreateLibrary(
      _fbb,
      _uuidLow,
      _uuidHigh,
      _address,
      _userLibrary,
      _arch,
      _size,
      _path);
}

inline const com::newrelic::mobile::fbs::ios::Library *GetLibrary(const void *buf) {
  return ::flatbuffers::GetRoot<com::newrelic::mobile::fbs::ios::Library>(buf);
}

inline const com::newrelic::mobile::fbs::ios::Library *GetSizePrefixedLibrary(const void *buf) {
  return ::flatbuffers::GetSizePrefixedRoot<com::newrelic::mobile::fbs::ios::Library>(buf);
}

inline Library *GetMutableLibrary(void *buf) {
  return ::flatbuffers::GetMutableRoot<Library>(buf);
}

inline com::newrelic::mobile::fbs::ios::Library *GetMutableSizePrefixedLibrary(void *buf) {
  return ::flatbuffers::GetMutableSizePrefixedRoot<com::newrelic::mobile::fbs::ios::Library>(buf);
}

inline bool VerifyLibraryBuffer(
    ::flatbuffers::Verifier &verifier) {
  return verifier.VerifyBuffer<com::newrelic::mobile::fbs::ios::Library>(nullptr);
}

inline bool VerifySizePrefixedLibraryBuffer(
    ::flatbuffers::Verifier &verifier) {
  return verifier.VerifySizePrefixedBuffer<com::newrelic::mobile::fbs::ios::Library>(nullptr);
}

inline void FinishLibraryBuffer(
    ::flatbuffers::FlatBufferBuilder &fbb,
    ::flatbuffers::Offset<com::newrelic::mobile::fbs::ios::Library> root) {
  fbb.Finish(root);
}

inline void FinishSizePrefixedLibraryBuffer(
    ::flatbuffers::FlatBufferBuilder &fbb,
    ::flatbuffers::Offset<com::newrelic::mobile::fbs::ios::Library> root) {
  fbb.FinishSizePrefixed(root);
}

inline std::unique_ptr<com::newrelic::mobile::fbs::ios::LibraryT> UnPackLibrary(
    const void *buf,
    const ::flatbuffers::resolver_function_t *res = nullptr) {
  return std::unique_ptr<com::newrelic::mobile::fbs::ios::LibraryT>(GetLibrary(buf)->UnPack(res));
}

inline std::unique_ptr<com::newrelic::mobile::fbs::ios::LibraryT> UnPackSizePrefixedLibrary(
    const void *buf,
    const ::flatbuffers::resolver_function_t *res = nullptr) {
  return std::unique_ptr<com::newrelic::mobile::fbs::ios::LibraryT>(GetSizePrefixedLibrary(buf)->UnPack(res));
}

}  // namespace ios
}  // namespace fbs
}  // namespace mobile
}  // namespace newrelic
}  // namespace com

#endif  // FLATBUFFERS_GENERATED_IOS_COM_NEWRELIC_MOBILE_FBS_IOS_H_

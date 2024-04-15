// FIXME: bit order seems wrong in output
// @as(*u16, @ptrCast(&file.flags)).*
pub const Flags = packed struct(u16) {
    EncryptedFile: bool = false,
    CompressionOption01: bool = false,
    CompressionOption02: bool = false,
    DataDescriptor: bool = true,
    EnhancedDeflation: bool = false,
    CompressedPatchedData: bool = false,
    StrongEncryption: bool = false,
    _unused_07: bool = false,
    _unused_08: bool = false,
    _unused_09: bool = false,
    _unused_10: bool = false,
    LanguageEncoding: bool = false,
    _reserved_12: bool = false,
    MaskHeaderValues: bool = false,
    _reserved_14: bool = false,
    _reserved_15: bool = false,
};

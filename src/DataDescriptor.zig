// TODO: impl in zipfile output
const DataDescriptor = packed struct {
    CRC32: u32,
    SizeCompressed: u32,
    SizeUncompressed: u32,
};

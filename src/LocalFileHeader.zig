const std = @import("std");
const Allocator = std.mem.Allocator;
const Endian = std.builtin.Endian;

const Flags = @import("Flags.zig").Flags;
const Compression = @import("Compression.zig").Compression;
const ExtraField = @import("ExtraField.zig").ExtraField;
const Version = @import("Version.zig").Version;

const MSDOSTime = @import("util/MSDOS.zig").MSDOSTime;
const MSDOSDate = @import("util/MSDOS.zig").MSDOSDate;

// LocalFileHeader
//  4 | Signature (0x04034B50)
//  2 | Minimum version needed to extract
//  2 | Bit flag
//  2 | Compression method
//  2 | File last modification time (MS-DOS format)
//  2 | File last modification date (MS-DOS format)
//  4 | CRC-32 of uncompressed data
//  4 | Compressed size
//  4 | Uncompressed size
//  2 | File name length (n)
//  2 | Extra field length (m)
//  n | File name
//  m | Extra field

pub const Header = struct {
    const signature: u32 = 0x04034B50;
    ver_min: Version,
    flags: Flags,
    compression: Compression,
    mod_time: MSDOSTime,
    mod_date: MSDOSDate,
    crc32: u32,
    size_compressed: u32,
    size_uncompressed: u32,
    len_filename: u16,
    len_extra_field: u16,
    filename: []const u8,
    extra_field: []const u8,
    raw_header: []const u8,
    raw_data: []const u8,

    pub fn parse(data: []const u8, raw_data: []const u8) !Header {
        const sig = std.mem.readInt(u32, data[0..4], Endian.little);
        if (sig != signature) return error.InvalidSignature;

        const fnlen: u16 = std.mem.readInt(u16, data[26..28], Endian.little);
        const eflen: u16 = std.mem.readInt(u16, data[28..30], Endian.little);
        const size: u32 = 32 + fnlen + eflen;

        return .{
            .ver_min = Version.parseSlice(data[4..6]),
            .flags = .{}, // TODO: impl, std.mem.readIntSliceLittle(u16, data[6..8]),
            .compression = @enumFromInt(std.mem.readInt(u16, data[8..10], Endian.little)),
            .mod_time = MSDOSTime.parseInt(std.mem.readInt(u16, data[10..12], Endian.little)),
            .mod_date = MSDOSDate.parseInt(std.mem.readInt(u16, data[12..14], Endian.little)),
            .crc32 = std.mem.readInt(u32, data[14..18], Endian.little),
            .size_compressed = std.mem.readInt(u32, data[18..22], Endian.little),
            .size_uncompressed = std.mem.readInt(u32, data[22..26], Endian.little),
            .len_filename = fnlen,
            .len_extra_field = eflen,
            .filename = data[30 .. 30 + fnlen],
            .extra_field = data[30 + fnlen .. size],
            .raw_header = data[0..size],
            .raw_data = raw_data,
        };
    }
};

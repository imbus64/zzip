const std = @import("std");
const Allocator = std.mem.Allocator;

const EndOfCentralDirectoryRecord = @import("EndOfCentralDirectoryRecord.zig").EndOfCentralDirectoryRecord;
const Flags = @import("Flags.zig").Flags;
const Compression = @import("Compression.zig").Compression;
const ExtraField = @import("ExtraField.zig").ExtraField;
const Version = @import("Version.zig").Version;

const MSDOSTime = @import("util/MSDOS.zig").MSDOSTime;
const MSDOSDate = @import("util/MSDOS.zig").MSDOSDate;

// CentralDirectoryFileHeader
//  4 | Signature (0x02014B50)
//  2 | Version made by
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
//  2 | File comment length (k)
//  2 | Disk number where file starts
//  2 | Internal file attributes
//  4 | External file attributes
//  4 | Offset of local file header (from start of disk)
//  n | File name
//  m | Extra field
//  k | File comment

pub const Header = struct {
    const signature: u32 = 0x02014B50;
    ver_made_by: Version,
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
    len_comment: u16,
    disk: u16,
    attr_internal: u16,
    attr_external: u32,
    local_header_offset: u32,
    filename: []const u8,
    extra_field: []const u8,
    comment: []const u8,
    raw_header: []const u8,
    raw_data: []const u8,

    // NOTE: assumes single disk
    pub fn iterator(eocd: *const EndOfCentralDirectoryRecord) Iterator {
        const st: u32 = eocd.directory_start_offset;
        const en: u32 = st + eocd.directory_size;
        return .{
            .data = eocd.raw_data[st..en],
            .raw_data = eocd.raw_data,
        };
    }

    pub fn parse(data: []const u8, raw_data: []const u8) !Header {
        const sig = std.mem.readIntLittle(u32, data[0..4]);
        if (sig != signature) return error.InvalidSignature;

        const fnlen: u16 = std.mem.readIntSliceLittle(u16, data[28..30]);
        const eflen: u16 = std.mem.readIntSliceLittle(u16, data[30..32]);
        const clen: u16 = std.mem.readIntSliceLittle(u16, data[32..34]);
        const size: u32 = 46 + fnlen + eflen + clen;

        return .{
            .ver_made_by = Version.parseSlice(data[4..6]),
            .ver_min = Version.parseSlice(data[6..8]),
            .flags = .{}, // TODO: impl, std.mem.readIntSliceLittle(u16, data[8..10]),
            .compression = @enumFromInt(std.mem.readIntSliceLittle(u16, data[10..12])),
            .mod_time = MSDOSTime.parseInt(std.mem.readIntSliceLittle(u16, data[12..14])),
            .mod_date = MSDOSDate.parseInt(std.mem.readIntSliceLittle(u16, data[14..16])),
            .crc32 = std.mem.readIntSliceLittle(u32, data[16..20]),
            .size_compressed = std.mem.readIntSliceLittle(u32, data[20..24]),
            .size_uncompressed = std.mem.readIntSliceLittle(u32, data[24..28]),
            .len_filename = fnlen,
            .len_extra_field = eflen,
            .len_comment = clen,
            .disk = std.mem.readIntSliceLittle(u16, data[34..36]),
            .attr_internal = std.mem.readIntSliceLittle(u16, data[36..38]), // TODO: impl
            .attr_external = std.mem.readIntSliceLittle(u32, data[38..42]), // TODO: impl
            .local_header_offset = std.mem.readIntSliceLittle(u32, data[42..46]),
            .filename = data[46 .. 46 + fnlen],
            .extra_field = data[46 + fnlen .. 46 + fnlen + eflen],
            .comment = data[46 + fnlen + eflen .. 46 + fnlen + eflen + clen],
            .raw_header = data[0..size],
            .raw_data = raw_data,
        };
    }
};

pub const Iterator = struct {
    data: []const u8,
    raw_data: []const u8,
    index: usize = 0,

    pub fn next(it: *Iterator) ?Header {
        if (it.index >= it.data.len) return null;

        const result = Header.parse(
            it.data[it.index..],
            it.raw_data,
        ) catch return null;

        it.index += result.raw_header.len;
        return result;
    }

    pub fn reset(it: *Iterator) void {
        it.index = 0;
    }
};

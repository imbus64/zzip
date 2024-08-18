const std = @import("std");
const Endian = std.builtin.Endian;
const Allocator = std.mem.Allocator;

// EndOfCentralDirectoryRecord
//  4 | Signature (0x06054B50)
//  2 | Number of this disk
//  2 | Disk where central directory starts
//  2 | Numbers of central directory records on this disk
//  2 | Total number of central directory records
//  4 | Size of central directory in bytes (excl. EOCD)
//  4 | Offset to start of central directory (from start of file (disk?))
//  2 | Comment length (n)
//  n | Comment

pub const EndOfCentralDirectoryRecord = struct {
    const signature: u32 = 0x06054B50;
    disk: u16,
    directory_disk: u16,
    records_this_disk: u16,
    total_records: u16,
    directory_size: u32,
    directory_start_offset: u32, // from whole archive or disk?
    comment_length: u16,
    comment: []const u8,
    raw_record: []const u8,
    raw_data: []const u8,

    pub fn parse(data: []const u8) !EndOfCentralDirectoryRecord {
        var eocd: ?[]const u8 = null;
        var clen: u16 = undefined;
        for (2..@min(data.len, 0xFFFF)) |i| {
            const i_clen = data.len - i; // TODO: Cleanup
            clen = std.mem.readVarInt(u16, data[i_clen .. i_clen + 2], Endian.little);
            if (clen != i - 2 and i_clen >= 20) continue;

            const i_sig = data.len - i - 20;
            const sig = std.mem.readVarInt(u32, data[i_sig .. i_sig + 4], Endian.little);
            if (sig != signature) continue;

            eocd = data[i_sig..data.len];
            break;
        }
        if (eocd == null) return error.EndOfCentralDirectoryNotFound;

        return .{
            .disk = std.mem.readVarInt(u16, eocd.?[4..6], Endian.little),
            .directory_disk = std.mem.readVarInt(u16, eocd.?[6..8], Endian.little),
            .records_this_disk = std.mem.readVarInt(u16, eocd.?[8..10], Endian.little),
            .total_records = std.mem.readVarInt(u16, eocd.?[10..12], Endian.little),
            .directory_size = std.mem.readVarInt(u32, eocd.?[12..16], Endian.little),
            .directory_start_offset = std.mem.readVarInt(u32, eocd.?[16..20], Endian.little),
            .comment_length = clen,
            .comment = eocd.?[22 .. 22 + clen],
            .raw_record = eocd.?,
            .raw_data = data,
        };
    }
};

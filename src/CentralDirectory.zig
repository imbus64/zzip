const std = @import("std");

pub const CentralDirectory = struct {
    allocator: std.mem.Allocator,
    disk: u16,
    directory_disk: u16,
    records_this_disk: u16,
    total_records: u16,
    directory_size: u16,
    directory_start_offset: i32, // ?
    comment_length: u16,
    comment: []u8,

    pub fn writeEOCD() void {
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
    }
};

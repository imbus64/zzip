const std = @import("std");
const Crc32 = std.hash.Crc32;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

pub const Compression = enum(u16) {
    None = 0,
    Shrink = 1,
    ReduceFactor1 = 2,
    ReduceFactor2 = 3,
    ReduceFactor3 = 4,
    ReduceFactor4 = 5,
    Implode = 6,
    _reserved_07 = 7,
    Deflate = 8,
    DeflateEnhanced = 9,
    PKWare_DCL_Imploded = 10,
    _reserved_11 = 11,
    BZIP2 = 12,
    _reserved_13 = 13,
    LZMA = 14,
    _reserved_15 = 15,
    _reserved_16 = 16,
    _reserved_17 = 17,
    IBM_TERSE = 18,
    IBM_LZ77_z = 19,
    PPMd_verI_Rev1 = 98,

    pub fn compress(
        comp: Compression,
        alloc: Allocator,
        data: []const u8,
        writer: anytype,
    ) !void {
        try switch (comp) {
            .None => writer.writeAll(data),
            .Deflate => {
                var defl = try std.compress.deflate.compressor(alloc, writer, .{});
                defer defl.deinit();
                _ = try defl.write(data);
                try defl.close();
            },
            else => return error.UnsupportedCompression,
        };
    }

    pub fn uncompress(
        comp: Compression,
        alloc: Allocator,
        data: []const u8,
        writer: anytype,
        crc32: u32,
    ) !void {
        switch (comp) {
            .None => {
                if (Crc32.hash(data) != crc32) return error.FailedCrc32;
                try writer.writeAll(data);
            },
            .Deflate => {
                var fb = std.io.fixedBufferStream(data);

                var defl = try std.compress.deflate.decompressor(alloc, fb.reader(), null);
                defer defl.deinit();
                var defl_r = defl.reader();

                const out_data = try defl_r.readAllAlloc(alloc, std.math.maxInt(usize));
                defer alloc.free(out_data);

                if (Crc32.hash(out_data) != crc32) return error.FailedCrc32;
                try writer.writeAll(out_data);
            },
            else => return error.UnsupportedCompression,
        }
    }
};

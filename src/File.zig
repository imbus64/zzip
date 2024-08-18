const std = @import("std");
const Crc32 = std.hash.Crc32;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const ExtraField = @import("ExtraField.zig").ExtraField;
const Version = @import("Version.zig").Version;
const Flags = @import("Flags.zig").Flags;
const Compression = @import("Compression.zig").Compression;

const MSDOSTime = @import("util/MSDOS.zig").MSDOSTime;
const MSDOSDate = @import("util/MSDOS.zig").MSDOSDate;

// TODO: integrate with headers etc. properly; currently basically two systems
// for extracting and generating
// TODO: rename to ZipFile

pub const File = struct {
    allocator: Allocator,
    ver_made_by: Version = .{}, // TODO
    ver_min: Version = .{}, // TODO
    flags: Flags = .{}, // TODO
    compression: Compression = .None,
    mod_time: MSDOSTime = .{},
    mod_date: MSDOSDate = .{},
    crc32: u32, // computed with magic 0xDEBB20E3 (LE); default crc32 in zig 0.11.0 OK
    //size_compressed: u32,
    file_attr_internal: u16 = 0, // TODO
    file_attr_external: u32 = 0, // TODO
    filename: []const u8, // max len 0xFFFF
    comment: []const u8 = "", // max len 0xFFFF
    raw_data: []const u8,
    extra_fields: ArrayList(ExtraField), // max total bytes 0xFFFF
    // NOTE: iirc max total bytes filename+comment+extfld 0xFFFF

    pub fn init(alloc: Allocator, src_filename: []const u8, filename: []const u8) !File {
        const file = try std.fs.cwd().openFile(src_filename, .{});
        defer file.close();

        const raw_data = try file.readToEndAlloc(alloc, 1 << 31);
        const crc32 = Crc32.hash(raw_data);

        const extra_fields = ArrayList(ExtraField).init(alloc);

        return .{
            .allocator = alloc,
            .ver_made_by = .{
                //.host = .Windows_NTFS,
                .spec = .@"2.0",
            }, // TODO: use zip gen impl as basis, stop hardcoding
            .ver_min = .{
                //.host = .Windows_NTFS,
                .spec = .@"2.0",
            }, // TODO: use zip gen impl as basis, stop hardcoding
            .crc32 = crc32,
            .filename = filename,
            .raw_data = raw_data,
            .extra_fields = extra_fields,
        };
    }

    pub fn deinit(self: *const File) void {
        self.allocator.free(self.raw_data);
        self.extra_fields.deinit();
    }
};

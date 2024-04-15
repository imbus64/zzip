const std = @import("std");
const ArrayList = std.ArrayList;
const Crc32 = std.hash.Crc32;
const assert = std.debug.assert;

pub const ZipArchive = @import("Zip.zig");
pub const ZipFile = @import("File.zig");
pub const Compression = @import("Compression.zig");
pub const ExtraField = @import("ExtraField.zig");
pub const EndOfCentralDirectoryRecord = @import("EndOfCentralDirectoryRecord.zig");
pub const CentralDirectoryFileHeader = @import("CentralDirectoryFileHeader.zig");
pub const LocalFileHeader = @import("LocalFileHeader.zig");

// TODO: full 2.0 spec support
// TODO: self-extracting archive
// TODO: appending to existing archive, incl. updating old file
// TODO: archive diagnostics; format error detection/correction, detecting files
// with no central directory present, etc.

pub fn main() !void {
    //var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    //const alloc = gpa.allocator();
}

test "generate basic zip file" {
    const Zip = ZipArchive.Zip;
    const File = ZipFile.File;
    const ExtendedTimestampEF = ExtraField.ExtendedTimestampEF;

    const START_DIR = "test/files";
    const OUT_CRC32: u32 = 0x3B112710;
    const IN_FILE_LIST = [_][]const u8{
        "source.txt",
        "001.jpg",
        "002.jpg",
        "subdir/003.jpg",
        "subdir/004.jpg",
    };

    const alloc = std.testing.allocator;

    var z = Zip.init(alloc);
    defer z.deinit();

    var ets_ls = try ArrayList(ExtendedTimestampEF).initCapacity(alloc, IN_FILE_LIST.len);
    defer ets_ls.deinit();

    for (IN_FILE_LIST) |filename| {
        const fullname = std.fmt.allocPrint(alloc, "{s}/{s}", .{ START_DIR, filename }) catch continue;
        defer alloc.free(fullname);

        var file = try File.init(alloc, fullname, filename);
        file.compression = .Deflate;

        // NOTE: leaving MS-DOS datetime default for now; 7z/winrar ignore it when extfld present anyway
        var ets = try ets_ls.addOne();
        ets.* = try ExtendedTimestampEF.parseFile(fullname, false);
        try file.extra_fields.append(ets.extraField());

        try z.files.append(file);
    }

    var archive = ArrayList(u8).init(alloc);
    defer archive.deinit();
    try z.write(&archive, null);
    assert(Crc32.hash(archive.items) == OUT_CRC32);
}

test "extract basic zip file" {
    const EOCDRecord = EndOfCentralDirectoryRecord.EndOfCentralDirectoryRecord;
    const DirHeader = CentralDirectoryFileHeader.Header;
    const LocHeader = LocalFileHeader.Header;

    const OUT_DIR = "test/out";
    const OUT_CRC32_SUM: u64 = 0x00000001F6CF62F1;
    const IN_FILE = "test/test.zip";
    const IN_CRC32: u32 = 0x3B112710;

    const alloc = std.testing.allocator;

    const file = try std.fs.cwd().openFile(IN_FILE, .{});
    defer file.close();

    const raw_data = try file.readToEndAlloc(alloc, 1 << 31);
    defer alloc.free(raw_data);
    assert(Crc32.hash(raw_data) == IN_CRC32);
    const eocd = try EOCDRecord.parse(raw_data);

    // NOTE: encryption header unsupported
    // NOTE: data descriptor unsupported
    var crc32_sum: u64 = 0;
    var dir_it = DirHeader.iterator(&eocd);
    while (dir_it.next()) |df| {
        // TODO: include all headers and data in the output slice, not just the main file header
        const lf = try LocHeader.parse(raw_data[df.local_header_offset..], raw_data);
        const filename = try std.fmt.allocPrint(alloc, "{s}/{s}", .{ OUT_DIR, lf.filename });
        defer alloc.free(filename);

        const data_off: usize = df.local_header_offset + 30 + lf.len_filename + lf.len_extra_field;
        const data = raw_data[data_off .. data_off + lf.size_compressed];

        //if (std.mem.lastIndexOf(u8, filename, "/")) |end|
        //    try std.fs.cwd().makePath(filename[0..end]);
        //const out = try std.fs.cwd().createFile(filename, .{});
        //defer out.close();
        var out = ArrayList(u8).init(alloc);
        defer out.deinit();

        try lf.compression.uncompress(alloc, data, out.writer(), df.crc32);
        crc32_sum += Crc32.hash(out.items);
    }
    assert(crc32_sum == OUT_CRC32_SUM);
}

const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const File = std.fs.File;

const ZipFile = @import("File.zig").File;

// TODO: rework, make 'just generate/read a zip file plis'-style stuff its own thing
// TODO: rename to ZipArchive

pub const Zip = struct {
    const Self = @This();
    allocator: Allocator,
    files: ArrayList(ZipFile),
    raw_data: ArrayList(u8),

    pub fn init(alloc: Allocator) Self {
        return .{
            .allocator = alloc,
            .files = ArrayList(ZipFile).init(alloc),
            .raw_data = ArrayList(u8).init(alloc),
        };
    }

    pub fn deinit(self: *const Self) void {
        self.raw_data.deinit();
        for (self.files.items) |file|
            file.deinit();
        self.files.deinit();
    }

    pub fn write(self: *Self, out: *ArrayList(u8), comment: ?[]const u8) !void {
        var arena = std.heap.ArenaAllocator.init(self.allocator);
        const alloc = arena.allocator();
        defer arena.deinit();

        var cdir = ArrayList(u8).init(self.allocator);
        defer cdir.deinit();
        const cdir_w = cdir.writer();

        //var zip = ArrayList(u8).init(self.allocator);
        //defer zip.deinit();
        //const zip_w = zip.writer();
        const out_w = out.writer();

        const entries: u16 = @intCast(self.files.items.len);

        for (self.files.items) |file| {
            defer _ = arena.reset(.retain_capacity);

            const loc_head_off: u32 = @intCast(out.items.len);

            var comp = ArrayList(u8).init(alloc);
            defer comp.deinit();
            try file.compression.compress(alloc, file.raw_data, comp.writer());

            var ef_loclen: u16 = 0;
            var ef_dirlen: u16 = 0;
            for (file.extra_fields.items) |ef| {
                ef_loclen += ef.lenLocal();
                ef_dirlen += ef.lenDirectory();
            }

            // LocalFile
            //header
            try out_w.writeIntLittle(u32, 0x04034B50);
            try out_w.writeStruct(file.ver_min);
            try out_w.writeStruct(file.flags);
            try out_w.writeIntLittle(u16, @intFromEnum(file.compression));
            try out_w.writeStruct(file.mod_time);
            try out_w.writeStruct(file.mod_date);
            try out_w.writeIntLittle(u32, file.crc32);
            try out_w.writeIntLittle(u32, @as(u32, @intCast(comp.items.len)));
            try out_w.writeIntLittle(u32, @as(u32, @intCast(file.raw_data.len)));
            try out_w.writeIntLittle(u16, @as(u16, @intCast(file.filename.len)));
            try out_w.writeIntLittle(u16, ef_loclen);
            try out_w.writeAll(file.filename);
            for (file.extra_fields.items) |ef|
                try ef.writeLocal(out);
            // TODO: encryption header goes here
            //data
            try out_w.writeAll(comp.items);
            // TODO: data descriptor goes here

            // CentralDirectoryFileHeader
            try cdir_w.writeIntLittle(u32, 0x02014B50);
            try cdir_w.writeStruct(file.ver_made_by);
            try cdir_w.writeStruct(file.ver_min);
            try cdir_w.writeStruct(file.flags);
            try cdir_w.writeIntLittle(u16, @intFromEnum(file.compression));
            try cdir_w.writeStruct(file.mod_time);
            try cdir_w.writeStruct(file.mod_date);
            try cdir_w.writeIntLittle(u32, file.crc32);
            try cdir_w.writeIntLittle(u32, @as(u32, @intCast(comp.items.len)));
            try cdir_w.writeIntLittle(u32, @as(u32, @intCast(file.raw_data.len)));
            try cdir_w.writeIntLittle(u16, @as(u16, @intCast(file.filename.len)));
            try cdir_w.writeIntLittle(u16, ef_dirlen);
            try cdir_w.writeIntLittle(u16, @as(u16, @intCast(file.comment.len)));
            try cdir_w.writeIntLittle(u16, 0);
            try cdir_w.writeIntLittle(u16, file.file_attr_internal);
            try cdir_w.writeIntLittle(u32, file.file_attr_external);
            try cdir_w.writeIntLittle(u32, loc_head_off);
            try cdir_w.writeAll(file.filename);
            for (file.extra_fields.items) |ef|
                try ef.writeDirectory(&cdir);
            try cdir_w.writeAll(file.comment);
        }

        const loc_head_off: u32 = @intCast(out.items.len);
        const cdir_head_size: u32 = @intCast(cdir.items.len);

        // EndOfCentralDirectoryRecord
        try cdir_w.writeIntLittle(u32, 0x06054B50);
        try cdir_w.writeIntLittle(u16, 0);
        try cdir_w.writeIntLittle(u16, 0);
        try cdir_w.writeIntLittle(u16, entries);
        try cdir_w.writeIntLittle(u16, entries);
        try cdir_w.writeIntLittle(u32, cdir_head_size);
        try cdir_w.writeIntLittle(u32, loc_head_off);
        try cdir_w.writeIntLittle(u16, if (comment) |c| @as(u16, @intCast(c.len)) else 0);
        if (comment) |c| try cdir_w.writeAll(c);

        try out_w.writeAll(cdir.items);

        //// write file
        //try file_out.writeAll(zip.items);
    }
};

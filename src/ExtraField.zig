const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

// https://libzip.org/specifications/extrafld.txt

// TODO: add all the predefined/common fields

// WARNING: ptr could point to allocated memory (see parse), must remember to free
// FIXME: add something to help manage backing allocations such as above; arena?
pub const ExtraField = struct {
    const Self = @This();
    ptr: *anyopaque,
    id: *const u16,
    lenLocalFn: *const fn (*anyopaque) u16,
    lenDirectoryFn: *const fn (*anyopaque) u16,
    writeLocalFn: *const fn (*anyopaque, *ArrayList(u8)) anyerror!void,
    writeDirectoryFn: *const fn (*anyopaque, *ArrayList(u8)) anyerror!void,

    pub fn lenLocal(self: *const Self) u16 {
        return self.lenLocalFn(self.ptr);
    }

    pub fn lenDirectory(self: *const Self) u16 {
        return self.lenDirectoryFn(self.ptr);
    }

    pub fn writeLocal(self: *const Self, data: *ArrayList(u8)) !void {
        try self.writeLocalFn(self.ptr, data);
    }

    pub fn writeDirectory(self: *const Self, data: *ArrayList(u8)) !void {
        try self.writeDirectoryFn(self.ptr, data);
    }
};

pub const RawExtraField = struct {
    const Self = @This();
    id: u16,
    data: []const u8,

    pub fn iterator(data: []const u8) Iterator {
        return .{
            .data = data,
        };
    }

    pub fn parse(data: []const u8) !Self {
        const id = std.mem.readIntSliceLittle(u16, data[0..2]);
        const len = std.mem.readIntSliceLittle(u16, data[2..4]) + 4;
        if (len != data.len) return error.InvalidSize;
        return .{
            .id = id,
            .data = data[4..len],
        };
    }
};

pub const Iterator = struct {
    const Self = @This();
    data: []const u8,
    index: usize = 0,

    pub fn next(it: *Self) ?RawExtraField {
        if (it.index >= it.data.len) return null;

        const result = RawExtraField.parse(it.data[it.index..]) catch return null;

        it.index += result.data.len + 4;
        return result;
    }

    pub fn reset(it: *Self) void {
        it.index = 0;
    }
};

pub const GenericEF = struct {
    const Self = @This();
    id: u16,
    data: []const u8,

    pub fn parseSlice(data: []const u8) !Self {
        if (std.mem.readIntSliceLittle(u16, data[2..4]) + 4 != data.len) return error.InvalidSize;
        return .{
            .id = std.mem.readIntSliceLittle(u16, data[0..2]),
            .data = data,
        };
    }

    fn lenLocal(ptr: *anyopaque) u16 {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return @truncate(4 + self.data.len);
    }

    fn lenDirectory(ptr: *anyopaque) u16 {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return @truncate(4 + self.data.len);
    }

    fn writeLocal(ptr: *anyopaque, data: *ArrayList(u8)) !void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        const writer = data.writer();
        try writer.writeIntLittle(u16, self.id);
        try writer.writeIntLittle(u16, @as(u16, @intCast(self.data.len)));
        if (self.data.len > 0)
            try writer.writeAll(self.data);
    }

    fn writeDirectory(ptr: *anyopaque, data: *ArrayList(u8)) !void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        const writer = data.writer();
        try writer.writeIntLittle(u16, self.id);
        try writer.writeIntLittle(u16, @as(u16, @intCast(self.data.len)));
        if (self.data.len > 0)
            try writer.writeAll(self.data);
    }

    pub fn extraField(self: *Self) ExtraField {
        return .{
            .ptr = self,
            .id = &self.id,
            .lenLocalFn = lenLocal,
            .lenDirectoryFn = lenDirectory,
            .writeLocalFn = writeLocal,
            .writeDirectoryFn = writeDirectory,
        };
    }
};

pub const TemplateEF = struct {
    const Self = @This();
    pub const id: u16 = 0xFFFF;

    pub fn parseSlice(data: []const u8) !Self {
        if (std.mem.readIntSliceLittle(u16, data[0..2]) != id) return error.InvalidId;
        if (std.mem.readIntSliceLittle(u16, data[2..4]) + 4 != data.len) return error.InvalidSize;
        return .{};
    }

    fn lenLocal(ptr: *anyopaque) u16 {
        const self: *Self = @ptrCast(@alignCast(ptr));
        _ = self;
    }

    fn lenDirectory(ptr: *anyopaque) u16 {
        const self: *Self = @ptrCast(@alignCast(ptr));
        _ = self;
    }

    fn writeLocal(ptr: *anyopaque, data: *ArrayList(u8)) !void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        _ = self;
        const writer = data.writer();
        try writer.writeInt(u16, id, .Little);
        // ExtraField
        //  2 | Header ID
        //  2 | Data length (n)
        //  n | Data
    }

    fn writeDirectory(ptr: *anyopaque, data: *ArrayList(u8)) !void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        _ = self;
        const writer = data.writer();
        try writer.writeInt(u16, id, .Little);
        // ExtraField
        //  2 | Header ID
        //  2 | Data length (n)
        //  n | Data
    }

    pub fn extraField(self: *Self) ExtraField {
        return .{
            .ptr = self,
            .id = &id,
            .lenLocalFn = lenLocal,
            .lenDirectoryFn = lenDirectory,
            .writeLocalFn = writeLocal,
            .writeDirectoryFn = writeDirectory,
        };
    }
};

pub const ExtendedTimestampEF = struct {
    const Self = @This();
    pub const id: u16 = 0x5455;

    flags: packed struct(u8) {
        modified: bool = false,
        accessed: bool = false,
        created: bool = false,
        _reserved_3_7: u5 = 0,
    } = .{},
    modified: ?i32 = null,
    accessed: ?i32 = null,
    created: ?i32 = null,

    pub fn parseSlice(data: []const u8) !Self {
        if (std.mem.readIntSliceLittle(u16, data[0..2]) != id)
            return error.InvalidId;
        if (std.mem.readIntSliceLittle(u16, data[2..4]) + 4 != data.len or data.len < 5)
            return error.InvalidSize;

        var et = Self{};

        var flags = data[4];
        var idx: usize = 5;
        if ((flags & 1) > 0 and idx + 4 <= data.len) {
            et.flags.modified = true;
            et.modified = std.mem.readIntSliceLittle(i32, data[idx .. idx + 4]);
            idx += 4;
        }
        if ((flags & 2) > 0 and idx + 4 <= data.len) {
            et.flags.accessed = true;
            et.accessed = std.mem.readIntSliceLittle(i32, data[idx .. idx + 4]);
            idx += 4;
        }
        if ((flags & 4) > 0 and idx + 4 <= data.len) {
            et.flags.created = true;
            et.created = std.mem.readIntSliceLittle(i32, data[idx .. idx + 4]);
            idx += 4;
        }

        return et;
    }

    pub fn parseFile(filename: []const u8, inclAcc: bool) !Self {
        const file = try std.fs.cwd().openFile(filename, .{});
        defer file.close();
        var et = Self{};
        try et.updateFromFile(&file, inclAcc);
        return et;
    }

    pub fn updateFromFile(self: *Self, file: *const std.fs.File, inclAcc: bool) !void {
        const md = try file.metadata();
        self.modified = blk: {
            self.flags.modified = true;
            break :blk @as(i32, @intCast(@divTrunc(md.modified(), std.time.ns_per_s)));
        };
        self.accessed = blk: {
            self.flags.accessed = inclAcc;
            break :blk if (!inclAcc) null else @as(i32, @intCast(@divTrunc(md.accessed(), std.time.ns_per_s)));
        };
        self.created = blk: {
            const c = md.created();
            self.flags.created = (c != null);
            break :blk if (c == null) null else @as(i32, @intCast(@divTrunc(c.?, std.time.ns_per_s)));
        };
    }

    pub fn reset(self: *Self) void {
        self.flags = .{};
        self.modified = null;
        self.accessed = null;
        self.created = null;
    }

    fn lenDataLocal(self: *Self) u16 {
        return 1 + 4 *
            (@as(u16, @intFromBool(self.flags.modified)) +
            @as(u16, @intFromBool(self.flags.accessed)) +
            @as(u16, @intFromBool(self.flags.created)));
    }

    fn lenDataDirectory(self: *Self) u16 {
        return 1 + 4 * @as(u16, @intFromBool(self.flags.modified));
    }

    fn lenLocal(ptr: *anyopaque) u16 {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return 4 + self.lenDataLocal();
    }

    fn lenDirectory(ptr: *anyopaque) u16 {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return 4 + self.lenDataDirectory();
    }

    fn writeLocal(ptr: *anyopaque, data: *ArrayList(u8)) !void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        const writer = data.writer();
        try writer.writeInt(u16, id, .Little);
        try writer.writeInt(u16, self.lenDataLocal(), .Little);
        try writer.writeStruct(self.flags);
        if (self.modified) |t| try writer.writeInt(i32, t, .Little);
        if (self.accessed) |t| try writer.writeInt(i32, t, .Little);
        if (self.created) |t| try writer.writeInt(i32, t, .Little);
    }

    fn writeDirectory(ptr: *anyopaque, data: *ArrayList(u8)) !void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        const writer = data.writer();
        try writer.writeInt(u16, id, .Little);
        try writer.writeInt(u16, self.lenDataDirectory(), .Little);
        try writer.writeStruct(self.flags);
        if (self.modified) |t| try writer.writeInt(i32, t, .Little);
    }

    pub fn extraField(self: *Self) ExtraField {
        return .{
            .ptr = self,
            .id = &id,
            .lenLocalFn = lenLocal,
            .lenDirectoryFn = lenDirectory,
            .writeLocalFn = writeLocal,
            .writeDirectoryFn = writeDirectory,
        };
    }
};

// FIXME: move out of here
pub const AnnodueUpdateTagEF = struct {
    const Self = @This();
    pub const id: u16 = 0x5055; // UP; UPdate tag

    pub fn parseSlice(data: []const u8) !Self {
        if (std.mem.readIntSliceLittle(u16, data[0..2]) != id) return error.InvalidId;
        if (std.mem.readIntSliceLittle(u16, data[2..4]) != 0 or data.len != 4) return error.InvalidSize;
        return Self{};
    }

    fn lenLocal(_: *anyopaque) u16 {
        return 4;
    }

    fn lenDirectory(_: *anyopaque) u16 {
        return 4;
    }

    fn writeLocal(_: *anyopaque, data: *ArrayList(u8)) !void {
        const writer = data.writer();
        try writer.writeInt(u16, id, .Little);
        try writer.writeInt(u16, 0, .Little);
    }

    fn writeDirectory(ptr: *anyopaque, data: *ArrayList(u8)) !void {
        try writeLocal(ptr, data);
    }

    pub fn extraField(self: *Self) ExtraField {
        return .{
            .ptr = self,
            .id = &id,
            .lenLocalFn = lenLocal,
            .lenDirectoryFn = lenDirectory,
            .writeLocalFn = writeLocal,
            .writeDirectoryFn = writeDirectory,
        };
    }
};

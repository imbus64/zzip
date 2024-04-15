const std = @import("std");
const assert = std.debug.assert;

// TODO: assign based on host system
// FIXME: 7z disagrees with Windows_NTFS?
pub const VersionHost = enum(u8) {
    MSDOS_OS2 = 0,
    Amiga = 1,
    OpenVMS = 2,
    UNIX = 3,
    VM_CMS = 4,
    Atari_ST = 5,
    OS2_HPFS = 6,
    Macintosh = 7,
    Z_System = 8,
    CP_M = 9,
    Windows_NTFS = 10,
    MVS = 11, // OS/390 - Z/OS
    VSE = 12,
    Acorn_Risc = 13,
    VFAT = 14,
    Alternate_MVS = 15,
    BeOS = 16,
    Tandem = 17,
    OS_400 = 18,
    OSX_Darwin = 19,
};

// TODO: min extract spec detection based on features used
pub const VersionSpec = enum(u8) { // n/10 = major, n%10 = minor
    @"1.0" = 10,
    @"1.1" = 11,
    @"2.0" = 20,
    @"2.1" = 21,
    @"2.5" = 25,
    @"2.7" = 27,
    @"4.5" = 45,
    @"4.6" = 46,
    @"5.0" = 50,
    @"5.1" = 51,
    @"5.2" = 52,
    @"6.1" = 61,
    @"6.2" = 62,
    @"6.3" = 63,
};

pub const Version = packed struct(u16) {
    spec: VersionSpec = .@"1.0",
    host: VersionHost = .MSDOS_OS2,

    pub fn parseSlice(slice: []const u8) Version {
        assert(slice.len == 2);
        return .{
            .spec = @enumFromInt(slice[0]),
            .host = @enumFromInt(slice[1]),
        };
    }
};

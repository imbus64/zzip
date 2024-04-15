// TODO: MS-DOS datetime parsing from unix timestamp
// TODO: check if this is needed for correct bit output: @as(*u16, @ptrCast(&file.flags)).*
pub const MSDOSTime = packed struct(u16) {
    seconds: u5 = 0, // real seconds divided by 2
    minute: u6 = 0,
    hour: u5 = 0,

    pub fn parseInt(int: u16) MSDOSTime {
        return .{
            .seconds = @truncate(int & 0b11111),
            .minute = @truncate((int >> 5) & 0b111111),
            .hour = @truncate((int >> 11) & 0b11111),
        };
    }
};

// TODO: MS-DOS datetime parsing from unix timestamp
// TODO: check if this is needed for correct bit output: @as(*u16, @ptrCast(&file.flags)).*
pub const MSDOSDate = packed struct(u16) {
    day: u5 = 1, // min: 1
    month: u4 = 1, // min: 1
    years: u7 = 0, // since 1980

    pub fn parseInt(int: u16) MSDOSDate {
        return .{
            .day = @truncate(int & 0b11111),
            .month = @truncate((int >> 5) & 0b1111),
            .years = @truncate((int >> 9) & 0b1111111),
        };
    }
};

const std = @import("std");
const types = @import("types.zig");

pub fn print_lump(lump: types.Lump, log_fn: *const fn (comptime []u8, anytype) void) void {
    log_fn(
        \\Lump info:
        \\  offset: {}
        \\  len: {}
        \\  version: {}
        \\  fourCC: {any}
        \\
    , .{ lump.file_offset, lump.len, lump.version, lump.fourCC });
}

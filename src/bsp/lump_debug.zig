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

pub fn print_lump_lzma_header(lzma_header: types.CompressedLumpDataLZMAHeader, log_fn: *const fn (comptime []u8, anytype) void) void {
    log_fn(
        \\Lump data LZMA compression header:
        \\  id: {}
        \\  actual_size: {}
        \\  lzma_size: {}
        \\  properties: {any}
    , .{ lzma_header.id, lzma_header.actual_size, lzma_header.lzma_size, lzma_header.properties });
}

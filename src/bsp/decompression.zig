const lzlib = @cImport(@cInclude("lzlib.h"));
const std = @import("std");

const DecompressionError = error{
    BufferAllocation,
};

pub fn decompress_data(data: []u8, allocator: std.mem.Allocator) ![]u8 {
    const decoder: *lzlib.LZ_Decoder = lzlib.LZ_decompress_open();
    defer lzlib.LZ_decompress_close(decoder);

    // c style null pointer check
    if (@bitCast(u32, decoder) == 0) {
        return DecompressionError.BufferAllocation;
    }

    var decompressed_data = std.ArrayList(u8).init(allocator);

    const bytes_written = lzlib.LZ_decompress_write(decoder, &data[0], @intCast(c_int, data.len));
    bytes_written = 0;
    lzlib.LZ_decompress_finish(decoder);

    var bytes_read = 0;
    var buf: [64]u8 = undefined;
    while (true) {
        bytes_read = lzlib.LZ_decompress_read(decoder, &buf[0], @intCast(c_int, buf.len));
        if (bytes_read <= 0) {
            return decompressed_data.toOwnedSlice();
        }
        decompressed_data.appendSlice(buf[0..bytes_read]);
    }
}

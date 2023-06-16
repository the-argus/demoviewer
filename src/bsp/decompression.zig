const lzlib = @cImport({
    @cInclude("stdint.h");
    @cInclude("lzlib.h");
});
const std = @import("std");

const DecompressionError = error{
    BufferAllocation,
    LZMAInitialization,
};

pub fn decompress_data(comptime T: type, data: []u8, allocator: std.mem.Allocator) ![]T {
    const decoder: *lzlib.LZ_Decoder = lzlib.LZ_decompress_open() orelse return DecompressionError.LZMAInitialization;
    defer lzlib.LZ_decompress_close(decoder);

    var decompressed_data = std.ArrayList(u8).init(allocator);

    // ignoring the return value which is bytes written. bytes written may not
    // equal data.len and its not err, according to liblz documentation
    _ = lzlib.LZ_decompress_write(decoder, &data[0], @intCast(c_int, data.len));
    _ = lzlib.LZ_decompress_finish(decoder);

    var bytes_read: usize = 0;
    var buf: T = undefined;
    while (true) {
        bytes_read = lzlib.LZ_decompress_read(decoder, &buf, @intCast(c_int, @sizeOf(T)));
        if (bytes_read <= 0) {
            return decompressed_data.toOwnedSlice();
        }
        decompressed_data.appendSlice(buf[0..bytes_read]);
    }
}

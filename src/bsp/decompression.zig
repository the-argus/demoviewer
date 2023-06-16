const lzlib = @cImport({
    @cInclude("stdint.h");
    @cInclude("lzlib.h");
});
const std = @import("std");

const DecompressionError = error{
    BufferAllocation,
    LZMAInitialization,
    BufferRead,
};

const MAX_FAILED_READS = 3;

pub fn decompress_data(comptime T: type, data: []u8, expected_decompressed_size: usize, allocator: std.mem.Allocator) ![]T {
    const decoder: *lzlib.LZ_Decoder = lzlib.LZ_decompress_open() orelse return DecompressionError.LZMAInitialization;
    defer _ = lzlib.LZ_decompress_close(decoder);

    var decompressed_data = std.ArrayList(T).init(allocator);

    // ignoring the return value which is bytes written. bytes written may not
    // equal data.len and its not err, according to liblz documentation
    _ = lzlib.LZ_decompress_write(decoder, &data[0], @intCast(c_int, data.len));
    _ = lzlib.LZ_decompress_finish(decoder);

    var total_bytes_read: usize = 0;
    var failed_reads: usize = 0;
    while (true) {
        var buf: [@sizeOf(T)]u8 = undefined;
        const c_bytes_read: c_int = lzlib.LZ_decompress_read(decoder, &buf, @intCast(c_int, buf.len));
        if (c_bytes_read <= 0) {
            if (failed_reads >= MAX_FAILED_READS) {
                return DecompressionError.BufferRead;
            }
            failed_reads += 1;
            continue;
        }

        if (c_bytes_read != buf.len) {
            @panic("It read less than requested. Not really sure how I'm supposed to handle that atm. The manual is hard to understand :(");
        }

        try decompressed_data.append(@ptrCast(*T, @alignCast(@alignOf(T), &buf)).*);

        total_bytes_read += @intCast(usize, c_bytes_read);

        if (total_bytes_read >= expected_decompressed_size) {
            return decompressed_data.toOwnedSlice();
        }
    }
}

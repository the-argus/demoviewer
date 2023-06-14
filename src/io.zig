///
/// I/O related utilities
///
const std = @import("std");

pub const DemoviewerIOError = error{
    EarlyTermination,
};

pub fn readObject(file: std.fs.File, comptime T: type) !T {
    var object: T = undefined;
    {
        var buf: [@sizeOf(T)]u8 = undefined;
        const bytes_read = try file.read(&buf);
        if (bytes_read < buf.len) {
            return DemoviewerIOError.EarlyTermination;
        }
        object = @bitCast(T, buf);
    }
    return object;
}

pub fn readObjectDirectOut(file: std.fs.File, comptime T: type, out: *T) !void {
    const bytes_read = try file.read(@ptrCast(*[@sizeOf(T)]u8, out));
    if (bytes_read < @sizeOf(T)) {
        return DemoviewerIOError.EarlyTermination;
    }
}

const std = @import("std");
const types = @import("types.zig");

const BspReadError = error{
    EarlyTermination,
};

const log = std.log.scoped(.demoviewer);

/// a function to read BSPs which currently only prints its findings to log
pub fn read_bsp(absolute_path: []const u8) !void {
    log.info("Attempting to open {s} as absolute path", .{absolute_path});
    const bsp_file = try std.fs.openFileAbsolute(absolute_path, .{ .mode = .read_only });
    defer bsp_file.close();

    var header: types.Header = undefined;
    {
        var buf: [@sizeOf(types.Header)]u8 = undefined;
        const bytes_read = try bsp_file.read(&buf);
        if (bytes_read < buf.len) {
            return BspReadError.EarlyTermination;
        }
        header = @bitCast(types.Header, buf);
    }

    log.debug("identifier: {}", .{header.ident});
    log.debug("bsp file version: {}", .{header.version});
    log.debug("map revision: {}", .{header.mapRevision});
    if (header.ident != types.HEADER_IDENT) {
        log.warn("Header identifier mismatch. File may be corrupted. Got {}, expected {}", .{ header.ident, types.HEADER_IDENT });
    }
    if (header.version != types.TF2_BSP_VERSION) {
        log.warn("BSP format version {} does not match expected {}", .{ header.version, types.TF2_BSP_VERSION });
        log.info("This demo file may be from a game which used a different version of the source/quake engine.", .{});
    }
}

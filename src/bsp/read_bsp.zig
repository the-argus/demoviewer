const std = @import("std");
const builtin = @import("builtin");
const types = @import("types.zig");
const lump_types = @import("lump_types.zig");
const demoviewer_io = @import("../io.zig");
const readObject = demoviewer_io.readObject;
const print_lump = @import("lump_debug.zig").print_lump;

const BspReadError = error{
    EarlyTermination,
    Corruption,
};

const log = std.log.scoped(.demoviewer);

/// a function to read BSPs which currently only prints its findings to log
pub fn read_bsp(allocator: std.mem.Allocator, absolute_path: []const u8) !void {
    log.info("Attempting to open {s} as absolute path", .{absolute_path});
    const bsp_file = try std.fs.openFileAbsolute(absolute_path, .{ .mode = .read_only });
    defer bsp_file.close();

    var header = try readObject(bsp_file, types.Header);

    log.debug("identifier: {}", .{header.ident});
    log.debug("bsp file version: {}", .{header.version});
    log.debug("map revision: {}", .{header.mapRevision});
    if (header.ident != types.HEADER_IDENT) {
        log.warn("Header identifier mismatch. File may be corrupted. Got {}, expected {}", .{ header.ident, types.HEADER_IDENT });
    }
    if (header.version != types.TF2_BSP_VERSION) {
        log.warn("BSP format version {} does not match expected {}", .{ header.version, types.TF2_BSP_VERSION });
        log.info("This BSP file may be from a game which used a different version of the source/quake engine.", .{});
    }

    const planes = try read_lump(bsp_file, allocator, &header.lumps, lump_types.lump_type_enum.LUMP_PLANES);
    for (planes, 0..) |plane, index| {
        log.debug("Plane {} normal: {}", .{ index, plane.normal });
    }
    allocator.free(planes);
}

/// reads the contents pointed at by a given lump
pub fn read_lump(
    file: std.fs.File,
    allocator: std.mem.Allocator,
    all_lumps: *[types.HEADER_LUMPS]types.Lump,
    comptime lump_type: lump_types.lump_type_enum,
) ![]lump_types.lump_index_to_type(@enumToInt(lump_type)) {
    const index = comptime @enumToInt(lump_type);
    const realtype = comptime lump_types.lump_index_to_type(index);
    const lump = all_lumps.*[index];
    print_lump(lump, &log.debug);
    try file.seekTo(@intCast(u64, lump.file_offset));

    const bytes_to_alloc = lump.len;
    // sanity check
    {
        const filesize = (try file.metadata()).size();
        if (bytes_to_alloc >= filesize or bytes_to_alloc < 0) {
            log.warn("Corruption detected in lump at index {}", .{lump_type});
            if (builtin.mode == .Debug) {
                return BspReadError.Corruption;
            }
        }
    }

    var lump_items_to_read = block: {
        const num = @intToFloat(f32, lump.len) / @intToFloat(f32, @sizeOf(realtype));
        const decimal = @mod(num, 1);
        if (decimal != 0) {
            log.warn(
                \\Lump length is not evenly divisible by lump size.
                \\Either the zig type does not match the size of the original
                \\C++ struct, or some corruption or misread is happening.
                \\
            , .{});
            log.debug("lump.len: {}\t@sizeOf(realtype): {}\tDecimal remainder: {}", .{ lump.len, @sizeOf(realtype), decimal });
            if (builtin.mode == .Debug) {
                return BspReadError.Corruption;
            }
        }
        break :block @floatToInt(usize, num);
    };

    // safe to intcast since we did the check
    var mem = try allocator.alloc(realtype, lump_items_to_read);

    while (lump_items_to_read > 0) {
        lump_items_to_read -= 1;
        mem[lump_items_to_read] = try readObject(file, realtype);
    }

    return mem;
}

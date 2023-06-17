const std = @import("std");
const builtin = @import("builtin");
const types = @import("types.zig");
const lump_types = @import("lump_types.zig");
const demoviewer_io = @import("../io.zig");
const readObject = demoviewer_io.readObject;
const lump_debug = @import("lump_debug.zig");
const print_lump = lump_debug.print_lump;
const decompress_data = @import("decompression.zig").decompress_data;

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
    // sanity check the lump header, which was already read
    {
        const filesize = (try file.metadata()).size();
        if (bytes_to_alloc >= filesize or bytes_to_alloc < 0) {
            log.warn("Corruption detected in lump at index {}", .{lump_type});
            if (builtin.mode == .Debug) {
                return BspReadError.Corruption;
            }
        }
    }

    // start reading by trying a lzma header and seeing if the actual size corresponds
    {
        const orig_pos = try file.getPos();

        // TODO: create a generic solution for this. reading a type w/o padding.
        var lzma_header: types.CompressedLumpDataLZMAHeader = undefined;
        lzma_header.id = try readObject(file, @TypeOf(lzma_header.id));
        lzma_header.actual_size = try readObject(file, @TypeOf(lzma_header.actual_size));
        lzma_header.lzma_size = try readObject(file, @TypeOf(lzma_header.lzma_size));
        lzma_header.properties = try readObject(file, @TypeOf(lzma_header.properties));

        lump_debug.print_lump_lzma_header(lzma_header, &log.debug);

        const final_pos = try file.getPos();
        const total_read = final_pos - orig_pos;

        if (lzma_header.lzma_size == @intCast(u64, lump.len) - total_read) {
            // this is probably not a coincidence...
            log.debug("Reading compressed lump data...", .{});
            return read_lump_data_compressed(realtype, file, allocator, lump, lzma_header);
        }
    }

    log.debug("Reading UNcompressed lump data...", .{});
    return read_lump_data_uncompressed(realtype, file, allocator, lump);
}

/// Read the data a lump in a BSP file is pointing to, assuming it is compressed
/// does not check if lump.len is valid, may panic
fn read_lump_data_compressed(
    comptime LumpDataType: type,
    file: std.fs.File,
    allocator: std.mem.Allocator,
    lump: types.Lump,
    lzma_header: types.CompressedLumpDataLZMAHeader,
) ![]LumpDataType {
    try file.seekTo(@intCast(u64, lump.file_offset) + @sizeOf(types.CompressedLumpDataLZMAHeader));
    // perform a massive heap allocation of this lump's whole data
    var rawmem = try allocator.alloc(u8, @intCast(usize, lump.len));
    defer allocator.free(rawmem);
    const bytes_read = try file.read(rawmem);

    if (bytes_read != rawmem.len) {
        return BspReadError.EarlyTermination;
    }

    return decompress_data(LumpDataType, rawmem, lzma_header.actual_size, allocator);
}

/// read lump data directly from a file if the lump's data is not compressed
fn read_lump_data_uncompressed(comptime LumpDataType: type, file: std.fs.File, allocator: std.mem.Allocator, lump: types.Lump) ![]LumpDataType {
    try file.seekTo(@intCast(u64, lump.file_offset));

    var lump_items_to_read = try get_items_in_lump_data(LumpDataType, lump);

    // safe to intcast since we did the check
    var mem = try allocator.alloc(LumpDataType, lump_items_to_read);

    while (lump_items_to_read > 0) {
        lump_items_to_read -= 1;
        mem[lump_items_to_read] = try readObject(file, LumpDataType);
    }

    return mem;
}

/// does not check if lump.len is valid, may panic
fn get_items_in_lump_data(comptime LumpDataType: type, lump: types.Lump) !usize {
    // TODO: this decimal remainder check is unecessary, remove it or move it to some assert_compression_good or something
    const num = @intToFloat(f32, lump.len) / @intToFloat(f32, @sizeOf(LumpDataType));
    const decimal = @mod(num, 1);
    if (decimal != 0) {
        log.warn(
            \\Lump length is not evenly divisible by lump size.
            \\Either the zig type does not match the size of the original
            \\C++ struct, or some corruption or misread is happening.
            \\
        , .{});
        log.debug("lump.len: {}\t@sizeOf(LumpDataType): {}\tDecimal remainder: {}", .{ lump.len, @sizeOf(LumpDataType), decimal });
        if (builtin.mode == .Debug) {
            return BspReadError.Corruption;
        }
    }
    return @floatToInt(usize, num);
}

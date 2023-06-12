const std = @import("std");
const demo_types = @import("valve_types.zig");
const Vector = demo_types.Vector;

const HEADER_LUMPS = 64;
const HEADER_IDENT = (('P' << 24) + ('S' << 16) + ('B' << 8) + 'V');
const TF2_BSP_VERSION = 20;
const BSPLump = extern struct {
    file_offset: i32,
    len: i32,
    version: i32,
    fourCC: [4]u8, // ident code
};
const BSPHeader = extern struct {
    ident: i32 = HEADER_IDENT,
    version: i32 = TF2_BSP_VERSION,
    lumps: []BSPLump,
    mapRevision: i32,
};

const BSPPlane = extern struct {
    normal: Vector,
    dist: f32,
    type: i32,
};

/// a function to read BSPs which currently only prints its findings to log
pub fn read_bsp(file: std.fs.File) !void {
    _ = file;
}

const mem = @import("std").mem;
pub const HEADER_LUMPS = 64;
pub const HEADER_IDENT = mem.readIntLittle(u32, "VBSP");
pub const TF2_BSP_VERSION = 20;

// little-endian "LZMA"
// if this appears at the beginning of lump data, it is compressed
pub const LZMA_ID = mem.readIntLittle(u32, "LZMA");

pub const Header = extern struct {
    ident: i32 = HEADER_IDENT,
    version: i32 = TF2_BSP_VERSION,
    lumps: [HEADER_LUMPS]Lump,
    mapRevision: i32,
};

pub const Lump = extern struct {
    file_offset: i32,
    len: i32,
    version: i32,
    fourCC: [4]u8, // ident code
};

pub const CompressedLumpDataLZMAHeader = extern struct {
    id: u32,
    actual_size: u32,
    lzma_size: u32,
    properties: [5]u8,
};

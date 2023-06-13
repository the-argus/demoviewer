const demo_types = @import("../valve_types.zig");
const Vector = demo_types.Vector;
const HEADER_LUMPS = 64;
pub const HEADER_IDENT = (('P' << 24) + ('S' << 16) + ('B' << 8) + 'V');
pub const TF2_BSP_VERSION = 20;

// little-endian "LZMA"
// if this appears at the beginning of lump data, it is compressed
pub const LZMA_ID: u32 = (('A' << 24) | ('M' << 16) | ('Z' << 8) | ('L'));

pub const Header = extern struct {
    ident: i32 = HEADER_IDENT,
    version: i32 = TF2_BSP_VERSION,
    lumps: *Lump,
    mapRevision: i32,
};

pub const Lump = extern struct {
    file_offset: i32,
    len: i32,
    version: i32,
    fourCC: [4]u8, // ident code
};

pub const Plane = extern struct {
    normal: Vector,
    dist: f32,
    type: i32,
};

pub const lump_type = enum(u8) {
    LUMP_ENTITIES = 0,
    LUMP_PLANES = 1,
    LUMP_TEXDATA = 2,
    LUMP_VERTEXES = 3,
    LUMP_VISIBILITY = 4,
    LUMP_NODES = 5,
    LUMP_TEXINFO = 6,
    LUMP_FACES = 7,
    LUMP_LIGHTING = 8,
    LUMP_OCCLUSION = 9,
    LUMP_LEAFS = 10,
    LUMP_FACEIDS = 11,
    LUMP_EDGES = 12,
    LUMP_SURFEDGES = 13,
    LUMP_MODELS = 14,
    LUMP_WORLDLIGHTS = 15,
    LUMP_LEAFFACES = 16,
    LUMP_LEAFBRUSHES = 17,
    LUMP_BRUSHES = 18,
    LUMP_BRUSHSIDES = 19,
    LUMP_AREAS = 20,
    LUMP_AREAPORTALS = 21,
    LUMP_UNUSED0 = 22,
    LUMP_UNUSED1 = 23,
    LUMP_UNUSED2 = 24,
    LUMP_UNUSED3 = 25,
    LUMP_DISPINFO = 26,
    LUMP_ORIGINALFACES = 27,
    LUMP_PHYSDISP = 28,
    LUMP_PHYSCOLLIDE = 29,
    LUMP_VERTNORMALS = 30,
    LUMP_VERTNORMALINDICES = 31,
    LUMP_DISP_LIGHTMAP_ALPHAS = 32,
    LUMP_DISP_VERTS = 33,
    LUMP_DISP_LIGHTMAP_SAMPLE_POSITIONS = 34,
    LUMP_GAME_LUMP = 35,
    LUMP_LEAFWATERDATA = 36,
    LUMP_PRIMITIVES = 37,
    LUMP_PRIMVERTS = 38,
    LUMP_PRIMINDICES = 39,
    LUMP_PAKFILE = 40,
    LUMP_CLIPPORTALVERTS = 41,
    LUMP_CUBEMAPS = 42,
    LUMP_TEXDATA_STRING_DATA = 43,
    LUMP_TEXDATA_STRING_TABLE = 44,
    LUMP_OVERLAYS = 45,
    LUMP_LEAFMINDISTTOWATER = 46,
    LUMP_FACE_MACRO_TEXTURE_INFO = 47,
    LUMP_DISP_TRIS = 48,
    LUMP_PHYSCOLLIDESURFACE = 49,
    LUMP_WATEROVERLAYS = 50,
    LUMP_LEAF_AMBIENT_INDEX_HDR = 51,
    LUMP_LEAF_AMBIENT_INDEX = 52,
    LUMP_LIGHTING_HDR = 53,
    LUMP_WORLDLIGHTS_HDR = 54,
    LUMP_LEAF_AMBIENT_LIGHTING_HDR = 55,
    LUMP_LEAF_AMBIENT_LIGHTING = 56,
    LUMP_XZIPPAKFILE = 57,
    LUMP_FACES_HDR = 58,
    LUMP_MAP_FLAGS = 59,
    LUMP_OVERLAY_FADES = 60,
};
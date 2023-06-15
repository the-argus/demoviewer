const demo_types = @import("../valve_types.zig");
const std = @import("std");
const Vector = demo_types.Vector;
const MAX_MAP_SURFEDGES = 512000;
const MAX_MAP_FACES = 65536;

pub fn lump_index_to_type(comptime index: u8) type {
    if (index < 0 or index > lump_types.len) {
        @compileError("index out of range of available lump types");
    }
    const result = lump_types[index];
    if (result == void) {
        @compileError("index does not correspond to a defined type");
    }
    return result;
}

pub const Plane = extern struct {
    normal: Vector,
    dist: f32,
    type: i32,
};

pub const Edge = extern struct { v: [2]u16 };

pub const Surfedge = extern struct {
    index: i32,

    pub fn to_experimental(self: @This()) ExperimentalSurfedge {
        return ExperimentalSurfedge{
            .second_to_first = self.index < 0,
            .edge_index = std.math.absInt(self.index),
        };
    }
};

pub const ExperimentalSurfedge = packed struct {
    second_to_first: u1,
    edge_index: u31,
};

pub const Face = extern struct {
    plane_num: u16,
    side: u8,
    on_node: u8,
    first_edge: i32,
    num_edges: i16,
    tex_info: i16,
    disp_info: i16,
    surface_fog_volume_id: i16,
    styles: [4]u8,
    light_offset: i32,
    area: f32,
    lightmap_texture_mins_in_luxels: [2]i32,
    lightmap_texture_size_in_luxels: [2]i32,
    orig_face: i32,
    num_prims: u16,
    first_prim_id: u16,
    smoothing_groups: u32,
};

pub const Node = extern struct {
    plane_num: i32, // index into plane array
    children: [2]i32, // negative numbers are -(leafs + 1), not nodes
    mins: [3]i16, // for frustum culling
    maxs: [3]i16,
    first_face: u16, // index into face array
    num_faces: u16, // counting both sides
    area: i16, // If all leaves below this node are in the same area, then this is the area index. If not, this is -1.
    _: u16, // pad to 32 bytes length
};

const leaf_bitfield = packed struct {
    area: i9,
    flags: i7,
};

pub const Leaf = extern struct {
    contents: i32,
    cluster: i16,
    area_and_flags: leaf_bitfield,
    mins: [3]i16,
    maxs: [3]i16,
    first_leaf_face: u16,
    num_leaf_faces: u16,
    first_leaf_brush: u16,
    num_leaf_brushes: u16,
    leaf_water_data_id: i16,
};

const lump_types = [_]type{
    void,
    Plane,
    void, // texdata
    void, //vertices
    void, // visibility
    Node,
    void, // texinfo
    Face,
    void, // lighting
    void, // occlusion
    Leaf,
    void, // faceids
    Edge,
    Surfedge,
    void, // models
};

pub const lump_type_enum = enum(u8) {
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

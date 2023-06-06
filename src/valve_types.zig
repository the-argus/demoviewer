pub const DEMO_FILE_MAX_STRINGTABLE_SIZE: u32 = 5000000;

pub const CommandHeader = struct {
    message: demo_messages,
    tick: i32,
};

pub const DemoHeader = extern struct {
    header: [8]u8,
    demo_protocol: i32,
    network_protocol: i32,
    server_name: [260]u8,
    client_name: [260]u8,
    map_name: [260]u8,
    game_directory: [260]u8,
    playback_time: f32,
    ticks: i32,
    frames: i32,
    signon_length: i32,
};

pub const demo_messages =
    enum(u8) {
    // it's a startup message, process as fast as possible
    dem_signon = 1,
    // it's a normal network packet that we stored off
    dem_packet,
    // sync client clock to demo tick
    dem_synctick,
    // console command
    dem_consolecmd,
    // user input command
    dem_usercmd,
    // network data tables
    dem_datatables,
    // end of time.
    dem_stop,
    dem_stringtables,
    // Last command
    // dem_lastcmd = 8,
};

/// from public/tier1/bitbuf.h - used for unserialization. idk what "bf" is
pub const BFRead = struct {};

/// from public/tier1/netadr.h
pub const NetAddressType = enum(u8) {
    NA_NULL = 0,
    NA_LOOPBACK,
    NA_BROADCAST,
    NA_IP,
};
pub const NetAddress = struct {
    type: NetAddressType,
    ip: [4]u8,
    port: u16,
};

pub const NetPacket = struct {
    from: NetAddressType, // sender IP
    source: i32, // received source
    received: f64, // received time
    data: [*]u8, // pointer to raw packet data
    message: NetAddress, // easy bitbuf data access
    size: i32, // size in bytes
    wiresize: i32, // size in bytes before decompression
    stream: bool, // was send as stream
    // next: NetPacket, // for internal use, should be NULL in public
};

pub const Packet = extern struct {
    cmd_type: u8,
    unknown: i32,
    tickcount: i32,
    size_of_packet: i32,
    buffer: *[]u8, // where the length should be equal to size_of_packet
};

pub const Frame = extern struct {
    server_frame: i32,
    client_frame: i32,
    subpacketsize: i32,
    buffer: *[]u8, // length equal to subpacketsize
    pkt: Packet,
};

pub const Vector = extern struct { x: f32, y: f32, z: f32 };
pub const Angle = Vector;

const FDEMO_NORMAL = 0;
const FDEMO_USE_ORIGIN2 = 1 << 0;
const FDEMO_USE_ANGLES2 = 1 << 1;
const FDEMO_NOINTERP = 1 << 2;

pub const DemoCommandInfo = extern struct {
    flags: i32 = FDEMO_NORMAL,
    view_origin: Vector,
    view_angles: Angle,
    local_view_angles: Angle,
    view_origin_2: Vector,
    view_angles_2: Angle,
    local_view_angles_2: Angle,
};

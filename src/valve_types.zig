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
    dem_packet = 2,
    // sync client clock to demo tick
    dem_synctick = 3,
    // console command
    dem_consolecmd = 4,
    // user input command
    dem_usercmd = 5,
    // network data tables
    dem_datatables = 6,
    // end of time.
    dem_stop = 7,
    dem_stringtables = 8,
    // Last command
    // dem_lastcmd = 8,
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

pub const DemoCommand = extern struct {
    flags: i32 = FDEMO_NORMAL,
    view_origin: Vector,
    view_angles: Angle,
    local_view_angles: Angle,
    view_origin_2: Vector,
    view_angles_2: Angle,
    local_view_angles_2: Angle,
};

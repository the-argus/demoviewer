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

pub const frame_commands_78 = enum(i32) {
    dem_signon = 1,
    dem_packet = 2,
    dem_synctick = 3,
    dem_consolecmd = 4,
    dem_usercmd = 5,
    dem_datatables = 6,
    dem_stop = 7, // data completed, demo over
};

pub const frame_commands_1415 = enum(u8) {
    dem_stringtables = 8,
};

pub const frame_commands_36plus = enum(u8) {
    dem_customdata = 8,
    dem_stringtables = 9,
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

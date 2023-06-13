const std = @import("std");
const read_dem = @import("read_dem.zig").read_dem;
const dem_io = @import("read_dem.zig");
const read_bsp = @import("bsp/read_bsp.zig").read_bsp;
const demo_debug = @import("demo_debug.zig");
const builtin = @import("builtin");
const clap = @import("clap");
const log = std.log.scoped(.demoviewer);

pub const std_options = struct {
    // log level depends on build mode
    pub const log_level = if (builtin.mode == .Debug) .debug else .info;
    // Define logFn to override the std implementation
    pub const logFn = @import("logging.zig").demoviewer_logger;
};

const Input = struct {
    print_only_header: bool,
    print_only_map_info: bool,
    map_file: ?[]const u8,
    demo_file: ?[]const u8,
    tf_path: ?[]const u8,
};

const DemoViewerError = error{
    BadMap,
    NoHome,
};

const default_tf_path = ".steam/steam/steamapps/common/Team Fortress 2/tf/maps";

pub fn main() !void {
    const params = comptime clap.parseParamsComptime(
        \\-h, --help                Display this help and exit.
        \\-p, --printheader         Print only the header of the specified demo file and exit.
        \\-m, --mapfile <str>       Override the map specified by the demo file.
        \\-b, --bspinfo             Print the information of the selected map and exit.
        \\-t, --tfpath <str>        Path to your tf folder.
        \\<str>...
        \\
    );

    var diag: clap.Diagnostic = .{};
    var parse_options: clap.ParseOptions = .{};
    if (builtin.mode == .Debug) {
        diag = clap.Diagnostic{};
        parse_options = .{ .diagnostic = &diag };
    }

    var parsed_args = clap.parse(clap.Help, &params, clap.parsers.default, parse_options) catch |err| {
        return badarg(err, &params, &diag);
    };
    defer parsed_args.deinit();

    // print help and exit if asked for
    if (parsed_args.args.help > 0) {
        return clap.help(std.io.getStdErr().writer(), clap.Help, &params, .{});
    }

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var input = block: {
        const opt_input = gather_required_input(&parsed_args);
        if (opt_input == null) {
            return clap.help(std.io.getStdErr().writer(), clap.Help, &params, .{});
        }
        break :block opt_input.?;
    };

    // most obvious first exit point, requires the least info
    if (input.print_only_header) {
        return print_header(input.demo_file.?);
    }

    // okay, we are going to need the map file for all remaining cases
    // resolve where the map is
    // option A: its supplied on the commandline
    if (parsed_args.args.mapfile) |mapfile| {
        input.map_file = mapfile;
    } else {
        // option B: find the map in tfpath based on the name in the demo header
        input.map_file = try get_map_absolute_path(allocator, &input, &parsed_args, &params);
    }
    defer allocator.free(input.map_file.?);

    if (input.print_only_map_info) {
        return read_bsp(input.map_file.?);
    }

    return try read_dem(input.demo_file.?, allocator);
}

fn get_map_absolute_path(allocator: std.mem.Allocator, input: *Input, parsed_args: anytype, params: anytype) ![]u8 {
    if (parsed_args.*.args.tfpath) |tfpath| {
        input.*.tf_path = tfpath;
    }

    // get map basename
    const map_name_from_header = label: {
        const demo_file = try dem_io.open_demo(input.*.demo_file.?);
        const header = try dem_io.read_header(demo_file);
        break :label dem_io.get_slice_from_cstring(&header.map_name);
    };

    // concatenate basename and dirname
    const map_file_abs_path = block: {
        const homedir = std.os.getenv("HOME");
        if (homedir == null) {
            log.err("You somehow don't have a $HOME directory...", .{});
            return DemoViewerError.NoHome;
        }
        const joined = try std.fs.path.join(allocator, &[_][]const u8{ homedir.?, input.*.tf_path.?, map_name_from_header });
        defer allocator.free(joined);
        const joined_with_ext = try std.mem.concat(allocator, u8, &[_][]const u8{ joined, ".bsp" });
        break :block joined_with_ext;
    };

    // make sure file exists
    const map_file = std.fs.openFileAbsolute(map_file_abs_path, .{ .mode = .read_only }) catch |err| {
        log.err("Failed to open mapfile {s}: {any}", .{ map_file_abs_path, err });
        log.info("If the attempted path looks wrong, try passing in --tfpath or --mapfile", .{});
        try clap.help(std.io.getStdErr().writer(), clap.Help, params, .{});
        allocator.free(map_file_abs_path);
        return DemoViewerError.BadMap;
    };
    map_file.close();
    return map_file_abs_path;
}

fn gather_required_input(parsed_args: anytype) ?Input {
    var input: Input = .{
        .print_only_header = false,
        .print_only_map_info = false,
        .map_file = null,
        .demo_file = null,
        .tf_path = default_tf_path,
    };

    input.print_only_header = parsed_args.*.args.printheader > 0;
    input.print_only_map_info = parsed_args.*.args.bspinfo > 0;

    const demo_file_supplied = parsed_args.*.positionals.len > 0;
    if (demo_file_supplied) {
        input.demo_file = parsed_args.*.positionals[0];
    } else if (!input.print_only_map_info) {
        log.err("No positional arguments provided. Need demo file.", .{});
        return null;
    }
    return input;
}

fn print_header(filename: []const u8) !void {
    const demo_file = try dem_io.open_demo(filename);
    const header = try dem_io.read_header(demo_file);
    demo_debug.print_demo_header(header);
}

/// When building in debug mode, handle arguments that cannot be parsed in this way
fn badarg(err: anyerror, params: anytype, diag: *clap.Diagnostic) !void {
    if (builtin.mode == .Debug) {
        // Report useful error and exit
        diag.report(std.io.getStdErr().writer(), err) catch {};
        return err;
    } else {
        log.err("Unable to parse command line arguments.", .{});
        return clap.help(std.io.getStdErr().writer(), clap.Help, params, .{});
    }
}

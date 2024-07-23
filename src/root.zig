const std = @import("std");
const config = @import("config");
const testing = std.testing;
const x11 = @cImport({
    @cInclude("X11/Xlib.h");
    @cInclude("X11/extensions/Xcomposite.h");
    @cInclude("X11/extensions/shape.h");
    @cInclude("X11/extensions/Xrandr.h");
});

export fn run_app() void {
    const display = result: {
        const display_optional = x11.XOpenDisplay(null);
        if (display_optional == null) {
            return;
        }
        break :result display_optional.?;
    };
    defer _ = x11.XCloseDisplay(display);

    const primary_screen = x11.XDefaultScreen(display);
    const root_window = x11.RootWindow(display, primary_screen);

    const crtc_info = result: {
        const crtc_info_optional = getPrimaryScreenInfo(display, root_window);
        if (crtc_info_optional == null) {
            return;
        }
        break :result crtc_info_optional.?;
    };

    const width = crtc_info.width;
    const height = crtc_info.height;
    const x = crtc_info.x;
    const y = crtc_info.y;

    var visual_info: x11.XVisualInfo = undefined;
    _ = x11.XMatchVisualInfo(display, x11.DefaultScreen(display), 32, x11.TrueColor, &visual_info);
    var attr: x11.XSetWindowAttributes = .{
        .colormap = x11.XCreateColormap(display, x11.DefaultRootWindow(display), visual_info.visual, x11.AllocNone),
        .border_pixel = 0,
        .background_pixel = 0,
        .override_redirect = 1,
        .event_mask = x11.ExposureMask | x11.StructureNotifyMask,
    };

    const window = x11.XCreateWindow(
        display,
        root_window,
        x,
        y,
        width,
        height,
        0,
        visual_info.depth,
        x11.InputOutput,
        visual_info.visual,
        x11.CWOverrideRedirect | x11.CWBackPixel | x11.CWBorderPixel | x11.CWEventMask | x11.CWColormap,
        &attr,
    );
    defer _ = x11.XDestroyWindow(display, window);

    x11.XCompositeRedirectWindow(display, window, x11.CompositeRedirectAutomatic);

    const region = x11.XFixesCreateRegion(display, null, 0);
    x11.XFixesSetWindowShapeRegion(display, window, x11.ShapeInput, 0, 0, region);
    x11.XFixesDestroyRegion(display, region);

    //_ = x11.XSetInputFocus(display, root_window, x11.RevertToNone, x11.CurrentTime);
    _ = x11.XSelectInput(display, window, x11.StructureNotifyMask | x11.ExposureMask);

    const gc = x11.XCreateGC(display, window, 0, 0);
    defer _ = x11.XFreeGC(display, gc);

    var wm_delete_window = x11.XInternAtom(display, "WM_DELETE_WINDOW", 0);
    _ = x11.XSetWMProtocols(display, window, &wm_delete_window, 1);

    _ = x11.XMapWindow(display, window);

    var keep_running = true;
    var event: x11.XEvent = undefined;

    _ = x11.XFlush(display);
    const crosshair_radius = 8;
    while (keep_running) {
        _ = x11.XNextEvent(display, &event);

        switch (event.type) {
            x11.ClientMessage => {
                if (event.xclient.message_type == x11.XInternAtom(display, "WM_PROTOCOLS", 1) and @as(x11.Atom, @intCast(event.xclient.data.l[0])) == x11.XInternAtom(display, "WM_DELETE_WINDOW", 1)) {
                    keep_running = false;
                }
            },
            x11.Expose => {
                _ = x11.XClearWindow(display, window);
                _ = x11.XSetForeground(display, gc, x11.XWhitePixel(display, primary_screen));
                _ = x11.XDrawLine(display, window, gc, @intCast(width / 2), @intCast((height / 2) - crosshair_radius), @intCast(width / 2), @intCast((height / 2) + crosshair_radius));
                _ = x11.XDrawLine(display, window, gc, @intCast((width / 2) - crosshair_radius), @intCast(height / 2), @intCast((width / 2) + crosshair_radius), @intCast(height / 2));
            },
            else => continue,
        }
    }
}

fn getPrimaryScreenInfo(display: *x11.Display, root: x11.Window) ?*x11.XRRCrtcInfo {
    const resources = x11.XRRGetScreenResources(display, root);
    if (resources == null) return null;
    defer x11.XRRFreeScreenResources(resources);

    const primary_output = x11.XRRGetOutputPrimary(display, root);
    if (primary_output == 0) return null;

    const num_of_outputs: usize = @intCast(resources.*.noutput);
    for (0..num_of_outputs) |index| {
        const output = resources.*.outputs[index];
        const info = x11.XRRGetOutputInfo(display, resources, output);
        defer x11.XRRFreeOutputInfo(info);
        if (output == primary_output) {
            return x11.XRRGetCrtcInfo(display, resources, info.*.crtc);
        }
    }

    return null;
}

pub export fn version() [*c]const u8 {
    return config.version.ptr;
}

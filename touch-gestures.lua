-- touch-gestures 1.0.0 - 2023-Jan-26
-- https://github.com/christoph-heinrich/mpv-touch-gestures
--
-- Touch gestures for mpv

local assdraw = require('mp.assdraw')
local options = require('mp.options')
local msg = require('mp.msg')

local opts = {
    horizontal_drag = 'playlist',
    proportional_seek = true,
    seek_scale = 1,
}
options.read_options(opts, 'touch-gestures')

if opts.horizontal_drag ~= 'playlist' and opts.horizontal_drag ~= 'seek' then
    msg.error('The option "horizontal_drag" supports the values "playlist" and "seek"')
end

local osd = mp.create_osd_overlay('ass-events')

local uosc = false
local osd_pref = 'osd-auto'

local scale = 1
mp.observe_property('display-hidpi-scale', 'number', function(_, val)
    if val == nil then scale = 1
    else scale = val end
end)

local drag_total = 0
-- ds is short for drag_start
local ds_w = nil
local ds_h = nil
local ds_time = nil
local ds_dur = nil
local ds_vol = nil
local ds_vol_max = nil
local ds_speed = nil

function opacity_to_alpha(opacity)
	return 255 - math.ceil(255 * math.min(opacity, 1))
end

local function render_playlist()
    local ass = assdraw.ass_new()

    local height = 720
    local width = ds_w/ds_h * height

    local vert_pos, rotation
    if drag_total > 0 then
        vert_pos = 0.1
        rotation = 180
    else
        vert_pos = 0.9
        rotation = 0
    end

    local opacity = math.max((math.abs(drag_total) - 80 * scale) / 100, 0)

    ass:pos(width * vert_pos, 360)
    local f = '{\\fnmonospace\\fs200\\bord2\\an6\\frz%d\\alpha&H%X&}\226\158\156'
    ass:append(string.format(f , rotation, opacity_to_alpha(opacity)))

    if osd.res_x == width and osd.data == ass.text then
        return
    end
    osd.res_x = width
    osd.res_y = height
    osd.data = ass.text
    osd.hidden = false
    osd.z = 1000
    osd:update()
end

local function drag_playlist(dx)
    drag_total = drag_total + dx
    render_playlist()
end
local function drag_playlist_end()
    if math.abs(drag_total) < (80 * scale) then return end
    if drag_total > 0 then
        mp.command('script-binding uosc/prev')
    else
        mp.command('script-binding uosc/next')
    end
end

local time = nil
local function seek(fast)
    if not time then return end
    mp.commandv(osd_pref, 'seek', time, fast and 'absolute+keyframes' or 'absolute+exact')
end
seek_timer = mp.add_timeout(0.05, seek)
seek_timer:kill()
local function drag_seek(dx)
    if not ds_dur then return end
    drag_total = drag_total + dx

    if opts.proportional_seek then
        time = math.max(drag_total / ds_w * ds_dur * opts.seek_scale + ds_time, 0)
    else
        time = math.max(drag_total * opts.seek_scale / scale + ds_time, 0)
    end

    if ds_w / ds_dur < 10 then
        -- Perform a fast seek while moving around and an exact seek afterwards
        seek(true)
        seek_timer:kill()
        seek_timer:resume()
    else
        seek()
    end
    if uosc then mp.commandv('script-binding', 'uosc/flash-timeline') end
end

local function drag_volume(dy)
    drag_total = drag_total + dy
    local vol = math.floor(-drag_total / ds_h * 100 + ds_vol + 0.5)
    mp.commandv(osd_pref, 'set', 'volume', math.max(math.min(vol, ds_vol_max), 0))
    if uosc then mp.commandv('script-binding', 'uosc/flash-volume') end
end

local function drag_speed(dy)
    drag_total = drag_total + dy
    local speed = math.floor((-drag_total / ds_h * 3 + ds_speed) * 10 + 0.5) / 10
    mp.commandv(osd_pref, 'set', 'speed', math.max(math.min(speed, 5), 0.1))
    if uosc then mp.commandv('script-binding', 'uosc/flash-speed') end
end

local function drag_init(dx, dy)
    ds_w, ds_h, _ = mp.get_osd_size()
    local vertical = dx * dx < dy * dy
    if vertical then
        local mouse = mp.get_property_native('mouse-pos')
        if mouse.x > ds_w / 2 then
            ds_vol = mp.get_property_number('volume')
            ds_vol_max = mp.get_property_number('volume-max')
            return 'volume'
        else
            ds_speed = mp.get_property_number('speed')
            return 'speed'
        end
    else
        if opts.horizontal_drag == 'playlist' then
            return 'playlist'
        elseif opts.horizontal_drag == 'seek' then
            ds_time = mp.get_property_number('playback-time')
            ds_dur = mp.get_property_number('duration')
            return 'seek'
        end
    end
end

local drag_kind = nil
local function drag(dx, dy)
    if not drag_kind then drag_kind = drag_init(dx, dy) end
    if drag_kind == 'volume' then drag_volume(dy)
    elseif drag_kind == 'speed' then drag_speed(dy)
    elseif drag_kind == 'playlist' then drag_playlist(dx)
    elseif drag_kind == 'seek' then drag_seek(dx)
    end
end

local function drag_start()
    drag_total = 0
    drag_kind = nil
end

local function drag_end()
    if drag_kind == 'playlist' then drag_playlist_end() end
    drag_total = 0
    ds_vol = nil
    ds_vol_max = nil
    ds_speed = nil
    ds_time = nil
    ds_dur = nil
    osd.data = ''
    osd.hidden = true
    osd:update()
end

local function double()
    w, _, _ = mp.get_osd_size()
    local mouse = mp.get_property_native('mouse-pos')
    if mouse.x < w / 3  then
        mp.commandv(osd_pref, 'seek', -10, 'relative+exact')
        if uosc then mp.commandv('script-binding', 'uosc/flash-timeline') end
    elseif mouse.x < w * 2 / 3 then
        mp.commandv('cycle', 'fullscreen')
    else
        mp.commandv(osd_pref, 'seek', 10, 'relative+exact')
        if uosc then mp.commandv('script-binding', 'uosc/flash-timeline') end
    end
end

mp.register_script_message('drag', drag)
mp.register_script_message('drag_start', drag_start)
mp.register_script_message('drag_end', drag_end)
mp.register_script_message('double', double)

-- check if uosc is running
mp.register_script_message('uosc-version', function(version)
    version = tonumber((version:gsub('%.', '')))
    ---@diagnostic disable-next-line: cast-local-type
    uosc = version and version >= 400
    if uosc then osd_pref = 'no-osd' end
end)
mp.commandv('script-message-to', 'uosc', 'get-version', mp.get_script_name())

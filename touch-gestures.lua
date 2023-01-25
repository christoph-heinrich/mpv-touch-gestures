-- pointer-event 1.1.1 - 2023-Jan-01
-- https://github.com/christoph-heinrich/mpv-pointer-event
--
-- Low latency detection of single-click, double-click, long-click and dragging.

local uosc = false
local osd_pref = 'osd-auto'

local drag_total = 0
local ds_w = nil
local ds_h = nil
local ds_time = nil
local ds_dur = nil
local ds_vol = nil
local ds_vol_max = nil
local ds_speed = nil

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
    time = math.max(drag_total / ds_w * ds_dur + ds_time, 0)
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
        ds_time = mp.get_property_number('playback-time')
        ds_dur = mp.get_property_number('duration')
        return 'seek'
    end
end

local drag_kind = nil
local function drag(dx, dy)
    if not drag_kind then drag_kind = drag_init(dx, dy) end
    if drag_kind == 'volume' then drag_volume(dy)
    elseif drag_kind == 'speed' then drag_speed(dy)
    elseif drag_kind == 'seek' then drag_seek(dx)
    end
end

local function drag_start()
    drag_total = 0
    drag_kind = nil
end

local function drag_end()
    drag_total = 0
    ds_vol = nil
    ds_vol_max = nil
    ds_speed = nil
    ds_time = nil
    ds_dur = nil
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

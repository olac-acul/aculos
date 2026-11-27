--!nonstrict
-- aculOs menu: one launcher menu for the aculos commands, under the /aculos prefix (Mod+Space).
--
-- An empty query lists the categories; choosing one turns the query into its name, which lists its items. Any
-- other text searches all items. "try <name>" offers to try a program (aculos try), "save <name>" to save the
-- current screen layout (aculos display save). Items also show up in the launcher's global search.
-- Commands that ask for a password or print something worth reading run in kitty, kept open at the end; the others
-- run quietly and answer with a notification. Themes are listed only when the "theme" command exists (dotfiles).

local function tr(key, vars)
    return noctalia.tr(key, vars)
end

local function terminal(cmd)   -- run in kitty and keep the window open, so the output can be read
    local argv = { "kitty", "--hold", "--title", "aculOs" }
    for _, a in ipairs(cmd) do
        table.insert(argv, a)
    end
    noctalia.runAsync(argv)
end

local function quiet(cmd, title)   -- run, then show the output in a notification
    noctalia.runAsync(cmd, function(r)
        local out = r and noctalia.string.trim((r.stdout or "") .. "\n" .. (r.stderr or "")) or ""
        if r and r.exitCode == 0 then
            noctalia.notify(title, out)
        else
            noctalia.notifyError(title, out)
        end
    end, 120000)
end

local function spawn(cmd)   -- start a program and forget it
    noctalia.runAsync(cmd)
end

-- Categories, in menu order
local CATEGORIES = {
    { key = "system", glyph = "settings" },
    { key = "appearance", glyph = "palette" },
    { key = "screens", glyph = "device-desktop" },
    { key = "battery", glyph = "battery-2" },
    { key = "agents", glyph = "robot" },
    { key = "remote", glyph = "server" },
    { key = "apps", glyph = "apps" },
}

-- Fixed items: category, id, glyph, command shown as subtitle, action
local ITEMS = {
    { "system", "update", "refresh", "aculos update", function() terminal({ "aculos", "update" }) end },
    { "system", "update-status", "info-circle", "aculos update status",
        function() quiet({ "aculos", "update", "status" }, tr("item.update-status")) end },
    { "system", "ssh-on", "lock-open", "aculos ssh on", function() terminal({ "aculos", "ssh", "on" }) end },
    { "system", "ssh-off", "lock", "aculos ssh off", function() terminal({ "aculos", "ssh", "off" }) end },
    { "system", "setup", "list-check", "aculos setup", function() terminal({ "aculos", "setup" }) end },
    { "appearance", "wallpaper", "photo", "", function() noctalia.togglePanel("wallpaper") end },
    { "screens", "display-next", "arrows-exchange", "aculos display switch",
        function() quiet({ "aculos", "display", "switch" }, tr("item.display-next")) end },
    { "screens", "display-list", "list", "aculos display list",
        function() quiet({ "aculos", "display", "list" }, tr("item.display-list")) end },
    { "battery", "battery-status", "battery-2", "aculos battery",
        function() quiet({ "aculos", "battery" }, tr("category.battery")) end },
    { "battery", "battery-full", "battery-charging", "aculos battery full",
        function() quiet({ "aculos", "battery", "full" }, tr("category.battery")) end },
    { "battery", "battery-normal", "battery-eco", "aculos battery normal",
        function() quiet({ "aculos", "battery", "normal" }, tr("category.battery")) end },
    { "agents", "agent-pi", "robot", "aculos agent pick pi",
        function() spawn({ "kitty", "--title", "pi", "aculos-agent", "pick", "pi" }) end },
    { "agents", "agent-pi-local", "robot", "aculos agent pick --local pi",
        function() spawn({ "kitty", "--title", "pi", "aculos-agent", "pick", "--local", "pi" }) end },
    { "agents", "agent-claude", "robot", "aculos agent pick claude",
        function() spawn({ "kitty", "--title", "Claude Code", "aculos-agent", "pick", "claude" }) end },
    { "agents", "agent-codex", "robot", "aculos agent pick codex",
        function() spawn({ "kitty", "--title", "Codex", "aculos-agent", "pick", "codex" }) end },
    { "remote", "remote", "terminal-2", "aculos remote",
        function() spawn({ "kitty", "--title", "Remote", "aculos-remote" }) end },
    { "apps", "flatpak", "package", "aculos flatpak", function() terminal({ "aculos", "flatpak" }) end },
}
for _, size in ipairs({ 90, 100, 110, 125 }) do
    table.insert(ITEMS, { "appearance", "text-" .. size, "text-size", "aculos text-size " .. size,
        function() quiet({ "aculos", "text-size", tostring(size) }, tr("item.text-size")) end, size })
end

-- The shell's PATH lacks ~/.local/bin, where the dotfiles put "theme"
local USER_PATH = 'PATH="$HOME/.local/bin:$PATH"; '

-- Themes, read from "theme" (refreshed every time the menu opens): { name, description, active }
local themes = {}
local function loadThemes()
    noctalia.runAsync({ "sh", "-c", USER_PATH .. "command -v theme >/dev/null && theme" }, function(r)
        local list = {}
        if r and r.exitCode == 0 then
            for line in string.gmatch(r.stdout or "", "[^\n]+") do
                local mark, name, description = string.match(line, "^(.)%s(%S+)%s*(.*)$")
                if name then
                    table.insert(list, { name = name, description = description, active = mark == "*" })
                end
            end
        end
        themes = list
    end, 10000)
end
loadThemes()

local actions = {}   -- id -> function, for onActivate

local function itemRow(item)
    local category, id, glyph, command, action, size = item[1], item[2], item[3], item[4], item[5], item[6]
    actions[id] = action
    return {
        id = id,
        title = size and tr("item.text-size-value", { value = size }) or tr("item." .. id),
        subtitle = command,
        glyph = glyph,
        category = category,
    }
end

local function themeRows()
    local rows = {}
    for _, t in ipairs(themes) do
        local id = "theme:" .. t.name
        actions[id] = function() terminal({ "sh", "-c", USER_PATH .. 'exec theme "$1"', "theme", t.name }) end
        table.insert(rows, {
            id = id,
            title = tr(t.active and "item.theme-active" or "item.theme", { name = t.name }),
            subtitle = t.description,
            glyph = "palette",
            category = "appearance",
        })
    end
    return rows
end

local function allRows()
    local rows = {}
    for _, item in ipairs(ITEMS) do
        table.insert(rows, itemRow(item))
    end
    for _, row in ipairs(themeRows()) do
        table.insert(rows, row)
    end
    return rows
end

local function categoryFor(text)   -- the category whose (translated) name is the query, if any
    local lower = string.lower(text)
    for _, c in ipairs(CATEGORIES) do
        if lower == string.lower(tr("category." .. c.key)) or lower == c.key then
            return c.key
        end
    end
    return nil
end

local function strip(row)   -- the launcher wants only these fields
    return { id = row.id, title = row.title, subtitle = row.subtitle, glyph = row.glyph }
end

function onQuery(query)
    local text = noctalia.string.trim(tostring(query or ""))
    local rows = {}

    local name = string.match(text, "^[Tt]ry%s+(%S+)$") or string.match(text, "^[Pp]rova%s+(%S+)$")
    if name then
        local id = "try:" .. name
        actions[id] = function() terminal({ "aculos", "try", name }) end
        table.insert(rows, { id = id, title = tr("item.try", { name = name }), subtitle = "aculos try " .. name, glyph = "flask" })
    end
    local layout = string.match(text, "^[Ss]ave%s+(%S+)$") or string.match(text, "^[Ss]alva%s+(%S+)$")
    if layout then
        local id = "save:" .. layout
        actions[id] = function() quiet({ "aculos", "display", "save", layout }, tr("item.display-save", { name = layout })) end
        table.insert(rows, { id = id, title = tr("item.display-save", { name = layout }), subtitle = "aculos display save " .. layout, glyph = "device-floppy" })
    end

    local category = categoryFor(text)
    if text == "" then
        loadThemes()
        for _, c in ipairs(CATEGORIES) do
            table.insert(rows, { id = "category:" .. c.key, title = tr("category." .. c.key), subtitle = tr("category." .. c.key .. "-hint"), glyph = c.glyph })
        end
        table.insert(rows, { id = "hint", title = tr("hint.title"), subtitle = tr("hint.subtitle"), glyph = "info-circle" })
    elseif category then
        for _, row in ipairs(allRows()) do
            if row.category == category then
                table.insert(rows, strip(row))
            end
        end
        if category == "apps" and not name then
            table.insert(rows, { id = "hint", title = tr("hint.try"), subtitle = "aculos try <name>", glyph = "flask" })
        end
        if category == "screens" and not layout then
            table.insert(rows, { id = "hint", title = tr("hint.save"), subtitle = "aculos display save <name>", glyph = "device-floppy" })
        end
    elseif not name and not layout then
        local matches = {}
        for _, row in ipairs(allRows()) do
            local score = noctalia.fuzzyScore(text, row.title .. " " .. row.subtitle)
            if score ~= nil then
                table.insert(matches, { row = row, score = score })
            end
        end
        table.sort(matches, function(a, b) return a.score > b.score end)
        for i = 1, math.min(#matches, 10) do
            table.insert(rows, strip(matches[i].row))
        end
    end

    launcher.setResults(query, rows)
end

function onActivate(id)
    local key = string.match(id, "^category:(.+)$")
    if key then
        launcher.setQuery(tr("category." .. key))   -- keeps the launcher open and lists the category
        return
    end
    if id == "hint" then
        return
    end
    local action = actions[id]
    if action then
        action()
    end
end

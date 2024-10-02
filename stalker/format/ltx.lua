local Ltx = {}

local function trim(str)
    if not str then return "" end
    return str:gsub("^%s*(.-)%s*$", "%1")
end

--- @class SectionEntry
--- @field key string
--- @field value string
--- @field comment_after string

--- @class Section
--- @field section_name string
--- @field parent_section string?
--- @field is_overwrite boolean
--- @field comments string
--- @field entries table<SectionEntry>

function Ltx:new()
    local obj = {}
    setmetatable(obj, self)
    self.__index = self
    return obj
end

function Ltx:matchComment(str)
    return str:match "^%;.*"
end

function Ltx:matchSection(str)
    return str:match "(!?)(%[.*%]):?(.*)"
end

function Ltx:matchSelectionName(str)
    return str:match "%[(.*)%]"
end

function Ltx:parseFile(filepath)
    local src_file = assert(
        io.lines(filepath, [[l]]),
        "Could not open filepath"
    )
    local sections = {}
    local current_section = nil
    local current_comments = ""

    for line in src_file do
        line = trim(line)

        local comment = self:matchComment(line)
        if comment then
            current_comments = current_comments .. "\n" .. comment
        elseif line ~= "" then
            local ow_symbol, section, parent_section = self:matchSection(line)
            if section then
                local is_overwrite = ow_symbol == "!"
                local section_name = self:matchSelectionName(section)
                if parent_section then
                    parent_section = trim(parent_section)
                end
                --- @type Section
                current_section = {
                    section_name = section_name,
                    is_overwrite = is_overwrite,
                    parent_section = parent_section,
                    comments = current_comments,
                    entries = {},
                }
                table.insert(sections, current_section)
                current_comments = ""
            else
                local key, value, comment_after = line:match "(.*)%s*=%s*(.*)%s*"
                if current_section then
                    --- @type SectionEntry
                    local entry = {
                        key = key,
                        value = value,
                        comment_before = current_comments,
                        comment_after = comment_after,
                    }
                    key = trim(key)
                    table.insert(current_section.entries, entry)
                    current_comments = ""
                end
            end
        end
    end

    return sections
end

function Ltx:stringify(sections, key_spaces)
    key_spaces = key_spaces or {}
    key_spaces.after_key = key_spaces.after_key or 0

    local str = ""

    for _, section in pairs(sections) do
        for _, entry in pairs(section.entries) do
            local entry_key_len = #entry.key
            if entry_key_len > key_spaces.after_key then
                key_spaces.after_key = entry_key_len
            end
        end
    end

    key_spaces.after_key = key_spaces.after_key + 8

    for _, section in pairs(sections) do
        local section_str = ""
        if section.comments ~= "" then
            section_str = section_str .. section.comments .. "\n"
        end
        if section.is_overwrite then
            section_str = "!" .. section_str
        end
        section_str = section_str .. string.format("[%s]", section.section_name)
        if section.parent_section then
            section_str = string.format("%s:%s", section_str, section.parent_section)
        end
        for _, entry in pairs(section.entries) do
            local key = entry.key
            section_str = section_str
                .. (entry.comment_before and entry.comment_before .. "\n" or "")
                .. key
                .. string.rep(" ", key_spaces.after_key - #key)
                .. " = "
                .. entry.value
                .. (entry.comment_after or "")
        end

        str = str .. section_str .. "\n"
    end

    return str
end

function Ltx:merge(files)
    local merged_sections = {}
    return merged_sections
end

return Ltx

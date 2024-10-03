local Ltx = {}

local function trim(str)
    if not str then return "" end
    return str:gsub("^%s*(.-)%s*$", "%1")
end

--- @class SectionEntry
--- @field idx number
--- @field key string
--- @field value string
--- @field comment_before string
--- @field comment_after string

--- @class Section
--- @field idx number
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
    return str:match "^[%;%/{2}].*"
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
    local cur_sec = nil
    local cur_sec_idx = 1
    local cur_entry_idx = 1
    local cur_comments = ""

    for line in src_file do
        line = trim(line)

        local comment = self:matchComment(line)
        if comment then
            cur_comments = cur_comments .. "\n" .. comment
        elseif line ~= "" then
            local ow_symbol, section, parent_section = self:matchSection(line)
            if section then
                local is_overwrite = ow_symbol == "!"
                local section_name = self:matchSelectionName(section)
                if parent_section then
                    parent_section = trim(parent_section)
                end
                --- @type Section
                cur_sec = {
                    idx = cur_sec_idx,
                    section_name = trim(section_name),
                    is_overwrite = is_overwrite,
                    parent_section = parent_section,
                    comments = trim(cur_comments),
                    entries = {},
                }
                table.insert(sections, cur_sec)
                cur_sec_idx = cur_sec_idx + 1
                cur_entry_idx = 1
                cur_comments = ""
            else
                local key, value, comment_after = line:match "(.*)%s*=%s*(.*)%s*"
                if cur_sec then
                    --- @type SectionEntry
                    local entry = {
                        idx = cur_entry_idx,
                        key = trim(key),
                        value = trim(value),
                        comment_before = trim(cur_comments),
                        comment_after = trim(comment_after),
                    }
                    key = trim(key)
                    table.insert(cur_sec.entries, entry)
                    cur_entry_idx = cur_entry_idx + 1
                    cur_comments = ""
                end
            end
        end
    end

    return sections
end

function Ltx:stringify(sections, key_spaces)
    key_spaces = key_spaces or {}
    key_spaces.before_key = key_spaces.before_key or 0
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
            local spaces_bef_key = string.rep(" ", key_spaces.before_key)
            section_str = section_str
                .. spaces_bef_key
                .. (entry.comment_before and entry.comment_before .. "\n" or "")
                .. spaces_bef_key
                .. key
                .. string.rep(" ", key_spaces.after_key - #key)
                .. " = "
                .. entry.value
                .. (entry.comment_after or "")
        end

        str = str .. section_str .. "\n\n"
    end

    return str
end

function Ltx:merge(files)
    local merged_sections = {}
    local cur_sec_idx = 1

    for _, file in ipairs(files) do
        local sections = self:parseFile(file)

        for _, section in pairs(sections) do
            local section_name = section.parent_section
                and section.section_name .. ":" .. section.parent_section
                or section.section_name
            if not merged_sections[section_name] then
                merged_sections[section_name] = {
                    idx = cur_sec_idx,
                    section_name = section.section_name,
                    parent_section = section.parent_section,
                    is_overwrite = section.is_overwrite,
                    comments = section.comments,
                    merged_entries = {},
                }
                cur_sec_idx = cur_sec_idx + 1
            end
            if section.is_overwrite then
                merged_sections[section_name].is_overwrite = true
            end
            if section.comments ~= "" then
                local comments = merged_sections[section_name].comments
                merged_sections[section_name].comments = comments .. "\n" .. section.comments
            end
            local cur_entry_idx = 1
            for _, entry in ipairs(section.entries) do
                local key = entry.key
                if not merged_sections[section_name].merged_entries[key] then
                    merged_sections[section_name].merged_entries[key] = {
                        idx = cur_entry_idx,
                        key = key,
                        value = entry.value,
                        comment_before = "",
                        comment_after = "",
                    }
                    cur_entry_idx = cur_entry_idx + 1
                end
                if entry.comment_before and entry.comment_before ~= "" then
                    local comments = merged_sections[section_name].merged_entries[key].comment_before
                    merged_sections[section_name].merged_entries[key].comment_before = comments ..
                        "\n" .. entry.comment_before
                end
                if entry.value ~= merged_sections[section_name].merged_entries[key].value then
                    merged_sections[section_name].merged_entries[key].value = entry.value
                end
                if entry.comment_after and entry.comment_after ~= "" then
                    local comments = merged_sections[section_name].merged_entries[key].comment_after
                    merged_sections[section_name].merged_entries[key].comment_after = comments ..
                        "\n" .. entry.comment_after
                end
            end
        end
    end

    local merged_sections_list = {}

    for _, section in pairs(merged_sections) do
        local entries = {}
        for _, entry in pairs(section.merged_entries) do
            table.insert(entries, {
                idx = entry.idx,
                key = entry.key,
                value = entry.value,
                comment_before = entry.comment_before,
                comment_after = entry.comment_after,
            })
        end
        table.sort(entries, function(a, b) return a.idx < b.idx end)
        section.entries = entries
        table.insert(merged_sections_list, {
            idx = section.idx,
            section_name = section.section_name,
            parent_section = section.parent_section,
            is_overwrite = section.is_overwrite,
            comments = section.comments,
            entries = entries,
        })
    end

    table.sort(merged_sections_list, function(a, b) return a.idx < b.idx end)

    return merged_sections_list
end

return Ltx

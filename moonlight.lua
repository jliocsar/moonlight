local lfs = require "lfs"

local args = { ... }
local cmd = args[1]

local function getReqPosArg(idx, missing_msg)
    local arg = args[idx]
    if not arg then
        if missing_msg then print(missing_msg) end
        return nil
    end
    return arg
end

local function prompt(message)
    os.execute("clear")
    print(message)

    local answer = io.read("*l")
    local is_yes = answer == "Y" or answer == "y"
    local is_no = answer == "N" or answer == "n"

    if not (is_yes or is_no) then
        return prompt(message)
    end

    return is_yes
end

local function iterateAndMatchReplaceFiles(fpath, pattern, replace)
    local iter, dir_obj = lfs.dir(fpath)
    local files = {}
    local filename = iter(dir_obj)

    while filename do
        if filename ~= "." and filename ~= ".." then
            local begins, ends = string.find(filename, pattern)
            if begins then
                local target = string.sub(filename, begins, ends)
                if replace then
                    local renamed = string.gsub(filename, target, replace)
                    files[#files + 1] = { filename, renamed }
                else
                    files[#files + 1] = filename
                end
            end
        end
        filename = iter(dir_obj)
    end

    return files
end

if cmd == "rename" then
    local function printRenameHelp()
        print([[

moonlight rename [directory] [pattern] [replace]

Searches files by the pattern and bulk renames with the replacement string.

]])
    end

    local path = getReqPosArg(2, "Files path is missing")
    local pattern = getReqPosArg(3, "Search pattern is missing")
    local replace = getReqPosArg(4, "Replacement string is missing")

    if not (path and pattern and replace) then
        printRenameHelp()
        os.exit(1)
    end

    local path_attr = lfs.attributes(path)
    if not path_attr then
        print("Path provided does not exist: " .. path)
        printRenameHelp()
        os.exit(1)
    end

    local is_dir_path = path_attr.mode == "directory"
    if not is_dir_path then
        print("Path provided is not a directory: " .. path)
        printRenameHelp()
        os.exit(1)
    end

    local renamed_files = iterateAndMatchReplaceFiles(path, pattern, replace)
    if #renamed_files == 0 then
        print("No files found with the pattern: " .. pattern)
        os.exit(1)
    end

    for _, file in ipairs(renamed_files) do
        local src, target = table.unpack(file)
        local abs_src_fpath = path:gsub("/", "") .. "/" .. src
        local abs_target_fpath = path:gsub("/", "") .. "/" .. target

        if lfs.attributes(abs_target_fpath) then
            if prompt("Filename " .. target .. " already exists in path " .. path .. "\nMake a backup? (Yy/Nn)") then
                local abs_target_fpathbkp = path .. "/" .. "__backup_" .. target
                os.rename(abs_target_fpath, abs_target_fpathbkp)
            end
        end

        if prompt('Renaming "' .. src .. '" to "' .. target .. '"\nProceed? (Yy/Nn)') then
            os.rename(abs_src_fpath, abs_target_fpath)
        end
    end

    return 0
end

if cmd == "overwrite" then
    local function printBulkOverwriteHelp()
        print([[

moonlight overwrite [directory] [source] [pattern]

Searches files by the pattern and overwrites them based on the source file.

]])
    end

    local path = getReqPosArg(2, "Files path is missing")
    local src = getReqPosArg(3, "Source file path is missing")
    local pattern = getReqPosArg(4, "Search pattern is missing")

    if not (path and src and pattern) then
        printBulkOverwriteHelp()
        os.exit(1)
    end

    local path_attr = lfs.attributes(path)
    if not path_attr then
        print("Path provided does not exist: " .. path)
        printBulkOverwriteHelp()
        os.exit(1)
    end

    local src_file_path_attr = lfs.attributes(src)
    if not src_file_path_attr then
        print("Source file provided does not exist: " .. src)
        printBulkOverwriteHelp()
        os.exit(1)
    end

    local is_file = src_file_path_attr.mode == "file"
    if not is_file then
        print("Path provided is not a file: " .. path)
        printBulkOverwriteHelp()
        os.exit(1)
    end

    local files = iterateAndMatchReplaceFiles(path, pattern)
    if #files == 0 then
        print("No files found with the pattern: " .. pattern)
        os.exit(1)
    end

    local src_file = assert(io.open(src, [[rb]]), "No source file found")
    local file_content = src_file:read [[*a]]
    src_file:close()

    if not file_content then
        print("Source file is empty")
        os.exit(1)
    end

    for _, target in ipairs(files) do
        local abs_target_fpath = path:gsub("/", "") .. "/" .. target
        local file = assert(io.open(abs_target_fpath, [[w+b]]), "Target file not found")
        if prompt('Overwriting "' .. target .. '" with contents of "' .. src .. '"\nProceed? (Yy/Nn)') then
            file:write(file_content)
        end
        file:close()
    end

    return 0
end

local function printHelp()
    print([[

moonlight [command] <...options>

List of useful file-system related scripts written in Lua.

Available commands:
- rename
- overwrite

]])
end

print("Unknown command: " .. cmd)
printHelp()
os.exit(127)

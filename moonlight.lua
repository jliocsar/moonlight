local lfs = require "lfs"
local Cli = require "lib.cli"

local args = { ... }
local cmd = args[1]
local cli = Cli:new {
    args = args,
    opts = {
        help = {
            short = "h",
            desc = "Prints this help message",
        }
    }
}

local function readDirAndMatchReplaceFiles(fpath, pattern, replace)
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

if cmd == [[rename]] then
    local function printRenameHelp()
        print([[

moonlight rename <directory> <pattern> <replace>

Searches files by the pattern and bulk renames with the replacement string.

Arguments:
- directory     Path to the directory containing the files
- pattern       Pattern to search for in the filenames
- replace       Replacement string for the pattern

]])
    end

    local path = cli:getReqPosArg(2, "Files path is missing")
    local pattern = cli:getReqPosArg(3, "Search pattern is missing")
    local replace = cli:getReqPosArg(4, "Replacement string is missing")

    if not (path and pattern and replace) then
        return cli:printWithHelpAndFailExit(nil, printRenameHelp)
    end

    local path_attr = lfs.attributes(path)
    if not path_attr then
        return cli:printWithHelpAndFailExit("Path provided does not exist: " .. path, printRenameHelp)
    end

    local is_dir_path = path_attr.mode == "directory"
    if not is_dir_path then
        return cli:printWithHelpAndFailExit("Path provided is not a directory: " .. path, printRenameHelp)
    end

    local renamed_files = readDirAndMatchReplaceFiles(path, pattern, replace)
    if #renamed_files == 0 then
        return cli:printWithHelpAndFailExit("No files found with the pattern: " .. pattern, printRenameHelp)
    end

    for _, file in ipairs(renamed_files) do
        local src, target = table.unpack(file)
        local abs_src_fpath = path:gsub("/", "") .. "/" .. src
        local abs_target_fpath = path:gsub("/", "") .. "/" .. target

        if lfs.attributes(abs_target_fpath) then
            if cli:prompt("Filename " .. target .. " already exists in path " .. path .. "\nMake a backup? (Yy/Nn)") then
                local abs_target_fpathbkp = path .. "/" .. "__backup_" .. target
                os.rename(abs_target_fpath, abs_target_fpathbkp)
            end
        end

        if cli:prompt('Renaming "' .. src .. '" to "' .. target .. '"\nProceed? (Yy/Nn)') then
            os.rename(abs_src_fpath, abs_target_fpath)
        end
    end

    return 0
end

if cmd == [[overwrite]] then
    local function printBulkOverwriteHelp()
        print([[

moonlight overwrite <directory> <source> <pattern>

Searches files by the pattern and overwrites them based on the source file.

Arguments:
- directory     Path to the directory containing the files
- source        Path to the source file to overwrite with
- pattern       Pattern to search for in the filenames

]])
    end

    local path = cli:getReqPosArg(2, "Files path is missing")
    local src = cli:getReqPosArg(3, "Source file path is missing")
    local pattern = cli:getReqPosArg(4, "Search pattern is missing")

    if not (path and src and pattern) then
        return cli:printWithHelpAndFailExit(nil, printBulkOverwriteHelp)
    end

    local path_attr = lfs.attributes(path)
    if not path_attr then
        return cli:printWithHelpAndFailExit("Path provided does not exist: " .. path, printBulkOverwriteHelp)
    end

    local src_file_path_attr = lfs.attributes(src)
    if not src_file_path_attr then
        return cli:printWithHelpAndFailExit("Source file provided does not exist: " .. src, printBulkOverwriteHelp)
    end

    local is_file = src_file_path_attr.mode == "file"
    if not is_file then
        return cli:printWithHelpAndFailExit("Source file provided is not a file: " .. src, printBulkOverwriteHelp)
    end

    local files = readDirAndMatchReplaceFiles(path, pattern)
    if #files == 0 then
        return cli:printWithHelpAndFailExit("No files found with the pattern: " .. pattern, printBulkOverwriteHelp)
    end

    local src_file = assert(
        io.open(src, [[rb]]),
        "No source file found"
    )
    local file_content = src_file:read [[*a]]
    src_file:close()

    if not file_content then
        return cli:printWithHelpAndFailExit("Source file is empty")
    end

    for _, target in ipairs(files) do
        local abs_target_fpath = path .. "/" .. target
        local file = assert(
            io.open(abs_target_fpath, [[w+b]]),
            "Target file not found"
        )
        if cli:prompt('Overwriting "' .. target .. '" with contents of "' .. src .. '"\nProceed? (Yy/Nn)') then
            file:write(file_content)
        end
        file:close()
    end

    return 0
end

if cmd == [[stalker]] then
    local Stalker = require "stalker"
    local stalker = Stalker:new(args)
    stalker:parseCmd()
    return 0
end

local function printHelp()
    print([[

moonlight <command> [...options]

List of useful file-system related scripts written in Lua.

Available commands:
- rename
- overwrite
- stalker

]])
end

if cmd then
    print("Unknown command: " .. cmd)
end
printHelp()
os.exit(127)

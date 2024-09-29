local lfs = require "lfs"
local Cli = require "lib.cli"

local debug_env = os.getenv("DEBUG")
local function debug(msg)
    if debug_env == "1" or debug_env == "true" then
        print("[DEBUG] " .. msg)
    end
end

local function join(list, separator)
    separator = separator or " "
    local text = ""

    for _, val in ipairs(list) do
        text = text .. val .. separator
    end

    return text
end

local function printHelp()
    print([[

moonlight stalker <command> [...options]

List of useful S.T.A.L.K.E.R. related scripts written in Lua.

Available commands:
- replace-texture
- generate-lod
- rescale:2x
- rescale:4x

]])
end

local TextureFormatSuffix = {
    Default = [[.dds]],
    Bump = [[_bump.dds]],
    BumpHash = [[_bump#.dds]],
    Normal = [[_normal.dds]],
    Thm = [[.thm]],
}

local StalkerModUtils = {}

function StalkerModUtils:new(args)
    local obj = {}
    obj.args = args or {}
    obj.cfg = nil
    setmetatable(obj, self)
    self.__index = self
    return obj
end

function StalkerModUtils:parseCfg()
    local cli = self.cli
    local cfg_path = cli.parsed_args.config
    if not cfg_path then
        return
    end

    local cfg_file = assert(io.open(cfg_path, [[r]]), "Could not open config file")
    local cfg_content = cfg_file:read [[*a]]
    cfg_file:close()

    local lyaml = require "lyaml"
    local cfg = assert(lyaml.load(cfg_content), "Could not parse config file")

    self.cfg = cfg
end

function StalkerModUtils:replaceTexture(orig, replace, printReplaceTextureHelp)
    local cli = self.cli
    local orig_dds = orig:find [[.dds$]] and orig or orig .. TextureFormatSuffix.Default
    local orig_attr = lfs.attributes(orig_dds)
    if not orig_attr then
        return cli:printWithHelpAndFailExit("Path provided does not exist: " .. orig, printReplaceTextureHelp)
    end

    if orig_attr.mode ~= "file" then
        return cli:printWithHelpAndFailExit("Path provided is not a file: " .. orig, printReplaceTextureHelp)
    end

    local replace_dds = replace:find [[.dds$]] and replace or replace .. TextureFormatSuffix.Default
    local replace_attr = lfs.attributes(replace_dds)
    if not replace_attr then
        return cli:printWithHelpAndFailExit("Path provided does not exist: " .. replace, printReplaceTextureHelp)
    end

    if replace_attr.mode ~= "file" then
        return cli:printWithHelpAndFailExit("Path provided is not a file: " .. replace, printReplaceTextureHelp)
    end

    local orig_filename = orig_dds:gsub(".*/", ""):gsub("%./", "")
    local replace_filename = replace_dds:gsub(".*/", ""):gsub("%./", "")
    local orig_dir = orig_dds:gsub(orig_filename, "")
    local replace_dir = replace_dds:gsub(replace_filename, "")
    local orig_texture_name = orig_filename:gsub(TextureFormatSuffix.Default, "")
    local replace_texture_name = replace_filename:gsub(TextureFormatSuffix.Default, "")

    debug("Original texture name: " .. orig_texture_name)
    debug("Replace texture name: " .. replace_texture_name)

    local timestamp = os.time()
    local bkp_dir = orig_dir .. "_backups_" .. timestamp
    lfs.mkdir(bkp_dir)

    for alias, suffix in pairs(TextureFormatSuffix) do
        local orig_target = orig_texture_name .. suffix
        local replace_target = replace_texture_name .. suffix
        local orig_target_path = orig_dir .. orig_target
        local replace_target_path = replace_dir .. replace_target

        if lfs.attributes(orig_target_path) then
            local bkp_filepath = bkp_dir .. "/" .. orig_target .. ".bak"
            debug("Found " .. alias .. " file: " .. orig_target)
            debug("Backup file path: " .. bkp_filepath)
            if not os.rename(orig_target_path, bkp_filepath) then
                return cli:printWithHelpAndFailExit("Failed to backup original texture: " .. orig_target_path,
                    printReplaceTextureHelp)
            end
        end

        if lfs.attributes(replace_target_path) then
            local replace_file = assert(io.open(replace_target_path, [[rb]]), "No original file found")
            local replace_file_content = replace_file:read [[*a]]
            replace_file:close()

            local new_file = assert(io.open(orig_target_path, [[wb]]), "Could not create new file")
            new_file:write(replace_file_content)
            new_file:close()

            debug("Replace texture path: " .. replace_target_path)
            debug("Wrote to: " .. orig_target_path)
        end
    end
end

function StalkerModUtils:convertFileToDds(filename, output)
    local convert_cmd = join {
        "./magick",
        filename,
        "-define",
        "dds:mipmaps=12",
        "-define",
        "dds:compression=dxt5",
        "DDS:" .. output .. ".dds"
    }
    return os.execute(convert_cmd)
end

function StalkerModUtils:parseCmd()
    local cli = Cli:new {
        args = self.args,
        opts = {
            help = {
                short = "h",
                desc = "Prints this help message",
            },
            config = {
                short = "c",
                desc = "Path to the configuration file",
            },
            dds = {
                desc = "Converts the output texture to DDS format with mipmaps and DXT5 compression",
            }
        }
    }
    local parsed_args = cli.parsed_args

    if parsed_args.help then
        printHelp()
        return
    end

    self.cli = cli
    self:parseCfg()

    local cmd = cli:getPosArg(2) -- 1 was "stalker"
    if not cmd then
        printHelp()
        os.exit(127)
    end

    local cfg = self.cfg
    local is_dds_format = parsed_args.dds

    if cmd == [[replace-texture]] then
        local function printReplaceTextureHelp()
            print([[

moonlight stalker replace-texture <original> <replacement>

Replaces a Stalker Anomaly texture by another.

Arguments:
- original        Path to the original texture file to be replaced
- replacement     Path to the replacement texture file

]])
        end

        if cfg then
            local replace_texture_cfg = cfg["replace-texture"]
            if not replace_texture_cfg then
                return cli:printWithHelpAndFailExit('No configuration found for "replace-texture"',
                    printReplaceTextureHelp)
            end

            if not type(replace_texture_cfg) == "table" then
                return cli:printWithHelpAndFailExit('Invalid configuration found for "replace-texture"',
                    printReplaceTextureHelp)
            end

            local is_list = replace_texture_cfg[1] ~= nil
            if is_list then
                for _, entry in ipairs(replace_texture_cfg) do
                    local orig = entry.original
                    local replace = entry.replacement
                    self:replaceTexture(orig, replace, printReplaceTextureHelp)
                end
            else
                local orig = replace_texture_cfg.original
                local replace = replace_texture_cfg.replacement
                self:replaceTexture(orig, replace, printReplaceTextureHelp)
            end
        else
            local orig = cli:getReqPosArg(3, "Original file path is missing")
            local replace = cli:getReqPosArg(4, "Replacement file path is missing")

            if not (orig and replace) then
                return cli:printWithHelpAndFailExit(nil, printReplaceTextureHelp)
            end

            self:replaceTexture(orig, replace, printReplaceTextureHelp)
        end

        return
    end

    if cmd == [[generate-lod]] then
        -- WIP
        -- will accept the asphalt, earth, grass and whatever the fuck the other one is
        -- as input to generate a LOD texture with DXT5 and Kaiser mipmaps I guess
        -- need a DDS handling lib.
    end

    if cmd == [[rescale:2x]] then
        local function printRescale2xHelp()
            print([[

moonlight stalker rescale:2x <texture> <output> [...options]

Rescales a `detail` Stalker Anomaly texture by itself 2x (2048 x (2 ^ 2)).

Arguments:
- texture     Path to the texture file to be rescaled
- output      Path to the rescaled texture output

Options:
- dds:     Converts the output file to DDS format with mipmaps and DXT5 compression.

]])
        end

        local texture = cli:getReqPosArg(3, "Texture file path is missing")
        local output = cli:getReqPosArg(4, "Rescaled texture file output path is missing")

        if not (texture and output) then
            return cli:printWithHelpAndFailExit(nil, printRescale2xHelp)
        end

        local output_ext = output:match [[%..*$]]
        local tmp_filename =
            (is_dds_format and "__temp_" or "")
            .. output
            .. (output_ext and "" or texture:match [[%..*$]])
        local rescale_cmd = join {
            "./magick",
            texture,
            "\\( +clone \\)",
            "-append",
            "\\( +clone \\)",
            "+append",
            "-resize",
            "4096x4096",
            tmp_filename
        }

        if not os.execute(rescale_cmd) then
            return cli:printWithHelpAndFailExit("Failed to rescale texture", printRescale2xHelp)
        end

        if is_dds_format then
            if not self:convertFileToDds(tmp_filename, output) then
                return cli:printWithHelpAndFailExit("Failed to convert texture to DDS", printRescale2xHelp)
            end
            local _, error = os.remove(tmp_filename)
            if error then
                return cli:printWithHelpAndFailExit("Failed to remove temporary file: " .. tmp_filename,
                    printRescale2xHelp)
            end
        end

        return
    end

    if cmd == [[rescale:4x]] then
        local function printRescale2xHelp()
            print([[

moonlight stalker rescale:4x <texture> <output> [...options]

Rescales a `detail` Stalker Anomaly texture by itself 4x (1024 x (4 ^ 2)).

Arguments:
- texture: Path to the texture file to be rescaled
- output:  Path to the rescaled texture output

Options:
- dds:     Converts the output file to DDS format with mipmaps and DXT5 compression.

]])
        end
        local texture = cli:getReqPosArg(3, "Texture file path is missing")
        local output = cli:getReqPosArg(4, "Rescaled texture file output path is missing")

        if not (texture and output) then
            return cli:printWithHelpAndFailExit(nil, printRescale2xHelp)
        end

        local output_ext = output:match [[%..*$]]
        local tmp_filename =
            (is_dds_format and "__temp_" or "")
            .. output
            .. (output_ext and "" or texture:match [[%..*$]])
        local rescale_cmd = join {
            "./magick",
            texture,
            "\\( +clone +clone +clone \\)",
            "-append",
            "\\( +clone +clone +clone \\)",
            "+append",
            "-resize",
            "4096x4096",
            tmp_filename
        }

        if not os.execute(rescale_cmd) then
            return cli:printWithHelpAndFailExit("Failed to rescale texture", printRescale2xHelp)
        end

        if is_dds_format then
            if not self:convertFileToDds(tmp_filename, output) then
                return cli:printWithHelpAndFailExit("Failed to convert texture to DDS", printRescale2xHelp)
            end
            local _, error = os.remove(tmp_filename)
            if error then
                return cli:printWithHelpAndFailExit("Failed to remove temporary file: " .. tmp_filename,
                    printRescale2xHelp)
            end
        end

        return
    end

    print("Unknown command: " .. cmd)
    printHelp()
    os.exit(127)
end

return StalkerModUtils

local Cli = {}

function Cli:new(config)
    local args = config.args
    local opts = config.opts
    local parsed_args = {}
    local opt_alias_map = {}

    for key, opt in pairs(opts) do
        if opt.short then
            opt_alias_map[opt.short] = key
        end
    end

    for i, arg in ipairs(args) do
        if arg:find [[^%-]] then
            local entry_match = [[^(.*)=(.*)$]]

            local long_entry = arg:match [[^%-%-(.*)]]
            if long_entry then
                local key, value = long_entry:match(entry_match)
                if key then
                    parsed_args[key] = value
                else
                    parsed_args[long_entry] = true
                end
            end

            local short_entry = arg:match [[^%-(.*)]]
            if short_entry then
                local key, value = short_entry:match(entry_match)
                if opt_alias_map[key] then
                    local long_key = opt_alias_map[key]
                    parsed_args[long_key] = value
                else
                    local long_key = opt_alias_map[short_entry]
                    if long_key then
                        parsed_args[long_key] = true
                    end
                end
            end
        end
    end

    local obj = {
        parsed_args = parsed_args
    }
    obj.args = args or {}
    setmetatable(obj, self)
    self.__index = self
    return obj
end

function Cli:getPosArg(idx)
    return self.args[idx]
end

function Cli:getReqPosArg(idx, missing_msg)
    local arg = self.args[idx]
    if not arg then
        if missing_msg then print(missing_msg) end
        return nil
    end
    return arg
end

function Cli:printWithHelpAndFailExit(msg, help)
    if msg then
        print(msg)
    end
    if help then
        help()
    end
    return os.exit(1)
end

function Cli:prompt(message)
    os.execute "clear"
    print(message)

    local answer = io.read [[*l]]
    local is_yes = answer == "Y" or answer == "y"
    local is_no = answer == "N" or answer == "n"

    if not (is_yes or is_no) then
        return Cli.prompt(message)
    end

    return is_yes
end

return Cli

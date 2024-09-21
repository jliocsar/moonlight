local Cli = {}

function Cli:new(args)
    local obj = {}
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

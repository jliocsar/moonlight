local Thm = {}

-- enums
local Type = {
    Image = 0,
    CubeMap = 1,
    BumpMap = 2,
    NormalMap = 3,
    Terrain = 4,
}
local Format = {
    DXT1 = 0,
    ADXT1 = 1,
    DXT3 = 2,
    DXT5 = 3,
    ["4444"] = 4,
    ["1555"] = 5,
    ["565"] = 6,
    RGB = 7,
    RGBA = 8,
    NVHS = 9,
    NVHU = 10,
    A8 = 11,
    L8 = 12,
    A8L8 = 13,
}
local BumpMode = {
    Autogen = 0,
    None = 1,
    Use = 2,
    UseParallax = 3,
}
local Material = {
    OrenNayarBlin = 0,
    BlinPhong = 1,
    PhongMetal = 2,
    MetalOrenNayar = 3,
}
local TextureFlag = {
    GenerateMipMaps = 1 << 0,
    BinaryAlpha = 1 << 1,
    AlphaBorder = 1 << 4,
    ColorBorder = 1 << 5,
    FadeToColor = 1 << 6,
    FadeToAlpha = 1 << 7,
    DitherColor = 1 << 8,
    DitherEachMIPLevel = 1 << 9,
    GreyScale = 1 << 10,
    DiffuseDetail = 1 << 23,
    ImplicitLighted = 1 << 24,
    HasAlpha = 1 << 25,
    BumpDetail = 1 << 26,
}
local MipFilter = {
    Box = 0,
    Cubic = 1,
    Point = 2,
    Triangle = 3,
    Quadratic = 4,
    Advanced = 5,
    Catrom = 6,
    Mitchell = 7,
    Gaussian = 8,
    Sinc = 9,
    Bessel = 10,
    Hanning = 11,
    Hamming = 12,
    Blackman = 13,
    Kaiser = 14,
}
local D3dFormat = {
    R8G8B8 = 20,
    R5G6B5 = 23,
    A1R5G5B5 = 25,
    A4R4G4B4 = 26,
    A8 = 28,
    A8B8G8R8 = 32,
    L8 = 50,
    A8L8 = 51,
    DXT1 = 827611204,
    DXT3 = 861165636,
    DXT5 = 894720068,
    MULTI2_ARGB8 = 827606349,
}
local Chunk = {
    Version = 0x0810,
    TextureParam = 0x0812,
    Type = 0x0813,
    TextureType = 0x0814,
    DetailExt = 0x0815,
    Material = 0x0816,
    Bump = 0x0817,
    ExtNormalMap = 0x0818,
    FadeDelay = 0x0819,
    ThmEditorFlag = 0x0820,
}

-- local soc_repaired = false
-- local fmt = Format.DXT1
-- local type = Type.Image
-- local material = Material.OrenNayarBlin
-- local bump_mode = BumpMode.None
-- local border_color = 0
-- local fade_color = 0
-- local fade_amount = 0
-- local width = 0
-- local height = 0
-- local material_weight = 0.5
-- local bump_virtual_height = 0.05
-- local fade_delay = 0
-- local detail_scale = 1
-- local detail_name = ""
-- local bump_name = ""
-- local ext_normal_map_name = ""
-- local m_flags = TextureFlag.DitherColor

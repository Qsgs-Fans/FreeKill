-- SPDX-License-Identifier: MIT
-- Copied from https://github.com/Zash/lua-cbor

-- Concise Binary Object Representation (CBOR)
-- RFC 7049

local function softreq(pkg, field)
  local ok, mod = pcall(require, pkg);
  if not ok then return end
  if field then return mod[field]; end
  return mod;
end
local dostring = function(s)
  local ok, f = load(function()
    local ret = s;
    s = nil
    return ret;
  end);
  if ok and f then
    return f();
  end
end

local setmetatable = setmetatable;
local getmetatable = getmetatable;
local dbg_getmetatable = debug.getmetatable;
local assert = assert;
local error = error;
local type = type;
local pairs = pairs;
local ipairs = ipairs;
local tostring = tostring;
local s_char = string.char;
local t_concat = table.concat;
local t_sort = table.sort;
local m_floor = math.floor;
local m_abs = math.abs;
local m_huge = math.huge;
local m_max = math.max;
local maxint = math.maxinteger or 9007199254740992;
local minint = math.mininteger or -9007199254740992;
local NaN = 0 / 0;
local m_frexp = math.frexp;
local m_ldexp = math.ldexp or function(x, exp) return x * 2.0 ^ exp; end;
local m_type = math.type or function(n) return n % 1 == 0 and n <= maxint and n >= minint and "integer" or "float" end;
local s_pack = string.pack or softreq("struct", "pack");
local s_unpack = string.unpack or softreq("struct", "unpack");
local b_rshift = softreq("bit32", "rshift") or softreq("bit", "rshift") or
    dostring "return function(a,b) return a >> b end" or
    function(a, b) return m_max(0, m_floor(a / (2 ^ b))); end;

-- sanity check
if s_pack and s_pack(">I2", 0) ~= "\0\0" then
  s_pack = nil;
end
if s_unpack and s_unpack(">I2", "\1\2\3\4") ~= 0x102 then
  s_unpack = nil;
end

local _ENV = nil; -- luacheck: ignore 211

local encoder = {};

local function encode(obj, opts)
  return encoder[type(obj)](obj, opts);
end

-- Major types 0, 1 and length encoding for others
local function integer(num, m)
  if m == 0 and num < 0 then
    -- negative integer, major type 1
    num, m = -num - 1, 32;
  end
  if num < 24 then
    return s_char(m + num);
  elseif num < 2 ^ 8 then
    return s_char(m + 24, num);
  elseif num < 2 ^ 16 then
    return s_char(m + 25, b_rshift(num, 8), num % 0x100);
  elseif num < 2 ^ 32 then
    return s_char(m + 26,
      b_rshift(num, 24) % 0x100,
      b_rshift(num, 16) % 0x100,
      b_rshift(num, 8) % 0x100,
      num % 0x100);
  elseif num < 2 ^ 64 then
    local high = m_floor(num / 2 ^ 32);
    num = num % 2 ^ 32;
    return s_char(m + 27,
      b_rshift(high, 24) % 0x100,
      b_rshift(high, 16) % 0x100,
      b_rshift(high, 8) % 0x100,
      high % 0x100,
      b_rshift(num, 24) % 0x100,
      b_rshift(num, 16) % 0x100,
      b_rshift(num, 8) % 0x100,
      num % 0x100);
  end
  error "int too large";
end

if s_pack then
  function integer(num, m)
    local fmt;
    m = m or 0;
    if num < 24 then
      fmt, m = ">B", m + num;
    elseif num < 256 then
      fmt, m = ">BB", m + 24;
    elseif num < 65536 then
      fmt, m = ">BI2", m + 25;
    elseif num < 4294967296 then
      fmt, m = ">BI4", m + 26;
    else
      fmt, m = ">BI8", m + 27;
    end
    return s_pack(fmt, m, num);
  end
end

local simple_mt = {};
function simple_mt:__tostring() return self.name or ("simple(%d)"):format(self.value); end

function simple_mt:__tocbor() return self.cbor or integer(self.value, 224); end

local function simple(value, name, cbor)
  assert(value >= 0 and value <= 255, "bad argument #1 to 'simple' (integer in range 0..255 expected)");
  return setmetatable({ value = value, name = name, cbor = cbor }, simple_mt);
end

local tagged_mt = {};
function tagged_mt:__tostring() return ("%d(%s)"):format(self.tag, tostring(self.value)); end

function tagged_mt:__tocbor(opts) return integer(self.tag, 192) .. encode(self.value, opts); end

local function tagged(tag, value)
  assert(tag >= 0, "bad argument #1 to 'tagged' (positive integer expected)");
  return setmetatable({ tag = tag, value = value }, tagged_mt);
end

local null = simple(22, "null");           -- explicit null
local undefined = simple(23, "undefined"); -- undefined or nil
local BREAK = simple(31, "break", "\255");

-- Number types dispatch
function encoder.number(num)
  return encoder[m_type(num)](num);
end

-- Major types 0, 1
function encoder.integer(num)
  if num < 0 then
    return integer(-1 - num, 32);
  end
  return integer(num, 0);
end

-- Major type 7
function encoder.float(num)
  if num ~= num then -- NaN shortcut
    return "\251\127\255\255\255\255\255\255\255";
  end
  -- 本项目特化 禁止传入.0
  if num == m_floor(num) then
    return encoder.integer(num)
  end
  local sign = (num > 0 or 1 / num > 0) and 0 or 1;
  num = m_abs(num)
  if num == m_huge then
    return s_char(251, sign * 128 + 128 - 1) .. "\240\0\0\0\0\0\0";
  end
  local fraction, exponent = m_frexp(num)
  if fraction == 0 then
    return s_char(251, sign * 128) .. "\0\0\0\0\0\0\0";
  end
  fraction = fraction * 2;
  exponent = exponent + 1024 - 2;
  if exponent <= 0 then
    fraction = fraction * 2 ^ (exponent - 1)
    exponent = 0;
  else
    fraction = fraction - 1;
  end
  return s_char(251,
    sign * 2 ^ 7 + m_floor(exponent / 2 ^ 4) % 2 ^ 7,
    exponent % 2 ^ 4 * 2 ^ 4 +
    m_floor(fraction * 2 ^ 4 % 0x100),
    m_floor(fraction * 2 ^ 12 % 0x100),
    m_floor(fraction * 2 ^ 20 % 0x100),
    m_floor(fraction * 2 ^ 28 % 0x100),
    m_floor(fraction * 2 ^ 36 % 0x100),
    m_floor(fraction * 2 ^ 44 % 0x100),
    m_floor(fraction * 2 ^ 52 % 0x100)
  )
end

if s_pack then
  function encoder.float(num)
    return s_pack(">Bd", 251, num);
  end
end


-- Major type 2 - byte strings
function encoder.bytestring(s)
  return integer(#s, 64) .. s;
end

-- Major type 3 - UTF-8 strings
function encoder.utf8string(s)
  return integer(#s, 96) .. s;
end

-- Lua strings are byte strings
encoder.string = encoder.bytestring;

function encoder.boolean(bool)
  return bool and "\245" or "\244";
end

encoder["nil"] = function() return "\246"; end

function encoder.userdata(ud, opts)
  local mt = dbg_getmetatable(ud);
  if mt then
    local encode_ud = opts and opts[mt] or mt.__tocbor;
    if encode_ud then
      return encode_ud(ud, opts);
    end
  end
  error "can't encode userdata";
end

function encoder.table(t, opts)
  local mt = getmetatable(t);
  if mt then
    local encode_t = opts and opts[mt] or mt.__tocbor;
    if encode_t then
      return encode_t(t, opts);
    end
  end
  -- the table is encoded as an array iff when we iterate over it,
  -- we see successive integer keys starting from 1.  The lua
  -- language doesn't actually guarantee that this will be the case
  -- when we iterate over a table with successive integer keys, but
  -- due an implementation detail in PUC Rio Lua, this is what we
  -- usually observe.  See the Lua manual regarding the # (length)
  -- operator.  In the case that this does not happen, we will fall
  -- back to a map with integer keys, which becomes a bit larger.
  local array, map, i, p = { integer(#t, 128) }, { "\191" }, 1, 2;
  local is_array = true;
  for k, v in pairs(t) do
    is_array = is_array and i == k;
    i = i + 1;

    local encoded_v = encode(v, opts);
    array[i] = encoded_v;

    map[p], p = encode(k, opts), p + 1;
    map[p], p = encoded_v, p + 1;
  end
  -- map[p] = "\255";
  map[1] = integer(i - 1, 160);
  return t_concat(is_array and array or map);
end

-- Array or dict-only encoders, which can be set as __tocbor metamethod
function encoder.array(t, opts)
  local array = {};
  for i, v in ipairs(t) do
    array[i] = encode(v, opts);
  end
  return integer(#array, 128) .. t_concat(array);
end

function encoder.map(t, opts)
  local map, p, len = { "\191" }, 2, 0;
  for k, v in pairs(t) do
    map[p], p = encode(k, opts), p + 1;
    map[p], p = encode(v, opts), p + 1;
    len = len + 1;
  end
  -- map[p] = "\255";
  map[1] = integer(len, 160);
  return t_concat(map);
end

encoder.dict = encoder.map; -- COMPAT

function encoder.ordered_map(t, opts)
  local map = {};
  if not t[1] then -- no predefined order
    local i = 0;
    for k in pairs(t) do
      i = i + 1;
      map[i] = k;
    end
    t_sort(map);
  end
  for i, k in ipairs(t[1] and t or map) do
    map[i] = encode(k, opts) .. encode(t[k], opts);
  end
  return integer(#map, 160) .. t_concat(map);
end

encoder["function"] = function()
  error "can't encode function";
end

-- Decoder
-- Reads from a file-handle like object
local function read_bytes(fh, len)
  return fh:read(len);
end

local function read_byte(fh)
  return fh:read(1):byte();
end

local function read_length(fh, mintyp)
  if mintyp < 24 then
    return mintyp;
  elseif mintyp < 28 then
    local out = 0;
    for _ = 1, 2 ^ (mintyp - 24) do
      out = out * 256 + read_byte(fh);
    end
    return out;
  else
    error "invalid length";
  end
end

local decoder = {};

local function read_type(fh)
  local byte = read_byte(fh);
  return b_rshift(byte, 5), byte % 32;
end

local function read_object(fh, opts)
  local typ, mintyp = read_type(fh);
  return decoder[typ](fh, mintyp, opts);
end

local function read_integer(fh, mintyp)
  return read_length(fh, mintyp);
end

local function read_negative_integer(fh, mintyp)
  return -1 - read_length(fh, mintyp);
end

local function read_string(fh, mintyp)
  if mintyp ~= 31 then
    return read_bytes(fh, read_length(fh, mintyp));
  end
  local out = {};
  local i = 1;
  local v = read_object(fh);
  while v ~= BREAK do
    out[i], i = v, i + 1;
    v = read_object(fh);
  end
  return t_concat(out);
end

local function read_unicode_string(fh, mintyp)
  return read_string(fh, mintyp);
  -- local str = read_string(fh, mintyp);
  -- if have_utf8 and not utf8.len(str) then
  -- TODO How to handle this?
  -- end
  -- return str;
end

local function read_array(fh, mintyp, opts)
  local out = {};
  if mintyp == 31 then
    local i = 1;
    local v = read_object(fh, opts);
    while v ~= BREAK do
      out[i], i = v, i + 1;
      v = read_object(fh, opts);
    end
  else
    local len = read_length(fh, mintyp);
    for i = 1, len do
      out[i] = read_object(fh, opts);
    end
  end
  return out;
end

local function read_map(fh, mintyp, opts)
  local out = {};
  local k;
  if mintyp == 31 then
    local i = 1;
    k = read_object(fh, opts);
    while k ~= BREAK do
      out[k], i = read_object(fh, opts), i + 1;
      k = read_object(fh, opts);
    end
  else
    local len = read_length(fh, mintyp);
    for _ = 1, len do
      k = read_object(fh, opts);
      out[k] = read_object(fh, opts);
    end
  end
  return out;
end

local tagged_decoders = {};

local function read_semantic(fh, mintyp, opts)
  local tag = read_length(fh, mintyp);
  local value = read_object(fh, opts);
  local postproc = opts and opts[tag] or tagged_decoders[tag];
  if postproc then
    return postproc(value);
  end
  return tagged(tag, value);
end

local function read_half_float(fh)
  local exponent = read_byte(fh);
  local fraction = read_byte(fh);
  local sign = exponent < 128 and 1 or -1;      -- sign is highest bit

  fraction = fraction + (exponent * 256) % 1024; -- copy two(?) bits from exponent to fraction
  exponent = b_rshift(exponent, 2) % 32;        -- remove sign bit and two low bits from fraction;

  if exponent == 0 then
    return sign * m_ldexp(fraction, -24);
  elseif exponent ~= 31 then
    return sign * m_ldexp(fraction + 1024, exponent - 25);
  elseif fraction == 0 then
    return sign * m_huge;
  else
    return NaN;
  end
end

local function read_float(fh)
  local exponent = read_byte(fh);
  local fraction = read_byte(fh);
  local sign = exponent < 128 and 1 or -1; -- sign is highest bit
  exponent = exponent * 2 % 256 + b_rshift(fraction, 7);
  fraction = fraction % 128;
  fraction = fraction * 256 + read_byte(fh);
  fraction = fraction * 256 + read_byte(fh);

  if exponent == 0 then
    return sign * m_ldexp(exponent, -149);
  elseif exponent ~= 0xff then
    return sign * m_ldexp(fraction + 2 ^ 23, exponent - 150);
  elseif fraction == 0 then
    return sign * m_huge;
  else
    return NaN;
  end
end

local function read_double(fh)
  local exponent = read_byte(fh);
  local fraction = read_byte(fh);
  local sign = exponent < 128 and 1 or -1; -- sign is highest bit

  exponent = exponent % 128 * 16 + b_rshift(fraction, 4);
  fraction = fraction % 16;
  fraction = fraction * 256 + read_byte(fh);
  fraction = fraction * 256 + read_byte(fh);
  fraction = fraction * 256 + read_byte(fh);
  fraction = fraction * 256 + read_byte(fh);
  fraction = fraction * 256 + read_byte(fh);
  fraction = fraction * 256 + read_byte(fh);

  if exponent == 0 then
    return sign * m_ldexp(exponent, -149);
  elseif exponent ~= 0xff then
    return sign * m_ldexp(fraction + 2 ^ 52, exponent - 1075);
  elseif fraction == 0 then
    return sign * m_huge;
  else
    return NaN;
  end
end


if s_unpack then
  function read_float(fh) return s_unpack(">f", read_bytes(fh, 4)) end

  function read_double(fh) return s_unpack(">d", read_bytes(fh, 8)) end
end

-- notify按: QML会把本来从Lua传入的整数转为浮点数 并cbor后发送到服务端
-- 为了解决这个 这里干脆直接杜绝了让cbor.decode解析出一切1.0之类的.0浮点数 强制转成整数
local function convert_dot0(n)
  if n == m_floor(n) then
    return m_floor(n)
  end
  return n
end

local function read_simple(fh, value, opts)
  if value == 24 then
    value = read_byte(fh);
  end
  if value == 20 then
    return false;
  elseif value == 21 then
    return true;
  elseif value == 22 then
    return null;
  elseif value == 23 then
    return undefined;
  elseif value == 25 then
    return convert_dot0(read_half_float(fh));
  elseif value == 26 then
    return convert_dot0(read_float(fh));
  elseif value == 27 then
    return convert_dot0(read_double(fh));
  elseif value == 31 then
    return BREAK;
  end
  if opts and opts.simple then
    return opts.simple(value);
  end
  return simple(value);
end

decoder[0] = read_integer;
decoder[1] = read_negative_integer;
decoder[2] = read_string;
decoder[3] = read_unicode_string;
decoder[4] = read_array;
decoder[5] = read_map;
decoder[6] = read_semantic;
decoder[7] = read_simple;

-- opts.more(n) -> want more data
-- opts.simple -> decode simple value
-- opts[int] -> tagged decoder
local function decode(s, opts)
  local fh = {};
  local pos = 1;

  local more;
  if type(opts) == "function" then
    more = opts;
  elseif type(opts) == "table" then
    more = opts.more;
  elseif opts ~= nil then
    error(("bad argument #2 to 'decode' (function or table expected, got %s)"):format(type(opts)));
  end
  if type(more) ~= "function" then
    function more()
      error "input too short";
    end
  end

  function fh:read(bytes)
    local ret = s:sub(pos, pos + bytes - 1);
    if #ret < bytes then
      ret = more(bytes - #ret, fh, opts);
      if ret then self:write(ret); end
      return self:read(bytes);
    end
    pos = pos + bytes;
    return ret;
  end

  function fh:write(bytes) -- luacheck: no self
    s = s .. bytes;
    if pos > 256 then
      s = s:sub(pos + 1);
      pos = 1;
    end
    return #bytes;
  end

  return read_object(fh, opts);
end

return {
  -- en-/decoder functions
  encode = encode,
  decode = decode,
  decode_file = read_object,

  -- tables of per-type en-/decoders
  type_encoders = encoder,
  type_decoders = decoder,

  -- special treatment for tagged values
  tagged_decoders = tagged_decoders,

  -- constructors for annotated types
  simple = simple,
  tagged = tagged,

  -- pre-defined simple values
  null = null,
  undefined = undefined,
};

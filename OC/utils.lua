local utils = {}

function table.getn(tbl)
  --if not tbl then return 0 end
  local n=0
  for _,_  in pairs(tbl) do
    n = n + 1
  end
  return n
end

local function toBits(num, bits)
    -- returns a table of bits
    local t={} -- will contain the bits
    for b=bits,1,-1 do
        local rest=math.floor(math.fmod(num,2))
        t[b]=rest
        num=(num-rest)/2
    end
    if num==0 then return t else return {'Not enough bits to represent this number'}end
end
-- bits=toBits(num, bits)
-- print(table.concat(bits))


-- local function r(num, numDecimalPlaces)
--   return tonumber(string.format("%." .. (numDecimalPlaces or 3) .. "f", num+.0011))
-- end

local function deepCopy(t) -- deep-copy a table
  if type(t) ~= "table" then return t end
  local meta = getmetatable(t)
  local target = {}
  for k, v in pairs(t) do
      if type(v) == "table" then
          target[k] = deepCopy(v)
      else
          target[k] = v
      end
  end
  setmetatable(target, meta)
  return target
end
utils.deepCopy = deepCopy

function utils.round(num, numDecimalPlaces)
  local mult = 10^(numDecimalPlaces or 0)
  return math.floor(num * mult + 0.5) / mult
end

--▀▁▂▃▄▅▆▇█ ▉▊▋▌▍▎▏▐░▒▓█
-- ⡀⣀⣄⣤⣦⣶⣷⣿ ⣀⣄⣆⣇⣧⣷⣿○◔◐◕⬤🌑🌘🌗🌖🌕
-- ◦∘○ⵔ◯ꖴ☉⦿⦿ΟO◌𝚘●⬤⚪ ◦⭘🞅🞇🞉⬤⏺ ⭘⨀ⵙ⏺
-- ⵔⵔⵔⵔⵔⵔⵔ
-- ◔◔◔◔◔◔◔
-- ◐◐◐◐◐◐◐
-- ◕◕◕◕◕◕◕
-- ⬤⬤⬤⬤⬤⬤⬤
-- ⭘⭘⭘⭘⭘⭘⭘⭘⭘⭘
-- 🞅🞅🞅🞅🞅🞅🞅🞅🞅🞅
-- 🞇🞇🞇🞇🞇🞇🞇🞇🞇🞇
-- 🞉🞉🞉🞉🞉🞉🞉🞉🞉🞉
-- ⬤⬤⬤⬤⬤⬤⬤⬤⬤⬤
-- ■□◙▢▣▤▥▨▧▦▩
-- ①②③④⑤⑥⑦⑧⑨⑩⑪⑫⑬⑭⑮⑯⑰⑱⑲⑳
-- ➊➋➌➍➎➏➐➑➒➓⓫⓬⓭⓮⓯⓰⓱⓲⓳⓴
-- ⓿❶❷❸❹❺❻❼❽❾❿
local bars = {"░","▒","▓","█"}
local circles = {"🞅","🞇","🞉","⬤"}
--local circles = {"🞯", "🞰", "🞱", "🞲", "🞳", "🞴"}
function utils.frmtNumber(n, barCount)
  --if n>1 then n=1 elseif n<0 then n=0 end
  barCount = barCount or 3
  local arr = barCount == 1 and circles or  bars
  if n==0 then return (arr[1]):rep(barCount) end
  local barMax = #arr
  local s = ""
  for i=0, barCount-1 do
    local mod = n - i/(barCount-0.9)/(barMax-1)-- -0.00000000001
    --if tttt then print(n, mod, math.ceil(mod*(barMax-1)))end
    mod = mod<0 and 0 or mod
    local cut = math.ceil(mod*(barMax-1))
    cut = cut>barMax-1 and barMax-1 or cut
    -- if not bars[cut+1] then
    --   print(n, cut, mod, barMax)
    -- end
    --print("cut=",cut)
    s = s .. arr[cut+1]
  end
  return s
end


function utils.getHigherkv(t)
  local k, v, prev = 1, 0, 1
  for i=1,#t do
    if v < t[i] then
      prev = k
      k = i
      v = t[i]
    end
  end
  return k, v, prev
end

function utils.valuesToKeys(tbl)
  local result = {}
  for i=1,#tbl do
    result[tbl[i]] = i
  end
  return result
end


-- ********************************************************************************** --
-- **   3D Array                                                                   ** --
-- **                                                                              ** --
-- **   By Krutoy242                                                               ** --
-- **                                                                              ** --
-- ********************************************************************************** --
utils.arr3d = function() return setmetatable({
  set = function(t,x,y,z,v)
    t[z]    = t[z]    or {}
    t[z][y] = t[z][y] or {}
    t[z][y][x] = v
  end,
  define = function(t,x,y,z,v)
    if t[z] and t[z][y] and t[z][y][x] then return false end
    t:set(x,y,z,v)
  end,
  setVolume = function(t, x1,y1,z1,x2,y2,z2, v)
    for z=z1, z2 do
      for y=y1, y2 do
        for x=x1, x2 do
          t:set(x,y,z, v)
        end
      end
    end
  end
  }, { __call = function(t, x, y, z)
    if not t[z] or not t[z][y] then return nil end
    return t[z][y][x]
  end
})end

-- ********************************************************************************** --
-- **   Debug                                                                      ** --
-- **                                                                              ** --
-- **                                                                              ** --
-- **                                                                              ** --
-- ********************************************************************************** --

-- debug()

local debug_level = math.huge
local s_tblBuffer = {}

-- Debug levels O()
local levelsOfDebug = utils.valuesToKeys{
  "Level_Zero",
  "Level_Important",
  "Level_Full",
  "Level_Detailed",
  "Level_Deep"
}

utils.debug = setmetatable({},{
  __index = function(self, k)
    return (levelsOfDebug[k] or math.huge) <= debug_level
  end,

  __newindex = function(self, k, v)
    debug_level = v
  end,

  -- Returns if level are fine for store data
  __call = function(self, ...)
    if #s_tblBuffer<1000 then s_tblBuffer[#s_tblBuffer+1] = {...} end
    return io.write(...)
    -- if type(level) ~= "number" then error("Can debug only on number levels", 2) end
    -- return level <= debug_level
  end
})

function utils.flush()
  local s_buffer
  for i=1, #s_tblBuffer do
    s_buffer = s_buffer or ""
    s_buffer = s_buffer .. table.concat(s_tblBuffer[i])
  end
  s_tblBuffer = {}

  return s_buffer
end

local s_lastFlush = ""
function utils.lastFlush()
  local s = utils.flush()
  if not s then
    return s_lastFlush
  else
    s_lastFlush = s
    return s
  end
end

return utils
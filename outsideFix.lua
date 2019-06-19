
--          ______________________________________
-- ________|                                      |_______
-- \       |        Emulates of MC world          |      /
--  \      |                                      |     /
--  /      |______________________________________|     \
-- /__________)                                (_________\


local returnTrue =  function() return true end

DEBUG = {}

local utils = require"utils"
local O = utils.debug

function table.pack(...)
  return { n = select("#", ...), ... }
end
if unpack then table.unpack = unpack end
if table.unpack then unpack = table.unpack end
if not loadstring then loadstring = load end

-- local G_PositionMatrix
local maxDist = 20
local totalVolume = (maxDist*2+1)^3
local d_maxDist = maxDist*4
local rnd = math.random
local volume = 0
--local rndPos = function() return math.ceil(rnd(maxDist)-maxDist/2) end
local rndPos = function(chunkSize) return math.ceil(rnd((maxDist)*2-chunkSize)-maxDist) end

function DEBUG.RemakeWorld(chunkSize)
  G_PositionMatrix = utils.arr3d()
  local cc = 3
  G_PositionMatrix:setVolume(-cc,-cc,-cc,cc,cc,cc, true)
  volume = (cc*2+1)^3
  for i=1,10 do
    local x1, y1, z1 = rndPos(chunkSize),rndPos(chunkSize),rndPos(chunkSize)
    local x2, y2, z2 = x1+chunkSize, y1+chunkSize, z1+chunkSize
    for z=z1, z2 do
      for y=y1, y2 do
        for x=x1, x2 do
          if not G_PositionMatrix(x,y,z) then
            local isBlock = true
            -- if love then
            --   isBlock = love.math.noise(x/10,y/10,z/20) > 0.5
            -- end
            G_PositionMatrix:set(x,y,z, isBlock)
            volume = volume + 1
          end
        end
      end
    end
  end
  BLOCKDENSITY = volume/totalVolume


  if O.Level_Important then
    O( string.format(
[[
    +------+ --  Minecraft World mulated.
   /|     /|  |
  +-+----+ | [%d]
  | |    | |  |
  | +----+-+ --       blocks: %d
  |/     |/     total volume: %d
  +------+  
  ]]
  ,maxDist*2+1, volume, totalVolume))
  end
end


function  GetVolume() return volume end


local function computeDelta(side)
  local dx,dy,dz = 0,0,0
  if side == 1 then
    dz=1
  elseif side == 0 then
    dz=-1
  else
    dx,dy =  unpack(({{1,0},{0,1},{-1,0},{0,-1}})[_G.robot.f+1])
  end
  return dx,dy,dz
end
local function computeTargetPos(side)
  local dx,dy,dz = computeDelta(side)
  return _G.robot.x+dx, _G.robot.y+dy, _G.robot.z+dz
end

local robot = {
  setLightColor = returnTrue,
  turn = returnTrue,
  swing = function(side)
      local tx,ty,tz = computeTargetPos(side)
      --tx,ty,tz = tx+maxDist*2, ty+maxDist*2, tz+maxDist*2

      local notEmpty = G_PositionMatrix(tx,ty,tz)
      G_PositionMatrix:set(tx,ty,tz, nil)
      return notEmpty
    end,
  move = function(side)
      local dx,dy,dz = computeTargetPos(side)
      if math.abs(dx) > maxDist then return false end
      if math.abs(dy) > maxDist then return false end
      if math.abs(dz) > maxDist then return false end
      return true
    end,
}

local _require = require
require = function(...)
  local args = {...}
  if args[1] == "component" then
    return {robot = robot}
  elseif args[1] == "sides" then
    return _require"lib/sides"
  end

  return _require(...)
end

-- local _oldLoad = load
-- load = function (...)
--   local args = {...}
--   local func = function(...) return _oldLoad(table.unpack(args)) end
--   return func
-- end

function checkArg(n, have, ...)
  have = type(have)
  local function check(want, ...)
    if not want then
      return false
    else
      return have == want or check(...)
    end
  end
  if not check(...) then
    local msg = string.format("bad argument #%d (%s expected, got %s)",
                              n, table.concat({...}, " or "), have)
    error(msg, 3)
  end
end
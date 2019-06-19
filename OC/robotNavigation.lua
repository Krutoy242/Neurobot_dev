local robot = require("component").robot
local sides = require("sides")
local abs = math.abs

local r = {
  x = 0,
  y = 0,
  z = 0,
  f = 0,

  binaryDirection = { -- Depending on .f value
    [0]={1,1}, --⬆
        {1,0}, --➞
        {0,0}, --⬇
        {0,1}  --⬅
  }
}

local function round(num, numDecimalPlaces)
  local mult = 10^(numDecimalPlaces or 0)
  return math.floor(num * mult + 0.5) / mult
end

if DEBUG then _G.robot = r end


local look  = {{1,0},{0,1},{-1,0},{0,-1}}
local delta = {[0] = function() r.x = r.x + 1 end, [1] = function() r.y = r.y + 1 end,
               [2] = function() r.x = r.x - 1 end, [3] = function() r.y = r.y - 1 end}

function r.pos() return r.x, r.y, r.z, r.f end
function r.lookTo(f) f=f or r.f return r.x+look[f+1][1], r.y+look[f+1][2], r.z, f end
function r.guessPos(side) -- Guess pos if we would move or turn
  if     side == sides.forward then return r.lookTo()
  elseif side == sides.down    then return r.x, r.y, r.z-1, r.f
  elseif side == sides.up      then return r.x, r.y, r.z+1, r.f
  elseif side == sides.right   then return r.x, r.y, r.z, (r.f + 1) % 4
  elseif side == sides.left    then return r.x, r.y, r.z, (r.f - 1) % 4
  end
end
function r.distanceFromSide(...)
  local args = {...}
  local x,y,z, side
  if type(args[1]) == "table" then
    x,y,z, side = args[1][1], args[1][2], args[1][3], args[2]
  else
    x,y,z, side = ...
  end
  local x2,y2,z2,f2 = r.x,r.y,r.z,r.f
  if side then x2,y2,z2,f2 = r.guessPos(side) end
  local dist = abs(x-x2)+abs(y-y2)+abs(z-z2)

  local relX,relY = x-x2, y-y2
  local a = math.pi/2*(-f2)
  local dx = round(relX*math.cos(a) - relY*math.sin(a))
  local dy = round(relX*math.sin(a) + relY*math.cos(a))
  if dx < 0 then dist = dist+2
  elseif dy ~= 0--[[ or dx ~= 0]] then dist = dist+1
  end

  return dist
end

local function turnRight()
  r.f = (r.f + 1) % 4
  return robot.turn(true)
end

local function turnLeft()
  r.f = (r.f - 1) % 4
  return robot.turn(false)
end

local function turnTowards(side)
  if r.f == side - 1 then
    turnRight()
  else
    while r.f ~= side do
      turnLeft()
    end
  end
end


local function clearBlock(side, cannotRetry)
  -- local result, reason = robot.swing(side)
  -- if not result then
  --   local _, what = robot.detect(side)
  --   if cannotRetry and what ~= "air" and what ~= "entity" then
  --     return false
  --   end
  -- end
  -- return true
  return robot.swing(side)
end

local function tryMove(side)
  side = side or sides.forward
  local tries = 5
  while not robot.move(side) do
    tries = tries - 1
    if tries < 0 then return false end
    if not clearBlock(side, tries < 1) then
      return false
    end
  end
  if side == sides.down then
    r.z = r.z - 1
  elseif side == sides.up then
    r.z = r.z + 1
  else
    delta[r.f]()
  end
  return true
end

local function moveTo(tx, ty, tz, backwards)
  local axes = {
    function()
      while r.z > tz do
        tryMove(sides.up)
      end
      while r.z < tz do
        tryMove(sides.down)
      end
    end,
    function()
      if r.y > ty then
        turnTowards(3)
        repeat tryMove() until r.y == ty
      elseif r.y < ty then
        turnTowards(1)
        repeat tryMove() until r.y == ty
      end
    end,
    function()
      if r.x > tx then
        turnTowards(2)
        repeat tryMove() until r.x == tx
      elseif r.x < tx then
        turnTowards(0)
        repeat tryMove() until r.x == tx
      end
    end
  }
  if backwards then
    for axis = 3, 1, -1 do
      axes[axis]()
    end
  else
    for axis = 1, 3 do
      axes[axis]()
    end
  end

  if tx == r.x and ty == r.y and tx == r.y then
    return true
  else
    return false
  end
end

local function turn(i)
  if i % 2 == 1 then
    turnRight()
  else
    turnLeft()
  end
end

r.turnRight = turnRight
r.turnLeft = turnLeft
r.turnTowards = turnTowards
r.clearBlock = clearBlock
r.tryMove = tryMove
r.moveTo = moveTo
r.turn = turn

return r
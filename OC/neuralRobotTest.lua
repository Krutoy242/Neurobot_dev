local component, sides, robot, LSTM, open, abs, fmod, min, max, exp, ceil, log, rnd, arr3d, frmtNumber, getHigherkv, round, O, nnType, nn, wasHere, explored, action_count, actKey, generation, maxEfficiency, savedTimes, successedSwings, sidesSymbols, m_sidesRemake, g_maxActions, m_generationsCount, sweetsPosNormalized, sweetsPos, optFile, opt, smooth, NNCommunication, input, addInput, robotActions, output, clearSidesAction, arrPushLeft, arrPushRight, nn_activate, nn_propagate, sigma, sigma_mid, logic, mathLogic, isSweet, findSweets, init, resetScene, iterateGeneration, saveNetwork, loadOptions, saveOptions, doAction
if collectgarbage then
  package.path = package.path .. ";" .. "..\\?.lua"
  require("outsideFix")
end
component = require("component")
sides = require("sides")
robot = require("robotNavigation")
LSTM = require("synaptic").LSTM
open = io.open
do
  local _obj_0 = math
  abs, fmod, min, max, exp, ceil, log = _obj_0.abs, _obj_0.fmod, _obj_0.min, _obj_0.max, _obj_0.exp, _obj_0.ceil, _obj_0.log
end
rnd = math.random
do
  local _obj_0 = require("utils")
  arr3d, frmtNumber, getHigherkv, round, O = _obj_0.arr3d, _obj_0.frmtNumber, _obj_0.getHigherkv, _obj_0.round, _obj_0.debug
end
nnType = { }
nnType.SYNAPTIC = true
nn = nil
wasHere = nil
explored = nil
action_count = 0
actKey = 2
generation = 1
maxEfficiency = 0
savedTimes = 0
successedSwings = 0
sidesSymbols = {
  "↑",
  "⟱",
  "⟰",
  "↱",
  "↰"
}
m_sidesRemake = {
  sides.forward,
  sides.down,
  sides.up,
  sides.right,
  sides.left
}
g_maxActions = 2000
m_generationsCount = 1000
O.debug_level = 10
sweetsPosNormalized = {
  0,
  0,
  0
}
sweetsPos = {
  0,
  0,
  0
}
optFile = "options.lua"
opt = {
  df = 0.33,
  exploreImportance = 0.25,
  hidden1 = 3,
  hidden2 = 1,
  learning_rate = 0.5
}
smooth = function(v1, v2, d)
  if v1 == nil then
    v1 = 0
  end
  if v2 == nil then
    v2 = 0
  end
  if d == nil then
    d = opt.df
  end
  return v1 * d + v2 * (1 - d)
end
do
  local _class_0
  local cut
  local _base_0 = {
    raw = { },
    descriptions = { },
    old = { },
    usedMap = { },
    indexes = { },
    unusedMap = { },
    add = function(self, name, func, description)
      local count = #description
      if count > 1 then
        rawset(self, name, (function()
          local _accum_0 = { }
          local _len_0 = 1
          for i = 1, count do
            _accum_0[_len_0] = 0
            _len_0 = _len_0 + 1
          end
          return _accum_0
        end)())
      else
        rawset(self, name, 0)
      end
      self.indexes[#self.indexes + 1] = name
      for i = 1, count do
        self.descriptions[#self.descriptions + 1] = description[i]
      end
      local funcResult = nil
      if func then
        local fncStr = "return function(n) return " .. tostring(func) .. " end"
        local err
        funcResult, err = loadstring(fncStr, nil, nil, setmetatable({
          input = self
        }, {
          __index = _G
        }))()
        if not funcResult then
          error(err)
        end
      end
      self.usedMap[name] = funcResult or true
    end,
    normalize = function(self)
      local k = 1
      local _list_0 = self.indexes
      for _index_0 = 1, #_list_0 do
        local key = _list_0[_index_0]
        local v = self[key]
        if type(v) == "table" then
          for i = 1, #v do
            self.raw[k] = cut(v[i])
            k = k + 1
          end
        else
          self.raw[k] = cut(v)
          k = k + 1
        end
      end
      return self.raw
    end,
    getQuality = function(self)
      local quality = 0
      local count = 0
      for k, f in pairs(self.usedMap) do
        local _continue_0 = false
        repeat
          if f == true then
            _continue_0 = true
            break
          end
          local v = self[k]
          if type(v) == "table" then
            for _index_0 = 1, #v do
              local val = v[_index_0]
              quality = quality + f(val)
              count = count + 1
            end
          else
            quality = quality + f(v)
            count = count + 1
          end
          _continue_0 = true
        until true
        if not _continue_0 then
          break
        end
      end
      return min(1, max(0, quality / count))
    end,
    computeThruTimeKey = function(self, key)
      local v = self[key]
      self.old[key] = v
      if key:sub(1, 3) == "tt_" then
        return 
      end
      local tt_key = "tt_" .. key
      if type(v) == "table" then
        self[tt_key] = self[tt_key] or { }
        for i = 1, #v do
          self[tt_key][i] = smooth(self[tt_key][i] or 0, v[i])
        end
      else
        self[tt_key] = smooth(self[tt_key] or 0, v)
      end
    end,
    computeThruTime = function(self)
      for k, _ in pairs(self.usedMap) do
        self:computeThruTimeKey(k)
      end
      for k, _ in pairs(self.unusedMap) do
        self:computeThruTimeKey(k)
      end
    end,
    __newindex = function(self, k, v)
      self.unusedMap[k] = true
      return rawset(self, k, v)
    end
  }
  _base_0.__index = _base_0
  _class_0 = setmetatable({
    __init = function() end,
    __base = _base_0,
    __name = "NNCommunication"
  }, {
    __index = _base_0,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  local self = _class_0
  cut = function(n)
    return n > 1 and 1 or (n < 0 and 0 or n)
  end
  NNCommunication = _class_0
end
input = NNCommunication()
addInput = function(...)
  return input:add(...)
end
addInput("tt_swingSuccesSide", "n", {
  "swing forward",
  "swing down",
  "swing up"
})
addInput("tt_explored", "n/3", {
  "explored forward",
  "explored down",
  "explored up"
})
addInput("tt_closerToSweets", "n*3", {
  "closer to sweets"
})
addInput("wasThere", "1-n", {
  "was there"
})
robotActions = {
  function()
    return robot.tryMove(sides.forward)
  end,
  function()
    return robot.tryMove(sides.down)
  end,
  function()
    return robot.tryMove(sides.up)
  end,
  function()
    return robot.turnRight() and false
  end,
  function()
    return robot.turnLeft() and false
  end
}
output = {
  0,
  0,
  0,
  0,
  0
}
clearSidesAction = {
  function()
    return robot.clearBlock(sides.forward)
  end,
  function()
    return robot.clearBlock(sides.down)
  end,
  function()
    return robot.clearBlock(sides.up)
  end
}
arrPushLeft = function(t)
  local result = {
    [0] = t[1]
  }
  for i = 1, #t - 1 do
    result[i] = t[i + 1]
  end
  return result
end
arrPushRight = function(t)
  local result = { }
  for i = 0, #t do
    result[i + 1] = t[i]
  end
  return result
end
nn_activate = function()
  if nnType.SYNAPTIC_JS then
    return arrPushRight(nn.activate(arrPushLeft(input:normalize())))
  elseif nnType.SYNAPTIC then
    return nn:activate(input.raw)
  end
end
nn_propagate = function(rate)
  if nnType.SYNAPTIC_JS then
    rate = rate or opt.learning_rate
    return nn.propagate(rate, arrPushLeft(output))
  elseif nnType.SYNAPTIC then
    rate = rate or opt.learning_rate
    return nn:propagate(rate, output)
  end
end
sigma = function(x)
  return -2 ^ (-x * 0.1) + 1
end
sigma_mid = function(x)
  return 1 / (1 + exp(-x * 0.1))
end
logic = function(bool)
  return bool and 1 or 0
end
mathLogic = function(v, t)
  return v < t and 1 or (v > t and 0 or .5)
end
isSweet = function(x, y, z)
  local ex = explored(x, y, z)
  if ex and ex >= 1 and not wasHere(x, y, z) then
    if not (explored(x, y, z + 1) and explored(x, y, z - 1) and explored(x, y + 1, z) and explored(x, y - 1, z) and explored(x + 1, y, z) and explored(x - 1, y, z)) then
      return true
    end
  end
end
findSweets = function(_x, _y, _z)
  local l = 30
  local n = l / 2
  for k = 0, 3 * n do
    for x = -min(n - fmod(l + 1, 2), k), min(n, k) do
      for y = -min(n - fmod(l + 1, 2), k - abs(x)), min(n, k - abs(x)) do
        local z = k - abs(x) - abs(y)
        if z <= n then
          if isSweet(x + _x, y + _y, z + _z) then
            return robot.distanceFromSide(x + _x, y + _y, z + _z), x + _x, y + _y, z + _z
          end
          if z ~= 0 and (fmod(l, 2) ~= 0 or z < n) then
            if isSweet(x + _x, y + _y, -z + _z) then
              return robot.distanceFromSide(x + _x, y + _y, -z + _z), x + _x, y + _y, -z + _z
            end
          end
        end
      end
    end
  end
  return robot.distanceFromSide(0, 0, 0), 0, 0, 0
end
init = function()
  resetScene()
  component.robot.setLightColor(0x446688)
  for i = 1, m_generationsCount do
    iterateGeneration()
  end
  if O.Level_Full then
    return O("total saved:: ", savedTimes, "maxEfficiency: ", maxEfficiency, "\n")
  end
end
resetScene = function(newOpts)
  opt = newOpts or opt
  math.randomseed(os.time())
  if DEBUG then
    DEBUG.RemakeWorld(7)
  end
  wasHere = arr3d()
  explored = arr3d()
  action_count = 0
  successedSwings = 0
  robot.x = 0
  robot.y = 0
  robot.z = 0
  robot.f = 0
  local numberOfImputs = #(input:normalize())
  local numberOfOutputs = #robotActions
  local numberOfHidden = ceil(numberOfImputs * 0.4)
  if nnType.SYNAPTIC then
    if not nn then
      local opts = {
        numberOfOutputs
      }
      if opt.hidden1 > 0 then
        table.insert(opts, 1, opt.hidden1)
      end
      if opt.hidden2 > 0 then
        table.insert(opts, 1, opt.hidden2)
      end
      nn = LSTM.new(numberOfImputs, table.unpack(opts))
    else
      nn:clear()
    end
    if O.Level_Important then
      return O("Inputs: " .. tostring(numberOfImputs), " Hidden:" .. tostring(opt.hidden1) .. " " .. tostring(opt.hidden2) .. ", Outputs: " .. tostring(numberOfOutputs) .. "\n")
    end
  end
end
iterateGeneration = function()
  while doAction() do
    local _ = _
  end
  saveNetwork()
  resetScene()
  generation = generation + 1
end
saveNetwork = function()
  local new_efficiency = successedSwings / action_count / (BLOCKDENSITY or 1)
  if O.Level_Important then
    O(("[%d/%d] new_efficiency:%-6.4f maxEfficiency:%-6.4f\n"):format(action_count, successedSwings, new_efficiency, maxEfficiency))
  end
  if DEBUG then
    if new_efficiency > maxEfficiency then
      maxEfficiency = new_efficiency
    end
  end
end
loadOptions = function()
  local f = io.open(optFile, "r")
  if f ~= nil then
    io.close(f)
    for k, v in pairs(dofile(optFile)) do
      opt[k] = v
    end
  end
end
saveOptions = function()
  local s = ""
  for k, v in pairs(opt) do
    s = s .. k .. " = " .. tostring(v) .. ",\n"
  end
  do
    local _with_0 = open(optFile, "w")
    _with_0:write("return {\n" .. s .. "}")
    _with_0:close()
    return _with_0
  end
end
doAction = function()
  if action_count >= g_maxActions then
    return false
  end
  do
    if action_count == 0 then
      do
        input:normalize()
      end
    end
    output = nn_activate()
    local actVal, secondKey
    actKey, actVal, secondKey = getHigherkv(output)
    local moveSucces = logic(robotActions[actKey]())
    local swingSucces = 0
    local swingedSide = {
      0,
      0,
      0
    }
    local exploreSucces = 0
    local exploreSide = {
      0,
      0,
      0
    }
    local neighboors = {
      {
        robot.lookTo()
      },
      {
        robot.x,
        robot.y,
        robot.z - 1
      },
      {
        robot.x,
        robot.y,
        robot.z + 1
      }
    }
    for i = 1, #clearSidesAction do
      local sr = logic(clearSidesAction[i]())
      swingSucces = swingSucces + sr
      swingedSide[i] = sr
      local _x, _y, _z = unpack(neighboors[i])
      exploreSide[i] = logic(not explored(_x, _y, _z))
      exploreSucces = exploreSucces + (exploreSide[i] / 3)
      explored:define(_x, _y, _z, sr)
    end
    if swingSucces > 0 or not isSweet(table.unpack(sweetsPos)) then
      local toSweets, s_x, s_y, s_z = findSweets(robot.x, robot.y, robot.z)
      sweetsPos = {
        s_x,
        s_y,
        s_z
      }
      sweetsPosNormalized = {
        sigma_mid(s_x),
        sigma_mid(s_y),
        sigma_mid(s_z)
      }
    end
    local distToSweetsBlocks = robot.distanceFromSide(sweetsPos)
    local distToSweets = sigma(distToSweetsBlocks)
    local isCloserToSweets = swingSucces > 0 and 1 or (mathLogic(distToSweets, (input.old.distToSweets or 0)) ^ 2)
    input.moveSucces = moveSucces
    input.swingSuccesSide = swingedSide
    input.swingSucces = swingSucces / 3
    input.lookTowards = robot.binaryDirection[robot.f]
    input.pos = {
      sigma_mid(robot.x),
      sigma_mid(robot.y),
      sigma_mid(robot.z)
    }
    input.exploreSucces = exploreSucces
    input.lastAction = input.lastAction or { }
    input.lookDirection = {
      0,
      0,
      0,
      0
    }
    input.lookDirection[robot.f + 1] = 1
    input.wasThere = logic(wasHere(robot.x, robot.y, robot.z))
    input.explored = exploreSide
    input.sweetsPos = sweetsPosNormalized
    do
      local _accum_0 = { }
      local _len_0 = 1
      for i = 1, #sweetsPos do
        _accum_0[_len_0] = sigma_mid(({
          robot.x,
          robot.y,
          robot.z
        })[i] - sweetsPos[i])
        _len_0 = _len_0 + 1
      end
      input.sweetsRelativePos = _accum_0
    end
    input.distToSweets = distToSweets
    input.closerToSweets = isCloserToSweets
    for i = 1, 5 do
      input.lastAction[i] = logic(i == actKey)
    end
    input:computeThruTime()
    input:normalize()
    wasHere:set(robot.x, robot.y, robot.z, true)
    successedSwings = successedSwings + swingSucces
    action_count = action_count + 1
    if O.Level_Full then
      local s = string.format("kpd: %4d/%-4d", action_count, successedSwings)
      local _list_0 = input.raw
      for _index_0 = 1, #_list_0 do
        local i = _list_0[_index_0]
        s = s .. frmtNumber(i, 1)
      end
      for i = 1, #output do
        s = s .. ((i == actKey and "[" or " ") .. sidesSymbols[i] .. frmtNumber(output[i]) .. (i == actKey and "]" or " "))
      end
      s = s .. string.format(" x%-3d y%-3d z%-3d f%d", robot.x, robot.y, robot.z, robot.f)
      O(s)
    end
    local val = input:getQuality()
    local optimalSide = 0
    for i = 1, #output do
      if sigma(robot.distanceFromSide(sweetsPos, m_sidesRemake[i])) < input.distToSweets then
        optimalSide = i
      end
    end
    local oppositeKey = ({
      0,
      3,
      2,
      5,
      4
    })[actKey]
    local rndKey = actKey
    while rndKey == actKey or rndKey == oppositeKey do
      rndKey = ceil(rnd(5))
    end
    local valz = 1 - val
    for i = #output, 1, -1 do
      local targ
      local _exp_0 = i
      if actKey == _exp_0 then
        targ = val
      elseif optimalSide == _exp_0 then
        targ = valz
      elseif oppositeKey == _exp_0 then
        targ = output[i] / 2
      else
        targ = 0
      end
      output[i] = targ
    end
    nn_propagate()
    if O.Level_Full then
      O(" Q=" .. frmtNumber(val, 10), " optSide:", optimalSide, " ")
      for _index_0 = 1, #output do
        local i = output[_index_0]
        O(" ", frmtNumber(i, 3))
      end
      O("\n")
    end
  end
  return true
end
loadOptions()
if not love then
  init()
end
return {
  doAction = doAction,
  saveNetwork = saveNetwork,
  resetScene = resetScene,
  nnType = nnType,
  input = input,
  sidesSymbols = sidesSymbols,
  opt = opt,
  saveOptions = saveOptions,
  loadOptions = loadOptions,
  getnn = function()
    return nn
  end
}

-- Moonscript define
local *

--===========================================================
-- Variables
--===========================================================
-- Outside MC fix
if collectgarbage
  package.path = package.path..";".."..\\?.lua"
  require"outsideFix" 

component= require"component"
--luaneural= require"luaneural"
sides    = require"sides"
robot    = require"robotNavigation"
import LSTM from require"synaptic"
import open from io
import abs,fmod,min,max,exp,ceil,log from math
rnd = math.random

-- Local imports
{:arr3d, :frmtNumber, :getHigherkv, :round, debug:O} = require"utils"

nnType = {}
--nnType.SYNAPTIC_JS = true
nnType.SYNAPTIC = true

nn                 = nil -- Main Network Table
wasHere            = nil-- 3d Array with true/nil values represents if turtle was there
explored           = nil-- 3d Array with true/nil values represents if turtle was there
action_count       = 0
actKey             = 2
generation         = 1
maxEfficiency      = 0
savedTimes         = 0
successedSwings    = 0
sidesSymbols       = {"↑","⟱","⟰","↱","↰"}
m_sidesRemake      = {sides.forward, sides.down, sides.up, sides.right, sides.left}
g_maxActions       = 2000
m_generationsCount = 1000
O.debug_level      = 10
sweetsPosNormalized= {0,0,0}
sweetsPos          = {0,0,0}
optFile            = "options.lua"

opt = {
  df: 0.33
  exploreImportance: 0.25
  hidden1: 3
  hidden2: 1
  learning_rate: 0.5
}

smooth = (v1=0, v2=0, d=opt.df)-> v1*d + v2*(1-d)

--  ___  _   _  ____   _   _  _____ 
-- |_ _|| \ | ||  _ \ | | | ||_   _|
--  | | |  \| || |_) || | | |  | |  
--  | | | |\  ||  __/ | |_| |  | |  
-- |___||_| \_||_|     \___/   |_|  
-- 
class NNCommunication
  raw:         {}
  descriptions:{} -- Descr. of raw fields
  old:         {}
  usedMap:     {} -- Keys of using values
  indexes:     {} -- All used keys in Array
  unusedMap:   {} -- Keys that not using as result
  cut = (n)-> n>1 and 1 or (n<0 and 0 or n)

  add: (name, func, description)=>
    count = #description
    if count > 1
      rawset(@, name, for i=1,count do 0)
    else 
      rawset(@, name, 0)
    @indexes[#@indexes + 1] = name
    for i=1, count
      @descriptions[#@descriptions+1] = description[i]

    funcResult = nil
    if func then
      fncStr = "return function(n) return #{func} end"
      funcResult, err = loadstring(fncStr, nil, nil, setmetatable({input:@}, {__index:_G}))()
      if not funcResult then error(err)
    @usedMap[name] = funcResult or true

  normalize: ()=>
    k=1
    for key in *@indexes
      v = @[key]
      if type(v) == "table" then
        for i=1,#v
          @raw[k] = cut v[i]
          k+=1
      else
        @raw[k] = cut v
        k+=1
    @raw

  getQuality: ()=>
    quality = 0
    count=0
    for k,f in pairs @usedMap
      continue if f==true
      v = @[k]
      if type(v) == "table" then
        for val in *v
          quality += f(val) 
          count+=1
      else
        quality += f(v)
        count+=1
    min(1, max(0, quality/count))

  computeThruTimeKey: (key)=>
    v = @[key]
    @old[key] = v

    if key\sub(1,3) == "tt_" then return
    tt_key = "tt_"..key
    if type(v) == "table"
      @[tt_key] or= {}
      @[tt_key][i] = smooth(@[tt_key][i] or 0, v[i]) for i=1, #v
    else 
      @[tt_key]    = smooth(@[tt_key]    or 0, v   )

  computeThruTime: ()=>
    @computeThruTimeKey(k) for k,_ in pairs @usedMap
    @computeThruTimeKey(k) for k,_ in pairs @unusedMap

  __newindex: (k,v)=>
    @unusedMap[k] = true
    rawset(@,k,v)

input = NNCommunication()
addInput = (...)-> input\add(...)

--addInput "pos",                nil  ,{"pos x","pos y","pos z"}
addInput "tt_swingSuccesSide", "n"  ,{"swing forward", "swing down", "swing up"}
addInput "tt_explored",        "n/3",{"explored forward","explored down","explored up"}
addInput "tt_closerToSweets",  "n*3",{"closer to sweets"}
addInput "wasThere",           "1-n", {"was there",}
--addInput "tt_exploreSucces",   "n"  ,{"explore succes"}
--addInput "lookDirection",  "0", {"look ↑","look →","look ↓","look ←"}
--addInput "sweetsPos",      "0", {"sweet x","sweet y","sweet z"}
--addInput "sweetsRelativePos",      nil, {"sweet x","sweet y","sweet z"}
--addInput "distToSweets",   "0", {"distance to sweets"}
--addInput "lookTowards",    "0", {"look ↗","look ↖",}
--addInput "lastAction",     nil, sidesSymbols



robotActions = {
  -> robot.tryMove(sides.forward)
  -> robot.tryMove(sides.down)
  -> robot.tryMove(sides.up)
  -> robot.turnRight() and false
  -> robot.turnLeft() and false
}
output     = {0,0,0,0,0}

clearSidesAction = {
  -> robot.clearBlock(sides.forward)
  -> robot.clearBlock(sides.down)
  -> robot.clearBlock(sides.up)
}

arrPushLeft  = (t)->
  result = {[0]:t[1]}
  for i=1,#t-1 do result[i] = t[i+1]
  return result
arrPushRight = (t)-> 
  result = {}
  for i=0,#t do result[i+1] = t[i]
  return result

nn_activate = ->
  if nnType.SYNAPTIC_JS
    return arrPushRight nn.activate( arrPushLeft input\normalize! ) 
  elseif nnType.SYNAPTIC
    return nn\activate(input.raw) 
nn_propagate = (rate)->
  if nnType.SYNAPTIC_JS
    rate = rate or opt.learning_rate
    nn.propagate( rate, arrPushLeft output) 
  elseif nnType.SYNAPTIC
    rate = rate or opt.learning_rate
    nn\propagate( rate, output)

sigma     = (x)-> -2^(-x*0.1)+1
--inv_sigma = (x)-> -log(1 - x)/log(2)
sigma_mid = (x)-> 1 / (1 + exp(-x*0.1))
logic     = (bool)-> bool and 1 or 0
mathLogic = (v,t)-> v<t and 1 or (v>t and 0 or .5) 


isSweet = (x,y,z)->
  ex = explored(x,y,z)
  --print(x,y,z, ex)
  if ex and ex>=1 and not wasHere(x,y,z)
    if not (explored(x,y,z+1) and
            explored(x,y,z-1) and
            explored(x,y+1,z) and
            explored(x,y-1,z) and
            explored(x+1,y,z) and
            explored(x-1,y,z))  --Check if we was on point above
      return true

findSweets = (_x,_y,_z)->
  l = 30
  n = l/2   --integer division
  for k = 0, 3*n
    for x = -min(n - fmod(l+1, 2), k), min(n, k)
      for y = -min(n - fmod(l+1, 2), k - abs(x)), min(n, k - abs(x))
        z = k - abs(x) - abs(y)
        if z <= n
          if isSweet(x+_x,y+_y,z+_z)
            return robot.distanceFromSide(x+_x,y+_y,z+_z) ,x+_x,y+_y,z+_z
          if z ~= 0 and (fmod(l, 2) ~= 0 or z < n)
            if isSweet(x+_x,y+_y,-z+_z)
              return robot.distanceFromSide(x+_x,y+_y,-z+_z) ,x+_x,y+_y,-z+_z
  return robot.distanceFromSide(0,0,0),0,0,0 -- if we lost return start point


--===========================================================
-- Init
--===========================================================
init = ->
  resetScene!

  component.robot.setLightColor(0x446688) 

  for i=1, m_generationsCount
    iterateGeneration!

  if O.Level_Full
    O "total saved:: ",savedTimes, "maxEfficiency: ", maxEfficiency, "\n"

--===========================================================
-- Loop
--===========================================================
resetScene = (newOpts)->
  opt = newOpts or opt

  math.randomseed(os.time!)

  -- Make new World
  if DEBUG
    DEBUG.RemakeWorld(7)


  wasHere         = arr3d!
  explored        = arr3d!
  action_count    = 0
  successedSwings = 0
  robot.x         = 0
  robot.y         = 0
  robot.z         = 0
  robot.f         = 0
  numberOfImputs  = #(input\normalize!)
  numberOfOutputs = #robotActions
  numberOfHidden  = ceil(numberOfImputs*0.4)

  -- if nnType.SYNAPTIC_JS
  --   if not nn then nn = require(nn_fileName)! -- Load neural
  --   package.loaded[nn_fileName] = nil -- Remove neural to load it again next time
  --   if O.Level_Important then 
  --     O "Inputs: #{#(input\normalize!)}", " Hidden: ", "???", " Outputs: ", 5, "\n"

  if nnType.SYNAPTIC
    if not nn
      opts = {numberOfOutputs}
      table.insert(opts, 1, opt.hidden1) if opt.hidden1>0
      table.insert(opts, 1, opt.hidden2) if opt.hidden2>0
      nn = LSTM.new(numberOfImputs, table.unpack(opts)) -- Load neural
    else 
      nn\clear!

    if O.Level_Important then 
      O "Inputs: #{numberOfImputs}", " Hidden:#{opt.hidden1} #{opt.hidden2}, Outputs: #{numberOfOutputs}\n"

  --   nnFile = open(nn_fileName,"r")
  --   if nnFile
  --     nn\ownership loadstring(nnFile\read!)!
  --     nnFile\close!

  -- if DEBUG
  --   configLoaded = pcall dofile, "config.lua"-- Load neuralnet maximum effiency
  --   maxEfficiency = LOADED_NN_EFFICIENCY or 0

  --   if O.Level_Important
  --     O "config LOADED with efficiency: ", string.sub(LOADED_NN_EFFICIENCY, 1, 6), "\n" if configLoaded

iterateGeneration = ->
  while doAction!
    _

  saveNetwork!
  resetScene!

  generation += 1
    
saveNetwork = ->
  -- Write file if maxEfficiency is better
  new_efficiency = successedSwings/action_count/(BLOCKDENSITY or 1)

  if O.Level_Important
    O ("[%d/%d] new_efficiency:%-6.4f maxEfficiency:%-6.4f\n")\format action_count, successedSwings, new_efficiency, maxEfficiency

  if DEBUG

    if new_efficiency > maxEfficiency 
      maxEfficiency = new_efficiency

      -- if new_efficiency > 0.01
      --   -- if nnType.SYNAPTIC_JS
      --   --   f = io.open nn_fileName, "w"
      --   --   if f 
      --   --     f\write("return {[0]="..nn.memory[0]..","..table.concat(nn.memory,",").."}")
      --   --     f\close!
      --   --   if O.Level_Important then O "NETWORK SAVED\n"

      --     -- Save config
      --   with open "config.lua", "w" 
      --     \write "LOADED_NN_EFFICIENCY = "..maxEfficiency..
      --            "\nTOTAL_PROPAGATIONS = "..((TOTAL_PROPAGATIONS or 0) + action_count)..
      --            "\nlocal kpd = #{action_count}/#{successedSwings}"
      --     \close! 

loadOptions = ->
  f=io.open(optFile,"r")
  if f~=nil then
    io.close(f)
    for k,v in pairs dofile(optFile)
      opt[k] = v
saveOptions = ->
  s = ""
  for k,v in pairs opt do s = s .. k .. " = " .. tostring(v) ..",\n"
  with open optFile, "w" 
    \write "return {\n"..s.."}"
    \close! 


------------------------------------------
-- Called every action                  --
------------------------------------------
doAction = ->
  -- Return
  if action_count >= g_maxActions return false

  with robot 

    --______________________________--
    --##   Collect and use input  ##--

    --## Call the result ##--
    if action_count==0 do input\normalize!
    output = nn_activate!

    -- Determine higher value
    actKey, actVal, secondKey = getHigherkv(output)--getHigherkv(for i=1,3 do output[i])

    -- Do move or turn
    --  ,+---+
    -- +---+'|
    -- |^_^| +
    -- +---+' 
    -- 
    moveSucces = logic(robotActions[actKey]!) -- <<<<

    -- Try to swing
    swingSucces   = 0
    swingedSide   = {0,0,0}
    exploreSucces = 0
    exploreSide   = {0,0,0}
    neighboors = {{.lookTo!}, {.x, .y, .z-1}, {.x, .y, .z+1}}
    for i=1, #clearSidesAction
      sr = logic(clearSidesAction[i]!) -- <<<<
      swingSucces   += sr
      swingedSide[i] = sr-- Succesful swing

      _x,_y,_z = unpack(neighboors[i])
      exploreSide[i] = logic( not explored(_x,_y,_z))
      exploreSucces += exploreSide[i]/3
      explored\define(_x,_y,_z, sr)

    if swingSucces>0 or not isSweet(table.unpack sweetsPos)
      toSweets, s_x,s_y,s_z = findSweets(.x,.y,.z)
      sweetsPos             = {s_x,s_y,s_z}
      sweetsPosNormalized   = {sigma_mid(s_x), sigma_mid(s_y), sigma_mid(s_z)}
    distToSweetsBlocks = .distanceFromSide(sweetsPos)
    distToSweets = sigma(distToSweetsBlocks)
    isCloserToSweets = swingSucces>0 and 1 or (mathLogic(distToSweets, (input.old.distToSweets or 0))^2)
    

    --______________________________--
    --##   Write information      ##--
    input.moveSucces         = moveSucces
    input.swingSuccesSide    = swingedSide
    input.swingSucces        = swingSucces/3
    input.lookTowards        = .binaryDirection[.f]
    input.pos                = {sigma_mid(.x), sigma_mid(.y), sigma_mid(.z)}
    input.exploreSucces      = exploreSucces
    input.lastAction       or= {}
    input.lookDirection      = {0,0,0,0}
    input.lookDirection[.f+1]= 1
    input.wasThere           = logic(wasHere(.x, .y, .z))
    input.explored           = exploreSide
    input.sweetsPos          = sweetsPosNormalized
    input.sweetsRelativePos  = [sigma_mid(({.x, .y, .z})[i] - sweetsPos[i]) for i=1, #sweetsPos]
    input.distToSweets       = distToSweets
    input.closerToSweets     = isCloserToSweets

    for i=1,5 do input.lastAction[i] = logic(i==actKey)

    input\computeThruTime!
    input\normalize!
    
    --print(string.format "isCloserToSweets: %d tt_closer: %1.3f |distToSweets: %.3f |oldDist: %.3f", isCloserToSweets, input.tt_closerToSweets, distToSweets, input.old.distToSweets)

    --##############################--
    --______________________________--


    wasHere\set(.x, .y, .z, true) -- Mark position before moving
    successedSwings          += swingSucces
    action_count             += 1


    -- Write gathered information
    if O.Level_Full
      s = string.format "kpd: %4d/%-4d", action_count, successedSwings
      s ..= frmtNumber(i,1) for i in *input.raw
      for i=1, #output
        s ..= (i==actKey and "[" or " ") .. sidesSymbols[i].. frmtNumber(output[i]).. (i==actKey and "]" or " ")
      s ..= string.format " x%-3d y%-3d z%-3d f%d", .x, .y, .z, .f
      O s

    --______________________________--
    --##  Collect and use output  ##--
    val = input\getQuality()

    optimalSide = 0
    --print " "
    for i=1, #output
      -- print string.format "Sweets pos [%d,%d,%d], side:%d, distBlocks:%d distNew:%1.3f distOld:%1.3f", 
      --   sweetsPos[1], sweetsPos[2], sweetsPos[3], m_sidesRemake[i], .distanceFromSide(sweetsPos, m_sidesRemake[i]), sigma(.distanceFromSide(sweetsPos, m_sidesRemake[i])), input.distToSweets
      if sigma(.distanceFromSide(sweetsPos, m_sidesRemake[i])) < input.distToSweets
        optimalSide = i
    oppositeKey = ({0, 3, 2, 5, 4})[actKey]
    rndKey = actKey
    while rndKey==actKey or rndKey==oppositeKey do rndKey=ceil(rnd(5))
    valz = 1-val
    for i=#output, 1, -1 do
      targ = switch i
        when actKey
          val
        -- when lastKey
        --   input.succes < (input.old.succes or 0) and val/2 or val
        when optimalSide
          valz
        when oppositeKey
          --val/2
          output[i]/2
        -- when secondKey
        --   valz/2
        -- when rndKey
        --   -- ((valz+1)^2)/4
        --   valz
        else
          0
      output[i] = targ
    nn_propagate!

    if O.Level_Full then 
      O " Q=" .. frmtNumber(val, 10)," optSide:", optimalSide, " "
      for i in *output do O " ", frmtNumber(i,3)
      O "\n"

  true -- return

------------------------------------------
-- Main Function                        --
------------------------------------------
loadOptions!
if not love then init!

{
  :doAction
  :saveNetwork
  :resetScene
  :nnType
  :input
  :sidesSymbols
  :opt
  :saveOptions
  :loadOptions
  getnn:-> nn
}
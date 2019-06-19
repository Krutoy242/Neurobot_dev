-- https://upload.wikimedia.org/wikipedia/commons/5/53/Peephole_Long_Short-Term_Memory.svg

-- Teens
local flux = require"flux"
local vec  = require"vector"
local MO   = require"mo"
local HSL  = require"colorFactory".HSL


-- Redefine globals
local love = love
local gfx  = love.graphics
local sqrt = math.sqrt
local pi   = math.pi
local abs  = math.abs
local log  = math.log
local pi2  = pi/2


-- Return
local synapticRenderer = {
  infoAmount = 5 -- Density of information on screen
}

-- Options
local opt

-- Stored objects
local hud


--===========================================================
-- Private functions
--===========================================================
local function info(level)
  return level <= synapticRenderer.infoAmount
end

local function vecFromCenter(a, len)
  return vec(1, 0):rotateInplace(a)*len/2 + vec(.5,.5)
end

local h,s,l = .58, .55, .5
local connectedNeurons = 0

local function addConnection(from, to, conn)
  local len = sqrt((from.X-to.X)^2 + (from.Y-to.Y)^2) / 1200 +.2
  --local delay = #(from.root.connections.shapes or {})/40+3
  local delay = connectedNeurons/4
  flux.to(from, .5, {a=1}):delay(delay/5)

  local gater = conn.gater and from.root.all["#"..conn.gater.ID] or nil
  from.root.connections:addShape{
    type = "clothesline", from=from, to=to, gater=gater,
    {"width", conn, "weight"}, endpoint=0, widthMult=2, mass=-.2,
    tweens={{time=len/2,  delay=delay, values={endpoint=1}},
            {time=len,    delay=delay, values={mass=1}, ease="quadinout"},
            {time=len*10, delay=delay, values={widthMult=1}}
           }}

  flux.to(from.root.all["#"..conn.to.ID], .1,{a=1}):ease("quadin"):delay(delay+len/2-3)
end

local function storeNeuron(mo, label, neuron)
  mo:square()

  if mo.W < opt.minSize then opt.minSize = mo.W end

  local v1 = vec(0,-.3):rotateInplace(-pi/5) + vec(.5,.5)

  local influence = {0, a=0, r=0}
  mo:addShape{type = "radGrad", color=HSL(h-.03,.9,l), blend="add",
    {"r", influence, "r"},
    {"a", influence, "a"}}

  mo:addStaticShape{type = "disk",   color={0, 0, 0,.6},  r=0.66}
    :addStaticShape{type = "circle", color=HSL(h,s,l,.8), r=.55, width=.05}

    :addShape{type="disk", r=.45, {"color", neuron, "activation"}}

    :addShape{type="arc",  r=.6, spin=-pi*2,
      color=HSL(.54,.75,.5,.8), width=.1,
      tween={time=3, values={spin=0},ease="quartout"},
      {"state", neuron, "bias"}}
    :addShape{type="arc", r=.6, width=.08, color=HSL(h,s,l,.4), a1=-pi*1/5, a2=pi*1/5,
      tween={a1=pi*3/5, a2=pi*6/5}}

  if label then
    local delay = mo:getShapeDelay()
    mo:addShape{type="text", color=HSL(h,0,0,.6), x=0, y=.5, txt=label:gsub("[^\n]","█")}
    mo:addShape{type="text", color=HSL(h,s,1,.8), x=0, y=.5, txt=label                  }
  end

  local gatedDelay = mo:getShapeDelay()+1
  local drawN1 = function(list, spin, col)
    -- Check if we have projected neurons
    local isDrawn1 = false
    local isDrawn2 = false
    local delay
    local connCount = 0
    local a = pi2*.8
    for _,conn in pairs(list) do
      if not isDrawn1 then
        isDrawn1 = true
        delay = mo:getShapeDelay()
        mo:addShape{type="arc", r=.65, width=.02, color=col, spin=spin,
            a1=a, a2=-a, tween={values={a2=-a/8}, delay=delay}}
          :extendShape{a2=a, a1=-a, tween={values={a1=-a/8}, delay=delay}}
        delay = mo:getShapeDelay()
        mo:extendShape{a2=a/2, a1=-a/2, tween={values={a1=-a/8}, delay=delay}, r=.7}
          :extendShape{a1=a/2, a2=-a/2, tween={values={a2=-a/8}, delay=delay}}
      end
      if conn.gater and not isDrawn2 then
        isDrawn2=true
        mo:addShape{type="arc", r=.95, width=.12, color=HSL(h,s,l, .1), spin=spin,
            a1=pi2/2, a2=-pi2/2,
            tween={values={a1=pi2/2, a2=pi2/2},time=2, ease="quartinout", delay=gatedDelay}}
          :extendShape{a2=0, a1=.1, color=HSL(h,s,.9,.9), spin=spin-pi2/2,
            tween={values={spin=spin+pi2/2},   time=2, ease="quartinout", delay=gatedDelay}}
      end
      connCount = connCount + 1
    end

    delay = mo:getShapeDelay()
    for i=1, connCount do
      local v2 = vecFromCenter(-pi2/2 + pi2*(i-.5)/connCount + spin, .9)
      local v3 = vecFromCenter(-pi2/2 + pi2*(i-.5)/connCount + spin,   1)
      mo:addShape{type="line", width=.02, color=HSL(h,s+.2,.7,.2),
        x = v2.x, y = v2.y, x2 = v2.x, y2 = v2.y,
        tween={time = .3, values={x2 = v3.x, y2 = v3.y},
               delay=delay+i/connCount/2}, ease="elasticout"}
    end
    mo.delay = delay
  end

  drawN1(neuron.connections.inputs,   pi, HSL(h+.015,s,l))
  drawN1(neuron.connections.projected, 0, HSL(h-.1 ,s,l))

  mo
    :addShape{type = "disk",   color=HSL(h,.01,.01,1), r=.05, R=10, x=v1.x, y=v1.y}
    :addShape{type = "text",   color=HSL(h,s,l,.8), x=-v1.x+.15, y=v1.y, txt=neuron.ID}
    :addShape{type="arc", r=.08, R=10, width=.02,  color=HSL(h,s,l,.8),
      a1=0, a2=0, x=v1.x, y=v1.y, spin=-pi*.75, tween={a1=pi*.7, a2=pi*.7}}


  -- ERROR responsibility
  local anchorHandlers = {"responsibility", "projected", "gated"}
  for i=1,3 do
    local angle = i*-pi2*.5 - pi2*.5
    local v4 = v1 + vec(1,0):rotateInplace(angle)*.15

    mo:addShape{type = "triangle",   color=HSL(.000,s,l-.4), x=v4.x, y=v4.y, r=.07, spin=angle,
                 {"a:abs:pow(.2)", neuron.error, anchorHandlers[i]}}
  end


  -- Store connections
  mo:addCallback("onInit", function()
    mo.a = 0
    local m = 0
    --mo:resizeG((opt.minSize*2+mo.W)/3, (opt.minSize*2+mo.H)/3)
    for _,projec in pairs(neuron.connections.projected) do
      addConnection(mo, mo.root.all["#"..projec.to.ID], projec)
      m=m+1
    end
    if neuron.selfconnection.weight>0 then
      addConnection(mo, mo, neuron.selfconnection)
      m=m+1
    end
    if m>5 then connectedNeurons = connectedNeurons+1 end
  end)

  -- Flare when we have strong connections
  mo:addCallback("onUpdate", function()
    influence[1] = 0
    for _,projec in pairs(neuron.connections.projected) do
      influence[1] = influence[1] + abs(projec.weight)
    end
    influence.r = -2 ^ (-influence[1] * 0.005) + 2
    influence.a = -2 ^ (-influence[1] * 0.01) + 1
  end)


  return mo
end

local function storeLayer(mo, label, list, output, forget, input)

  local description, stack = mo:splitVertical(.04)
  description:addShape{type="text", font=3, color=HSL(h,s,l,1), x=0, txt=mo.name:upper()}

  local v1 = vec(0,-.5):rotateInplace(pi2/3)*.98 + vec(.5,.5)/2
  local v2 = vec(0, .5):rotateInplace(pi2/3)*.98 + vec(.5,.5)/2
  local v3 = vecFromCenter(pi2*.75, .8)

  local rows = #list
  for n=1, rows do
    local y = (n-1)/(rows)

    if not output then
      local nlabel = type(label)=="table" and label[n] or label
      storeNeuron(stack:add("#"..list[n].ID, 0, y, 1, 1/rows), nlabel:gsub(" ","\n"), list[n])
    else
      local peephole = stack:add(0, y, 1, 1/rows):square()
      peephole:addCallback("onInit", function(self)
          self:resizeG((opt.minSize+self.W)/2, (opt.minSize+self.H)/2)
        end)
      storeNeuron(peephole:add("#"..list[n].ID, .75, .75):center(), "memory\ngate", list[n])

        flux.to(
      storeNeuron(peephole:add("#"..output[n].ID, .5, .5 ):center(), "output\ngate", output[n])
        , 1, {x=v1.x, y=v1.y}):ease("backinout"):delay(n/3)

      storeNeuron(peephole:add("#"..forget[n].ID, .35,.35):center(v3.x, v3.y),  "forget\ngate", forget[n])

        flux.to(
      storeNeuron(peephole:add("#".. input[n].ID, .5, .5 ):center(), "input\ngate", input[n] )
        , 1, {x=v2.x, y=v2.y}):ease("backinout"):delay(n/3)
    end
  end
end

--===========================================================
-- Public functions
--===========================================================
function synapticRenderer.init(options)
  opt = options
  opt.minSize = 200
  connectedNeurons = 0
  hud = MO(opt)
  hud:add("connections")

  -- Store LSTM
  local hidden         = options.nn.layers.hidden
  local totalHidden    = #hidden
  local totalSublayers = totalHidden/4
  local sliceW         = 1/(totalSublayers+2)

  -- Store input
  storeLayer(hud:add("input", sliceW, 1), options.tInput, options.nn.layers.input.list)
  local hiddenSector = hud:add("hidden", sliceW, 0 , sliceW*totalSublayers, 1)
  for i=0, totalSublayers-1 do
    -- local x = ceil(((l-1)/4+1)/(totalSublayers+1))

    local peepholeLyer = hiddenSector:add("LSTM peepholes #"..(i+1), (i)/totalSublayers, 0, 1/totalSublayers, 1)
    storeLayer(peepholeLyer, nil,
      hidden[i*4+1+2].list,
      hidden[i*4+1+3].list,
      hidden[i*4+1+1].list,
      hidden[i*4+1].list)
  end
  storeLayer(hud:add("output", sliceW*(totalSublayers+1),0,sliceW, 1)
             , options.tOutput, options.nn.layers.output.list)

  return hud
end

function synapticRenderer.draw()
  flux.update(love.timer.getDelta())

  --opt.glow(function()
  hud:update()
  --end)
end



return synapticRenderer
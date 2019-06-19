-- local assert = assert
-- local sqrt, cos, sin, atan2 = math.sqrt, math.cos, math.sin, math.atan2

local abs   = math.abs
local ceil  = math.ceil
local floor = math.floor
local log   = math.log
local max   = math.max
local min   = math.min
local pi    = math.pi
local sqrt  = math.sqrt

local gfx   = love.graphics
local vec   = require"vector"
local flux  = require"flux"

local utf8       = require"utf8"
local utf8len    = utf8.len
local utf8offset = utf8.offset

local utils    = require"utils"
local round    = utils.round
local deepCopy = utils.deepCopy

local fonts = {
  gfx.newFont("FixedsysExcelsior.ttf", 10),
  gfx.newFont("FixedsysExcelsior.ttf", 14),
  gfx.newFont("FixedsysExcelsior.ttf", 20)
}

local radialGradient
--  _   _ _   _ _
-- | | | | |_(_) |___
-- | | | | __| | / __|
-- | |_| | |_| | \__ \
--  \___/ \__|_|_|___/
local sigma = function(x)
  return -2 ^ (-x * 0.1) + 1
end

local function sub_utf8(s,i,j)
    i=utf8offset(s,i)
    j=utf8offset(s,j+1)-1
    return string.sub(s,i,j)
end

--  ____  _
-- / ___|| |__   __ _ _ __   ___  ___
-- \___ \| '_ \ / _` | '_ \ / _ \/ __|
--  ___) | | | | (_| | |_) |  __/\__ \
-- |____/|_| |_|\__,_| .__/ \___||___/
--                   |_|
local function loadPlyAsMesh(filename)
  local f = io.open(filename, "r")
  local s = f:read("*a")
  f:close()

  local verts = {}
  s = s:match("end_header(.*)")
  for x,y,r,g,b,a in s:gmatch("(%S+) (%S+) %S+ (%d+) (%d+) (%d+) (%d+)") do
    verts[#verts+1] = {
      tonumber(x),
      tonumber(y),0,0,
      r/255,
      g/255,
      b/255,
      a/255
    }
  end

  local map = {}
  s = s:match("(\n3 %d+ %d+ %d+.*)")
  for v1,v2,v3 in s:gmatch("3 (%d+) (%d+) (%d+)") do
    map[#map+1] = v1+1
    map[#map+1] = v2+1
    map[#map+1] = v3+1
  end

  local mesh = love.graphics.newMesh(verts, "triangles")
  mesh:setVertexMap( map )

  return mesh
end

local function roundrect(mode, x, y, width, height, xround, yround)
  xround = xround or 10
  yround = yround or 10
  local points = {}
  local precision = (xround + yround) * .1
  local tI, hP = table.insert, .5*math.pi
  if xround > width*.5 then xround = width*.5 end
  if yround > height*.5 then yround = height*.5 end
  local X1, Y1, X2, Y2 = x + xround, y + yround, x + width - xround, y + height - yround
  local sin, cos = math.sin, math.cos
  for i = 0, precision do
    local a = (i/precision-1)*hP
    tI(points, X2 + xround*cos(a))
    tI(points, Y1 + yround*sin(a))
  end
  for i = 0, precision do
    local a = (i/precision)*hP
    tI(points, X2 + xround*cos(a))
    tI(points, Y2 + yround*sin(a))
  end
  for i = 0, precision do
    local a = (i/precision+1)*hP
    tI(points, X1 + xround*cos(a))
    tI(points, Y2 + yround*sin(a))
  end
  for i = 0, precision do
    local a = (i/precision+2)*hP
    tI(points, X1 + xround*cos(a))
    tI(points, Y1 + yround*sin(a))
  end
  love.graphics.polygon(mode, unpack(points))
end

local function createRadialGradient(color, segments)
  color = color or {1,1,1,1}
  segments = segments or 30
  local vertices = {}

  -- The first vertex is at the origin (0, 0) and will be the center of the circle.
  table.insert(vertices, {0, 0, 0, 0, unpack(color)})

  -- Create the vertices at the edge of the circle.
  for i=0, segments do
    local angle = (i / segments) * math.pi * 2

    -- Unit-circle.
    local x = math.cos(angle)
    local y = math.sin(angle)

    table.insert(vertices, {x, y,0,0,color[1],color[2],color[3],0})
  end

  -- The "fan" draw mode is perfect for our circle.
  return love.graphics.newMesh(vertices, "fan")
end

--  ____                     _
-- |  _ \ _ __ __ ___      _(_)_ __   __ _
-- | | | | '__/ _` \ \ /\ / / | '_ \ / _` |
-- | |_| | | | (_| |\ V  V /| | | | | (_| |
-- |____/|_|  \__,_| \_/\_/ |_|_| |_|\__, |
--                                   |___/

local function getGlobalOffset(shape, hud, isStatic)
  local x = hud.W*(shape.x or .5) + (shape.X or 0)
  local y = hud.H*(shape.y or .5) + (shape.Y or 0)
  if not isStatic then
    x = x+hud.X
    y = y+hud.Y
  end
  return x,y
end

local function tuneLine(v, len, sWidth, sHeight)
  len = len or 0
  local lenDim = (1-len/sqrt(sWidth^2 + sHeight^2))^2
  local positiveMult = (v >= 0) and 1 or -1
  local col = abs(v)
  col = col>1 and 1 or col -- Cut value over 1
  gfx.setLineWidth(log(abs(v)*2+1)*2+.3)
  if positiveMult > 0 then
    return gfx.setColor(0, col, col, lenDim*(col+.1))
  else
    return gfx.setColor(0, col/3, col, lenDim*(col*.2+.1))
  end
end

local function drawClothesline(shape, hud, isStatic)
  local x1, y1 = getGlobalOffset({}, shape.from, isStatic)
  local x2, y2 = getGlobalOffset({}, shape.to, isStatic)

  -- x1 = x1+20
  -- x2 = x2-20

  local len = sqrt((x1-x2)^2 + (y1-y2)^2)
  tuneLine(shape.width*(shape.widthMult or 1) + (shape.widthMult or 1)-1, len, hud.root.W, hud.root.H)

  local bend = len/5*(shape.mass or 1)
  local bezier
    -- = love.math.newBezierCurve({
    --   x1,y1,
    --   x1+(x2-x1)/2, y1+(y2-y1)/2+bend,
    --   --x1-len/5,y1+len/5,
    --   x2,y2
    -- })

  if shape.gater then
    local x3, y3 = getGlobalOffset({}, shape.gater, isStatic)
    local sc = 70/(len+1)-- Self connection bend
    bezier = love.math.newBezierCurve({
      x1,y1,
      x3-sc, y3+sc/2,
      x3+sc, y3+sc/2,
      x2,y2
    })
  else
    if shape.startpoint ~= 0 and shape.endpoint ~= 1 then
      local v1 = vec(x1,y1)
      local v2 = vec(x2,y2)
      local v0 = (v2-v1)*(shape.endpoint or 1)
      local v3 = v1 + v0
      local v4 = v1 + v0*.95
      gfx.line(x1,y1, v3.x, v3.y)

      gfx.setColor(1,1,1,.4)
      gfx.line(v4.x, v4.y, v3.x, v3.y)
    else
      gfx.line(x1,y1, x2,y2)
    end
    return
  end

  if shape.startpoint ~= 0 and shape.endpoint ~= 1 then
    local lines = bezier:renderSegment(shape.startpoint or 0, shape.endpoint or 1, 4)
    if #lines>=6 then
      gfx.line(lines)
      local n = #lines
      gfx.setColor(1,1,1,.2)
      gfx.line(lines[n-5], lines[n-4], lines[n-3], lines[n-2], lines[n-1], lines[n])
    end
  else
    gfx.line(bezier:render(4))
  end
  -- gfx.line(x1,y1,x2,y2)
  -- print(x1,y1,x2,y2)
end

local function restore(shape, hud, isStatic)
  if shape.blend then gfx.setBlendMode("alpha") end
end

local function drawShape(shape, hud, isStatic)

  -- Special case
  if shape.type == "clothesline" then
    return drawClothesline(shape, hud, isStatic)
  end

  --## color ##--
  local c = shape.color
  local alpha = (isStatic and 1 or hud.a) * (shape.a or 1)
  if alpha < 0.001 then return end

  if c then
    gfx.setColor(c[1], c[2], c[3], (c[4] or 1)*alpha)
  else
    gfx.setColor(1,1,1, alpha)
  end
  if shape.blend then gfx.setBlendMode(shape.blend) end

  --## XY ##--
  local x,y = getGlobalOffset(shape, hud, isStatic)

  if shape.type == "text" then
    local str = tostring(shape.txt)
    if shape.len and shape.len < 1 then
      local len = utf8len(str)
      local subLen = floor(len*shape.len)
      str = sub_utf8(str, 1, subLen) ..
            ((subLen<len and subLen>0) and "█" or "")
    end
    local lineCount  = select(2, str:gsub('\n', '\n'))
    local currFont = fonts[shape.font or min(3, max(1, ceil(hud.W/70)))]
    local currWidth= currFont:getHeight()
    gfx.setFont(currFont) -- TODO: Fix versions
    gfx.printf(str,
      ceil(x),ceil(y-currWidth/2-lineCount*currWidth/2), hud.W, shape.txtAlign or "center")
    return restore(shape, hud, isStatic)
  end

  --## R ##--
  local r = min(hud.W, hud.H)/2 * (shape.r or 1) + (shape.R or 1)


  if shape.type == "radGrad" then
    radialGradient = radialGradient or createRadialGradient()
    gfx.draw(radialGradient, x, y, 0, r, r)
    return restore(shape, hud, isStatic)
  end

  if shape.type == "triangle" then
    local v1 = vec(x,y) + r * vec(1,0):rotateInplace(shape.spin or 0)
    local v2 = vec(x,y) + r * vec(1,0):rotateInplace(pi*2/3 + (shape.spin or 0))
    local v3 = vec(x,y) + r * vec(1,0):rotateInplace(pi*4/3 + (shape.spin or 0))
    gfx.polygon("fill", v1.x, v1.y, v2.x, v2.y, v3.x, v3.y)
    return restore(shape, hud, isStatic)
  end

  if shape.type == "disk" then
    gfx.circle("fill", x, y, r)
    return restore(shape, hud, isStatic)
  end

  --## lineWidth ##--
  gfx.setLineWidth(shape.width*r)

  if shape.type == "line" then
    local x2,y2 = getGlobalOffset(
      {x=shape.x2, y=shape.y2, X=shape.X2, Y=shape.Y2}, hud, isStatic)
    gfx.line(x, y, x2, y2)
    return restore(shape, hud, isStatic)
  end

  if shape.type == "circle" then
    gfx.circle("line", x, y, r)
    return restore(shape, hud, isStatic)
  end

  if shape.type == "arc" then
    gfx.arc("line", "open", x, y, r,
      -(shape.a1 or pi) * sigma(shape.state or math.huge) + (shape.spin or 0),
       (shape.a2 or pi) * sigma(shape.state or math.huge) + (shape.spin or 0))
    return restore(shape, hud, isStatic)
  end
end

--   ____ _
--  / ___| | __ _ ___ ___
-- | |   | |/ _` / __/ __|
-- | |___| | (_| \__ \__ \
--  \____|_|\__,_|___/___/

local mo = {}
mo.__index = mo

local ID = 0
local function uid() ID = ID+1; return ID end

local function newFromRect(parent, x,y,w,h)
  local this = setmetatable({
    x = x or 0,
    y = y or 0,
    w = w or 1,
    h = h or 1,

    r=1, g=1, b=1, a=1,

    list = {},
    parent = parent,
    id = uid(),
    level = 0,
    delay = 0 -- tween delay for shapes
  }, mo)

  if not parent then
    this.all = {}
    this.root = this
  else
    this.root = parent.root
    this.level= parent.level+1
  end

  this:updateThis()

  return this
end

local function newFromTable(parent, rect)
  return newFromRect(parent, rect.x, rect.y, rect.w, rect.h)
end

local function new(parent, ...)
  local args = {...}
  if type(args[1]) == "table" then
    return newFromTable(parent, args[1])
  elseif #args == 2 then
    return newFromRect(parent, 0,0, ...)
  else
    return newFromRect(parent, ...)
  end
end

function mo:center(nx, ny)
  self.x = (nx or .5) - self.w/2
  self.y = (ny or .5) - self.h/2
  return self:updateThis()
end

function mo:resize(dx,dy)
  self.x = self.x + self.w*(1-self.x)*(.5 - dx/2)
  self.y = self.y + self.h*(1-self.y)*(.5 - dy/2)
  self.w = self.w * dx
  self.h = self.h * dy
  return self:updateThis()
end

function mo:resizeG(newW, newH)
  local dw,dh = newW/self.W, newH/self.H
  return self:resize(dw,dh)
end

function mo:square()
  local m = min(self.W, self.H)
  return self:resize(m/self.W, m/self.H)
end

function mo:getCenter()
  return self.X + self.W/2, self.Y + self.H/2
end

function mo:add(arg1, ...)
  local this
  local name
  if type(arg1) == "string" then
    name = arg1
    this = new(self, ...)
    self[name] = this
    this.root.all[name] = this
  else
    this = new(self, arg1, ...)
  end
  local list     = self.list
  list  [#list+1]= this
  self  [#list]  = this
  this.name = name

  -- Store everything
  this.root.all[#this.root.all+1] = this

  return this
end

function mo:splitVertical(split)
  return self:add(0,0,1, split),
         self:add(0,split,1, 1-split)
end

function mo:addCallback(name, func)
  self[name] = func
  return self
end

function mo:getShapeDelay(time)
  self.delay = self.delay + (time or 1)*.3
  --return self.level+#self.shapes*.5
  return self.delay
end

local function processTween(parent,tw, shape)
  local values = tw.values or tw
  local time = tw.time or 1
  local handler = flux.to(shape, time, values)
  handler:ease(tw.ease or "quadout")
  handler:delay(tw.delay or parent:getShapeDelay(time))
end

function mo:addShape(shape)
  if not self.shapes then self.shapes = {} end
  self.shapes[#self.shapes+1] = shape
  if shape.name then self.shapes[shape.name] = shape end

  if shape.tween  then processTween(self, shape.tween, shape)end
  if shape.tweens then
    for i=1, #shape.tweens do
      processTween(self, shape.tweens[i], shape)
    end
  end
  if not shape.tween and not shape.tweens then
    if shape.type == "text" then
      if shape.txt then
        shape.len = 0
        processTween(self, {time=utf8len(shape.txt)/10, values={len=1}}, shape)
      end
    else
      shape.a = 0
      processTween(self, {values={a=1}}, shape)
    end
  end
  return self
end

function mo:extendShape(shape)
  local sh = deepCopy(self.shapes[#self.shapes])
  for k,v in pairs(shape) do
    sh[k] = v
  end
  self:addShape(sh)
  return self
end

function mo:addStaticShape(shape)
  if not self.static then self.static = {} end
  self.static[#self.static+1] = shape
  return self
end

function mo:updateThis()
  -- ## Compute values ## --
  local p = self.parent
  if p then
    self.X = p.X + p.W*self.x
    self.Y = p.Y + p.H*self.y
    self.W = p.W*self.w
    self.H = p.H*self.h

    self.R = self.r*p.r
    self.G = self.g*p.g
    self.B = self.b*p.b
    self.A = self.a*p.a
  else
    self.X = self.x
    self.Y = self.y
    self.W = self.w
    self.H = self.h

    self.R = self.r
    self.G = self.g
    self.B = self.b
    self.A = self.a
  end
  return self
end

function mo:init()
  if self.onInit then self:onInit() end

  -- Draw on canvas if we have static chapes
  if self.static then
    self.canvas = gfx.newCanvas( self.W, self.H )
    gfx.setCanvas(self.canvas)
    gfx.clear()
    gfx.setBlendMode("alpha")

    for i=1, #self.static do
      local shape = self.static[i]
      drawShape(shape, self, true)
    end

    gfx.setCanvas()
  end

  self.initialised = true
end

function mo:update()
  self:updateThis()

  -- ## Init ## --
  if not self.initialised then self:init() end

  -- Draw static
  if self.canvas then
    gfx.setColor(1,1,1, self.A)
    gfx.draw(self.canvas, self.X, self.Y)
  end

  -- ## Update children ## --
  for i=1, #self.list do
    local c = self.list[i]
    c:update()
  end

  -- ## Callbacks ## --
  if self.onUpdate then self:onUpdate() end

  -- ## Draw shapes ## --
  if self.shapes then
    for i=1, #self.shapes do
      local shape = self.shapes[i]
      --if shape.fnc then shape:fnc() end
      for j=1, #shape do
        local anchor = shape[j]
        local val = anchor[2][anchor[3]]

        if anchor[1]=="color" then
          local r,g,b,a
          if #anchor == 4 then r,g,b,a = table.unpack(anchor[4])
          else r,g,b,a = 1,1,1,1 end
          if not shape[anchor[1]] then shape[anchor[1]] = {} end
          local col = shape[anchor[1]]
          col[1] = r*val
          col[2] = g*val
          col[3] = b*val
          col[4] = a
        elseif anchor[1]=="txt_num" then
          shape.txt = round(val, 5)
        elseif anchor[1]=="a:abs:pow(.2)" then
          shape.a = abs(val)^.2
        else
          shape[anchor[1]] = val
        end

      end
      drawShape(shape, self)
    end
  end

  gfx.setLineWidth(1)
  gfx.setColor(0,.5,1, self.A*.1)
  --love.graphics.rectangle("line", self.X,self.Y,self.W,self.H)
  roundrect("line", self.X,self.Y,self.W,self.H)
  --love.graphics.print(table.concat({self.W, self.H}, " "), self.X,self.Y)
  return self
end

-- the module
return setmetatable({
  new  = new
}, {
  __call = function(_, ...) return new(nil, ...) end
})

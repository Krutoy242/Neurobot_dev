--===========================================================
-- Variables
--===========================================================
local mcPath = "./OC/"
package.path = package.path ..";"..mcPath.."?.lua".. ";"..mcPath.."?/init.lua"--.. ";".."?\\init.lua"

require "gooi"
local serialize        = require'ser'
--local moonshine        = require'moonshine'
local synapticRenderer = require"synapticRenderer"
local flux = require"flux"
local nbot

-- ## Utils ## --
local utils = require("utils")
local dbg = utils.debug

-- ## Love ## --
local love         = love
local fs           = love.filesystem
local gfx          = love.graphics

-- ## Locals ## --
local ceil         = math.ceil
local gooi         = gooi
local block_width  = 16
local block_height = 16
local block_depth  = block_height / 2
local grid_size    = 20
--    local abs    = math.abs
--    local exp    = math.exp
local frameNumber  = 0
local trace
local traceMaxLen    = 10
local images         = {}
local canvas
local window         = {w=1100, h=900}
local lastUpdate = 0
local opt = {
  filename = "options.lua"
}
local rendererHUD

local font_pixel
local font_debug

local screenPanel
local glow -- Moonshine effect

---------------------
-- GUI
---------------------
local sliders
local ui_debugLevel
-- local ui_debug

function love.mousereleased(x, y, button) gooi.released() end
function love.mousepressed(x, y, button)  gooi.pressed() end

do
  local major, minor, revision, codename = love.getVersion( )
  if minor < 11 then
    local oldsetColor = gfx.setColor
    gfx.setColor = function(r,g,b,a)
      if type(r) == "table" then
        oldsetColor(r[1]*255,r[2]*255,r[3]*255,(r[4] or 1)*255)
      else
        oldsetColor(r*255,g*255,b*255,(a or 1)*255)
      end
    end
  end
end


--===========================================================
-- Functions
--===========================================================
function love.textinput(text)
  --if (text == "`") then console.Show() end
end

local function isometric(x,y,z)
  local grid_x, grid_y  = 340, 380
  return ceil(grid_x + ((y-x) * (block_width / 2))),
         ceil(grid_y + ((x+y) * (block_depth / 2)) - (block_depth * (grid_size / 2)) - block_depth*z)
end

local function reloadNbot()
  trace = utils.arr3d()
  package.loaded.neuralRobotTest = nil
  nbot = require("neuralRobotTest")
  nbot.resetScene(opt)


  ------------------------------------------
  -- DRAWING NETWORK                      --
  ------------------------------------------
  local nnmargin = 30
  rendererHUD = synapticRenderer.init({
    x       = nnmargin + gfx.getWidth()*.35,
    y       = nnmargin*2,
    w       = gfx.getWidth()*.65-nnmargin*2,
    h       = gfx.getHeight()-nnmargin*3,
    nn      = nbot.getnn(),
    tInput  = nbot.input.descriptions,
    tOutput = nbot.sidesSymbols,
    glow    = glow,
  })
end

--===========================================================
-- Init
--===========================================================
-- function love.conf(t)
--   t.title = "Neural Robot Test"        -- The title of the window the game is in (string)
--   t.author = "Krutoy242"       -- The author of the game (string)
--   t.identity = "neurobot"        -- The name of the save directory (string)
-- end


function love.load()
  ------------------------------------------
  -- Initialization                       --
  ------------------------------------------
  local f = io.open(opt.filename, "r")
  if f ~= nil then
    io.close(f)
    for k, v in pairs(dofile(opt.filename)) do
      opt[k] = v
    end
  end

  ------------------------------------------
  -- Love options                         --
  ------------------------------------------
  gfx.setBackgroundColor(0.01, 0.01, 0.01)

  -- Load images
  local files = love.filesystem.getDirectoryItems( "images" )
  for i=1,#files do
    local fileName = files[i]:sub(1, #files[i]-4)
    images[fileName] = gfx.newImage("images/"..files[i])
  end
  images[2] = images.dirt
  images[3] = images.grass

  --Record the screen dimensions
  local _, _, flags = love.window.getMode()
  -- The window's flags contain the index of the monitor it's currently in.
  window.w , window.h = love.window.getDesktopDimensions(flags.display)
  window.w = window.w*.8
  window.h = window.h*.8

  --Continue as normal
  love.window.setMode(window.w, window.h, {vsync=false})
  love.window.setTitle("Neural Robot Test")
  love.graphics.setDefaultFilter( "nearest", "nearest", 1 )

  font_pixel = gfx.newFont("FixedsysExcelsior.ttf", 14)
  gfx.setFont(font_pixel)

  font_debug = gfx.newFont("FixedsysExcelsior.ttf", 16)

  ------------------------------------------
  -- Predrawn objects                     --
  ------------------------------------------
  -- Draw the grid
  canvas = love.graphics.newCanvas(680, 620)
  love.graphics.setCanvas(canvas)
  love.graphics.clear()
  --love.graphics.setBlendMode("alpha")

  local maxSumm = grid_size*3
  local dim
  for x = -grid_size-1, grid_size do
    for y = -grid_size-1, grid_size do
      for z = -grid_size-1, grid_size do
        dim = (x+y+z)/maxSumm/2+0.7
        gfx.setColor(dim, dim, dim, 1 )

        if (x == -grid_size-1 or y == -grid_size-1 or z == -grid_size-1) then
          gfx.draw(images.bedrock, isometric(x,y,z))
        end
      end
    end
  end
  love.graphics.setCanvas()


  ------------------------------------------
  -- EFFECTS                              --
  ------------------------------------------
  --glow = moonshine(moonshine.effects.glow)
  --glow.strength = 5


  ------------------------------------------
  -- GUI                                  --
  ------------------------------------------
  reloadNbot()


  gooi.shadow()

  -- |````````````
  -- | LEFT PANEL
  -- |
  sliders = {}
  local addSlider = function(name, value, onChanged)
    sliders[#sliders+1] = gooi.newSlider({value = value}):onValueChanged(onChanged)
    sliders[#sliders+1] = gooi.newLabel({text = name}):left()
    sliders[#sliders+1] = gooi.newLabel():right()
  end

  addSlider("DF:", nbot.opt.df)
  addSlider("Speed:", opt.compute_speed,
    function(_, value) opt.compute_speed = value end)
  addSlider("Learning Rate:", opt.learning_rate,
    function(_, value) opt.learning_rate = value end)

  local rows = ceil((#sliders)/3)+2
  local pGrid = gooi.newPanel({x = 0, y = 16, w = 320, h = rows*26,
    layout = "grid ".. rows .."x3"})
  -- Add in the specified cell:
  pGrid--:debug()
  :add(
    gooi.newButton({text = "Shrink Network"}):onRelease(function()
      flux.to(rendererHUD, 1, {w=rendererHUD.w/2, x = rendererHUD.x + rendererHUD.w/2})
        :ease("backinout")
    end),
    gooi.newButton({text = "------"}):onRelease(function()

    end),
    gooi.newButton({text = "Reload Nbot"}):onRelease(function()
      reloadNbot()
    end),
    table.unpack(sliders)
  )
  pGrid:add(gooi.newCheck({text = "Draw MC", checked = opt.drawMC})
      :onValueChanged(function(_, value) opt.drawMC = value end))
  pGrid:add(gooi.newCheck({text = "Draw UI", checked = opt.drawUI})
      :onValueChanged(function(_, value) opt.drawUI = value end))
  pGrid:add(gooi.newCheck({text = "Update NN", checked = opt.updateNN})
      :onValueChanged(function(_, value) opt.updateNN = value end))


  screenPanel = gooi.newPanel({
    x = 0, y = 0,
    w = gfx.getWidth(), h = gfx.getHeight(),
    layout = "game"})

  ui_debugLevel = gooi.newSpinner({
      min   = -1,
      max   = 10,
      value = opt.debugLevel,
      w     = 90,
      h     = 16
    })
  screenPanel:add(ui_debugLevel, "t-r")
  screenPanel:add(gooi.newLabel({text = "Debug level",h=16}):right(), "t-r")

  local spinnerParams = {
      min   = 0,
      max   = 20,
      value = opt.hidden1,
      w     = 50,
      h     = 16
    }
  screenPanel:add(gooi.newSpinner(spinnerParams):onValueChanged(function(_,value)
    opt.hidden1 = value
    reloadNbot()
  end), "t-r")

  spinnerParams.value = opt.hidden2
  spinnerParams.min = 1
  screenPanel:add(gooi.newSpinner(spinnerParams):onValueChanged(function(_,value)
    opt.hidden2 = value
    reloadNbot()
  end), "t-r")

  screenPanel:add(gooi.newLabel({text = "Hidden 1 and 2",h=16}):right(), "t-r")
end

function love.quit()
  nbot.saveOptions()

  -- Merge two options
  for k,v in pairs(nbot.opt) do
    if not opt[k] then opt[k] = v end
  end

  local f = io.open(opt.filename, "w")
  f:write(serialize(opt))
  f:close()

  return false
end

function love.update(dt)
  -- Check if options are updated
  -- local optFile = fs.getInfo"options.lua"
  -- if optFile then
  --   local time = optFile.modtime
  --   if time > optionsModtime then
  --     optionsModtime = time
  --     nbot.loadOptions()
  --   end
  -- end

  gooi.update(dt)

  -- Update options
  local newLevel = ui_debugLevel:getValue()
  if (opt.debugLevel and opt.debugLevel ~= newLevel) or dbg.level ~= newLevel then
    opt.debugLevel              = newLevel
    dbg.level                   = newLevel
    synapticRenderer.infoAmount = newLevel
  end

  for i=1, #sliders,3 do
    sliders[i+2]:setText(sliders[i]:getValue())
  end
  opt.df = sliders[1]:getValue()
  opt.exploreImportance = sliders[7]:getValue()


  frameNumber = frameNumber + 1

  if opt.updateNN then
    local val = 100^(sliders[4]:getValue()*2-1)
    local to = 1
    if val > 1 then
      if lastUpdate >= val/30 then
        lastUpdate = 0
      else
        lastUpdate = lastUpdate + dt
        to = -1
      end
    end
    for _=0+0.01, to, val do
      if not nbot.doAction() then
        nbot.saveNetwork()
        nbot.resetScene()
        trace = utils.arr3d()
        break
      end
      trace:set(_G.robot.x,_G.robot.y,_G.robot.z, love.timer.getTime())
    end
  end
end

--===========================================================
-- DRAW
--===========================================================
function love.draw()

  if opt.drawMC then
    gfx.push()
    gfx.translate( -70, window.h/2- canvas:getHeight()/2+50)

    --gfx.setBlendMode("alpha")--, "premultiplied")
    gfx.setColor(1, 1, 1, .5)
    gfx.draw(canvas)
    --gfx.setBlendMode("alpha")

    -- Sotre everything we need to draw
    -- rewriting same poses
    local drawTable = {}
    local list = {}
    local r,g,b,a
    local minx, miny = 9999, 9999
    local maxx, maxy = 0, 0
    local setColor = function(...)
      gfx.setColor(...)
      -- r,g,b,a = ...
    end
    local store = function(img, x, y)
      gfx.draw(img, x, y)
      -- minx = minx>x and x or minx
      -- miny = miny>y and y or miny
      -- maxx = maxx<x and x or maxx
      -- maxy = maxy<y and y or maxy
      -- drawTable[x] = drawTable[x] or {}
      -- if not drawTable[x][y] then
      --   list[#list+1] = {x,y, img, r,g,b,a}
      --   drawTable[x][y] = #list
      -- else
      --   list[drawTable[x][y]] = {x,y, img, r,g,b,a}
      -- end
    end

    local maxSumm = grid_size*3
    local dim
    for x = -grid_size-1, grid_size do
      for y = -grid_size-1, grid_size do
        for z = -grid_size-1, grid_size do
          dim = (x+y+z)/maxSumm/2+0.7
          setColor(dim, dim, dim, 1 )

          if ( _G.robot.x == x and _G.robot.y == y and _G.robot.z == z) then
            store(images.player_head1, isometric(x,y,z))
          elseif G_PositionMatrix(x,y,z) then
            local id = G_PositionMatrix(x,y,z+1) and 2 or 3
            store(images[id], isometric(x,y,z))
          elseif trace(x,y,z) then
            local tr = trace(x,y,z)
            if tr then
              local dist = love.timer.getTime() - tr
              if dist<traceMaxLen then
                setColor(dim*0.25, dim*0.75, dim, (1-dist/traceMaxLen)^2)
                -- local adim = (1-dist/traceMaxLen)^2
                -- setColor(adim*dim*0.25, adim*dim*0.75, adim*dim)
                store(images.stone, isometric(x,y,z))
              else
                trace:set(x,y,z, nil)
              end
            end
          end

        end
      end
    end

    -- for y=miny, maxy, 4 do
    --   for x=minx, maxx, 8 do
    --   --if drawTable[x] then
    --       local v = drawTable[x] and drawTable[x][y] or nil
    --       if v then
    --         gfx.setColor(v[2], v[3], v[4], v[5])
    --         gfx.draw(v[1], x, y)
    --       end
    --     end
    --   --end
    -- end
    -- for i=1, #list do
    --   local v = list[i]
    --   gfx.setColor(v[4], v[5], v[6], v[7])
    --   gfx.draw(v[3], v[1], v[2])
    -- end
    gfx.pop()
  end

  gfx.setColor(.4,.7,.8, .4)
  gfx.setFont(font_debug)
  gfx.print( ("FPS: %.0f"):format(1/love.timer.getAverageDelta()) )
  --gfx.printf(utils.lastFlush()--[[:gsub("▌","\n")]], 10, 150, window.w, "left")
  gfx.setFont(font_pixel)

  -- Dim world
  if dbg.Level_Full then
    gfx.setColor(0, 0, 0, .3)
    gfx.rectangle( "fill", rendererHUD.X, rendererHUD.Y,
                           rendererHUD.W, rendererHUD.H )

    synapticRenderer.draw()
  end

  if opt.drawUI then
    gooi.draw()
  end

  --glow(function()
  gfx.setColor(.4,.7,.8, 1)
  --end)
end
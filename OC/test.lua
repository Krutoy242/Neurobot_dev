local mcPath = "OC\\"
package.path = package.path ..";"..mcPath.."?.lua".. ";"..mcPath.."?\\init.lua"--.. ";".."?\\init.lua"

require("outsideFix")

local sides = require"OC/lib/sides"
local m_sidesRemake = {
  sides.forward,
  sides.down,
  sides.up,
  sides.right,
  sides.left
}

local R            = require("OC/robotNavigation")
local sidesSymbols = {" ↑","⟱","⟰"," ↱"," ↰"}
R.x = 0
R.f = 0

local D = R.distanceFromSide

for k=0,3 do 
  R.f = k
  print("current f: ", R.f)
  local tbl = {}
  for i=1, #sidesSymbols do
    tbl[#tbl+1] = string.format("%2d %2d %2d", D( 1,-1,0, m_sidesRemake[i]), D( 1, 0,0, m_sidesRemake[i]), D( 1, 1,0, m_sidesRemake[i]))
    tbl[#tbl+1] = string.format("%2d %2s %2d", D( 0,-1,0, m_sidesRemake[i]), sidesSymbols[i],              D( 0, 1,0, m_sidesRemake[i]))
    tbl[#tbl+1] = string.format("%2d %2d %2d", D(-1,-1,0, m_sidesRemake[i]), D(-1, 0,0, m_sidesRemake[i]), D(-1, 1,0, m_sidesRemake[i]))
  end

  for i=0, 2 do
    for j=0, 4 do io.write(tbl[i+1+j*3], " ") end
    io.write("\n")
  end
end
-- print(R.distanceFromSide({-1,0,0}, m_sidesRemake[1]))
-- -- print(R.distanceFromSide({-1,0,0}, m_sidesRemake[2]))
-- -- print(R.distanceFromSide({-1,0,0}, m_sidesRemake[3]))
-- print(R.distanceFromSide({-1,0,0}, m_sidesRemake[4]))

-- print()
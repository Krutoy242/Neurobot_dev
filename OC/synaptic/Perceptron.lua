local Network = require"synaptic.Network"
local Layer = require"synaptic.Layer"

local Perceptron = setmetatable({}, Network)

function Perceptron.new(...)
  local this = Network.new()

  local args = {...} -- convert arguments to array
  if #args < 3 then
    error("not enough layers (minimum 3) !!")
  end

  local inputs = table.remove(args,1)
  local outputs = table.remove(args)
  local layers = args

  local inputLayer = Layer.new(inputs)
  local hiddenLayers = {}
  local outputLayer = Layer.new(outputs)

  local previous = inputLayer

  -- generate layers
  for i = 1, #layers do
    -- generate memory blocks (memory cell and respective gates)
    local size = layers[i]
    local layer = Layer.new(size)
    hiddenLayers[#hiddenLayers+1] = layer
    previous:project(layer)
    previous = layer
  end
  previous:project(outputLayer)

  -- set the layers of the neural network
  this:set{
    input= inputLayer,
    hidden= hiddenLayers,
    output= outputLayer
  }

  return this
end

Perceptron.__index = Perceptron
return Perceptron
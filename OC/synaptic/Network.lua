-- local Neuron = require'Neuron'
-- local Layer = require'Layer'
-- local Trainer = require'Trainer'
local Network ={}

function Network.new(layers)
  local this = setmetatable({
    class="Network"
  }, Network)
  if layers then
    this.layers = {
      input= layers.input or nil,
      hidden= layers.hidden or {},
      output= layers.output or nil
    }
  end
  return this
end

-- feed-forward activation of all the layers to produce an ouput
function Network:activate(input)
  self.layers.input:activate(input)
  for i=1, #self.layers.hidden do
    self.layers.hidden[i]:activate()
  end
  return self.layers.output:activate()
end

-- back-propagate the error thru the network
function Network:propagate(rate, target)
  self.layers.output:propagate(rate, target)
  for i=#self.layers.hidden,1,-1  do
    self.layers.hidden[i]:propagate(rate)
  end
end

-- project a connection to another unit (either a network or a layer)
function Network:project(unit, type, weights)
  if unit.class == "Network" then
    return self.layers.output:project(unit.layers.input, type, weights)
  end
  if unit.class == "Layer" then
    return self.layers.output:project(unit, type, weights)
  end
  error('Invalid argument, you can only project connections to LAYERS and NETWORKS!')
end

-- let self network gate a connection
function Network:gate(connection, type)
  self.layers.output:gate(connection, type)
end

-- clear all elegibility traces and extended elegibility traces
-- (the network forgets its context, but not what was trained)
function Network:clear()
  local inputLayer = self.layers.input
  local outputLayer = self.layers.output

  inputLayer:clear()
  for i=1, #self.layers.hidden do
    self.layers.hidden[i]:clear()
  end
  outputLayer:clear()
end

-- reset all weights and clear all traces (ends up like a network)
function Network:reset()
  local inputLayer = self.layers.input
  local outputLayer = self.layers.output

  inputLayer:reset()
  for i=1, #self.layers.hidden do
    self.layers.hidden[i]:reset()
  end
  outputLayer:reset()
end

-- returns all the neurons in the network
function Network:neurons()
  local neurons = {}

  local inputLayer = self.layers.input:neurons()
  local outputLayer = self.layers.output:neurons()

  for i=1, #inputLayer do
    neurons[#neurons+1] = {
      neuron = inputLayer[i],
      layer  = 'input'
    }
  end

  for i=1, #self.layers.hidden do
    local hiddenLayer = self.layers.hidden[i]:neurons()
    for j=1, #hiddenLayer do
      neurons[#neurons+1] = {
        neuron = hiddenLayer[j],
        layer  = i
      }
    end
  end

  for i=1, #outputLayer do
    neurons[#neurons+1] = {
      neuron = outputLayer[i],
      layer  = 'output'
    }
  end

  return neurons
end

-- returns number of inputs of the network
function Network:inputs()
  return self.layers.input.size
end
-- returns number of outputs of hte network
function Network:outputs()
  return self.layers.output.size
end

-- sets the layers of the network
function Network:set(layers)
  self.layers = {
    input  = layers.input or nil,
    hidden = layers.hidden or {},
    output = layers.output or nil
  }
end

Network.__index = Network
return Network
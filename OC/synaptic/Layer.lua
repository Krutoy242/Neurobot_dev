local LayerConnection = require'synaptic.LayerConnection'
local Neuron = require'synaptic.Neuron'
--local Network = require'Network'

local Layer = {
-- types of connections
  connectionType = {
    ALL_TO_ALL= "ALL TO ALL",
    ONE_TO_ONE= "ONE TO ONE",
    ALL_TO_ELSE= "ALL TO ELSE"
  },

-- types of gates
  gateType = {
    INPUT= "INPUT",
    OUTPUT= "OUTPUT",
    ONE_TO_ONE= "ONE TO ONE"
  }
}

function Layer.new(size)
  local this = setmetatable({
    class="Layer",
    size = size or 0,
    list = {},
    connectedTo = {}
  }, Layer)

  for i=1, size do
    this.list[i] = Neuron.new()
  end
  return this
end

-- activates all the neurons in the layer
function Layer:activate(input)

  local activations = {}

  if input then
    if #input ~= self.size then
      error('INPUT size and LAYER size must be the same to activate!')
    end
    for id=1, #self.list do
      activations[#activations+1] = self.list[id]:activate(input[id])
    end
  else
    for id=1, #self.list do
      activations[#activations+1] = self.list[id]:activate()
    end
  end
  return activations
end

-- propagates the error on all the neurons of the layer
function Layer:propagate(rate, target)

  if target then
    if #target ~= self.size then
      error('TARGET size and LAYER size must be the same to propagate!')
    end
    for id = #self.list, 1, -1 do
      self.list[id]:propagate(rate, target[id])
    end
  else
    for id = #self.list, 1, -1 do
      self.list[id]:propagate(rate)
    end
  end
end

-- projects a connection from self layer to another one
function Layer:project(layer, type, weights)

  if layer.class == "Network" then
    layer = layer.layers.input
  end
  if layer.class == "Layer" then
    if not self:connected(layer) then
      return LayerConnection.new(self, layer, type, weights)
    end
  else
    error('Invalid argument, you can only project connections to LAYERS and NETWORKS!')
  end
end

-- gates a connection betwenn two layers
function Layer:gate(connection, type)

  if type == Layer.gateType.INPUT then
    if connection.to.size ~= self.size then
      error('GATER layer and CONNECTION.TO layer must be the same size in order to gate!')
    end
    for id=1, #connection.to.list do
      local neuron = connection.to.list[id]
      local gater = self.list[id]
      for _,gated in pairs(neuron.connections.inputs) do
        if connection.connections[gated.ID] then
          gater:gate(gated)
        end
    end
  end
  elseif type == Layer.gateType.OUTPUT then
    if connection.from.size ~= self.size then
      error('GATER layer and CONNECTION.FROM layer must be the same size in order to gate!')
    end
    for id=1, #connection.from.list do
      local neuron = connection.from.list[id]
      local gater = self.list[id]
      for _,gated in pairs(neuron.connections.projected) do
        if connection.connections[gated.ID] then
          gater:gate(gated)
        end
      end
    end
  elseif type == Layer.gateType.ONE_TO_ONE then
    if connection.size ~= self.size then
      error('The number of GATER UNITS must be the same as the number of CONNECTIONS to gate!')
    end
    for id=1, #connection.list do
      local gater = self.list[id]
      local gated = connection.list[id]
      gater:gate(gated)
    end
  end
  connection.gatedfrom[#connection.gatedfrom+1] = {layer= self, type= type}
end

-- true or false whether the whole layer is self-connected or not
function Layer:selfconnected()

  for id=1, #self.list do
    local neuron = self.list[id]
    if not neuron.selfconnected() then
      return nil
    end
  end
  return true
end

-- true of false whether the layer is connected to another layer (parameter) or not
function Layer:connected(layer)
  -- Check if ALL to ALL connection
  local connections = 0
  for here=1, #self.list do
    for there=1, #layer.list do
      local from = self.list[here]
      local to = layer.list[there]
      local connected = from:connected(to)
      if connected and connected.type == 'projected' then
        connections = connections + 1
      end
    end
  end
  if connections == self.size * layer.size then
    return Layer.connectionType.ALL_TO_ALL
  end

  -- Check if ONE to ONE connection
  connections = 0
  for neuron=1, #self.list do
    local from = self.list[neuron]
    local to = layer.list[neuron]
    local connected = from:connected(to)
    if connected and connected.type == 'projected' then
      connections = connections + 1
    end
  end
  if connections == self.size then
    return Layer.connectionType.ONE_TO_ONE
  end
end

-- clears all the neuorns in the layer
function Layer:clear()
  for id=1, #self.list do
    self.list[id]:clear()
  end
end

-- resets all the neurons in the layer
function Layer:reset()
  for id=1, #self.list do
    self.list[id]:reset()
  end
end

-- returns all the neurons in the layer (array)
function Layer:neurons()
  return self.list
end

-- adds a neuron to the layer
function Layer:add(neuron)
  neuron = neuron or Neuron.new()
  self.list[#self.list] = neuron
  self.size = self.size + 1
end

function Layer:set(options)
  options = options or {}

  for i=1, #self.list do
    local neuron = self.list[i]
    if options.label then
      neuron.label = options.label .. '_' .. neuron.ID
    end
    if options.squash then
      neuron.squash = options.squash
    end
    if options.bias then
      neuron.bias = options.bias
    end
  end
  return self
end


Layer.__index = Layer
return Layer
local Connection = require'synaptic.Connection'

local Neuron = {
  connections = Connection.connections,
  neurons = 0,

  -- squashing functions
  squash = {
    -- eq. 5 & 5'
    LOGISTIC = function (x, derivate)
      local fx = 1 / (1 + math.exp(-x))
      if not derivate then
        return fx
      end
      return fx * (1 - fx)
    end,
    TANH = function (x, derivate)
      if derivate then
        return 1 - math.pow(math.tanh(x), 2)
      end
      return math.tanh(x)
    end,
    IDENTITY= function (x, derivate)
      return derivate and 1 or x
    end,
    HLIM= function (x, derivate)
      return derivate and 1 or x > 0 and 1 or 0;
    end,
    RELU= function (x, derivate)
      if derivate then
        return x > 0 and 1 or 0
      end
      return x > 0 and x or 0
    end
  }
}

function Neuron.new()
  local this = setmetatable({
  },Neuron)
  this.ID = Neuron.uid()

  this.connections = {
    inputs    = {},
    projected = {},
    gated     = {}
  }
  this.error = {
    responsibility = 0,
    projected      = 0,
    gated          = 0
  }
  this.trace = {
    elegibility = {},
    extended    = {},
    influences  = {}
  }
  this.state = 0
  this.old = 0
  this.activation = 0
  this.selfconnection = Connection.new(this, this, 0) -- weight = 0 -> not connected
  this.squash = Neuron.squash.LOGISTIC
  this.neighboors = {}
  this.bias = math.random() * .2 - .1

  return this
end

function Neuron.uid()
  Neuron.neurons = Neuron.neurons + 1
  return Neuron.neurons
end

function Neuron.quantity()
  return {
    neurons= Neuron.neurons,
    connections= Neuron.connections
  }
end

-- activate the neuron
function Neuron:activate(envinput)
  -- activation from enviroment (for input neurons)
  if envinput then
    self.activation = envinput
    self.derivative = 0
    self.bias = 0
    return self.activation
  end

  -- old state
  self.old = self.state

  -- eq. 15
  self.state = self.selfconnection.gain * self.selfconnection.weight * self.state + self.bias

  for _,input in pairs(self.connections.inputs) do
    self.state = self.state + input.from.activation * input.weight * input.gain
  end

  -- eq. 16
  self.activation = self.squash(self.state)

  -- f'(s)
  self.derivative = self.squash(self.state, true)

  -- update traces
  local influences = {}
  for id,_ in pairs(self.trace.extended) do
    -- extended elegibility trace
    local neuron = self.neighboors[id]

    -- if gated neuron's selfconnection is gated by self unit, the influence keeps track of the neuron's old state then
    local influence = neuron.selfconnection.gater == self and neuron.old or 0

    -- index runs over all the incoming connections to the gated neuron that are gated by self unit
    for incoming=1, #self.trace.influences[neuron.ID] do -- captures the effect that has an input connection to self unit, on a neuron that is gated by self unit
      influence = influence + self.trace.influences[neuron.ID][incoming].weight *
        self.trace.influences[neuron.ID][incoming].from.activation
    end
    influences[neuron.ID] = influence
  end

  for _,input in pairs(self.connections.inputs) do

    -- elegibility trace - Eq. 17
    self.trace.elegibility[input.ID] = self.selfconnection.gain * self.selfconnection.weight *
          self.trace.elegibility[input.ID] + input.gain * input.from.activation

    for id,_ in pairs(self.trace.extended) do
      -- extended elegibility trace
      local xtrace = self.trace.extended[id]
      local neuron = self.neighboors[id]
      local influence = influences[neuron.ID]

      -- eq. 18
      xtrace[input.ID] = neuron.selfconnection.gain *
            neuron.selfconnection.weight *
            xtrace[input.ID] +
            self.derivative *
            self.trace.elegibility[input.ID] *
            influence
    end
  end

  --  update gated connection's gains
  for _,neuron in pairs(self.connections.gated) do
    neuron.gain = self.activation
  end
  return self.activation
end

-- back-propagate the error
function Neuron:propagate(rate, target)
  -- error accumulator
  local error = 0

  -- whether or not this neuron is in the output layer
  -- output neurons get their error from the enviroment
  if target then
    local val = target - self.activation
    self.error.responsibility = val
    self.error.projected = val -- Eq. 10
  else -- the rest of the neuron compute their error responsibilities by backpropagation
    -- error responsibilities from all the connections projected from this neuron
    for _,connection in pairs(self.connections.projected) do
      local neuron = connection.to
      -- Eq. 21
      error = error + neuron.error.responsibility * connection.gain * connection.weight
    end

    -- projected error responsibility
    self.error.projected = self.derivative * error

    error = 0
    -- error responsibilities from all the connections gated by self neuron
    for id,_ in pairs(self.trace.extended) do
      local neuron = self.neighboors[id]
      local influence = neuron.selfconnection.gater == self and neuron.old or 0 -- if gated neuron's selfconnection is gated by self neuron then

      -- index runs over all the connections to the gated neuron that are gated by self neuron
      for input, infl in pairs(self.trace.influences[id]) do -- captures the effect that the input connection of self neuron have, on a neuron which its input/s is/are gated by self neuron
        influence = influence + infl.weight * self.trace.influences[neuron.ID][input].from.activation
      end
      -- eq. 22
      error = error + neuron.error.responsibility * influence
    end

    -- gated error responsibility
    self.error.gated = self.derivative * error

    -- error responsibility - Eq. 23
    self.error.responsibility = self.error.projected + self.error.gated
  end

  -- learning rate
  rate = rate or .1

  -- adjust all the neuron's incoming connections
  for _,input in pairs(self.connections.inputs) do

    -- Eq. 24
    local gradient = self.error.projected * self.trace.elegibility[input.ID]
    for id,_ in pairs(self.trace.extended) do
      local neuron = self.neighboors[id]
      gradient = gradient + neuron.error.responsibility * self.trace.extended[neuron.ID][input.ID]
    end
    input.weight = input.weight + rate * gradient -- adjust weights - aka learn
  end

  -- adjust bias
  self.bias = self.bias + rate * self.error.responsibility
end

function Neuron:project(neuron, weight)
  local connection
  -- self-connection
  if neuron == self  then
    self.selfconnection.weight = 1
    return self.selfconnection
  end

  -- check if connection already exists then
  local connected = self:connected(neuron)
  if connected and connected.type == 'projected'  then
    -- update connection
    if weight then connected.connection.weight = weight end
    -- return existing connection
    return connected.connection
  else
    -- create a connection
    connection = Connection.new(self, neuron, weight)
  end

  -- reference all the connections and traces
  self.connections.projected[connection.ID] = connection
  self.neighboors[neuron.ID]                = neuron
  neuron.connections.inputs[connection.ID]  = connection
  neuron.trace.elegibility[connection.ID]   = 0

  for _,trace in pairs(neuron.trace.extended) do
    trace[connection.ID] = 0
  end

  return connection
end

function Neuron:gate(connection)
  -- add connection to gated list
  self.connections.gated[connection.ID] = connection

  local neuron = connection.to
  if not self.trace.extended[neuron.ID] then
    -- extended trace
    self.neighboors[neuron.ID] = neuron
    local xtrace = {}
    self.trace.extended[neuron.ID] = xtrace
    for _,input in pairs(self.connections.inputs) do
      xtrace[input.ID] = 0
    end
  end

  -- keep track
  if self.trace.influences[neuron.ID] then
    self.trace.influences[neuron.ID][#self.trace.influences[neuron.ID]+1] = connection
  else
    self.trace.influences[neuron.ID] = {connection}
  end

  -- set gater
  connection.gater = self
end

-- returns true or false whether the neuron is self-connected or not
function Neuron:selfconnected()
  return self.selfconnection.weight ~= 0
end

-- returns true or false whether the neuron is connected to another neuron (parameter)
function Neuron:connected(neuron)
  local result = {
    type       = nil,
    connection = nil
  }

  if self == neuron  then
    if self:selfconnected()  then
      result.type = 'selfconnection'
      result.connection = self.selfconnection
      return result
    else
      return nil
    end
  end

  for type,conn in pairs(self.connections) do
    for _,connection in pairs(conn) do
      if connection.to == neuron  then
        result.type = type
        result.connection = connection
        return result
      elseif connection.from == neuron  then
        result.type = type
        result.connection = connection
        return result
      end
    end
  end

  return nil
end

-- clears all the traces
-- (the neuron forgets it's context, but the connections remain intact)
function Neuron:clear()
  for trace, _ in pairs(self.trace.elegibility) do
    self.trace.elegibility[trace] = 0
  end

  for trace,_ in pairs(self.trace.extended) do
    for extended,_ in pairs(self.trace.extended[trace]) do
      self.trace.extended[trace][extended] = 0
    end
  end

  self.error.responsibility = 0
  self.error.projected = 0
  self.error.gated = 0
end

-- -- all the connections are randomized and the traces are cleared
-- function Neuron:reset()
--   self:clear()

--   for type=1, #self.connections do
--     for connection=1, #self.connections[type] do
--       self.connections[type][connection].weight = math.random() * .2 - .1
--     end
--   end

--   self.bias = math.random() * .2 - .1
--   self.old = 0
--   self.state = 0
--   self.activation = 0
-- end


Neuron.__index = Neuron
return Neuron
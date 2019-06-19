local Network = require"synaptic.Network"
local Layer = require"synaptic.Layer"

local LSTM = setmetatable({}, Network)

function LSTM.new(...)
  local this = Network.new()

  local args = {...} -- convert arguments to array
  if #args < 3 then
    error("not enough layers (minimum 3) !!")
  end

  local last = table.remove(args)
  local option = {
    peepholes      = Layer.connectionType.ALL_TO_ALL,
    hiddenToHidden = nil,
    outputToHidden = nil,
    outputToGates  = nil,
    inputToOutput  = true,
  }

  local outputs = last

  local inputs = table.remove(args,1)
  local layers = args
  local inputLayer = Layer.new(inputs)
  local hiddenLayers = {}
  local outputLayer = Layer.new(outputs)

  local previous = nil

  -- generate layers
  for i = 1, #layers do
    -- generate memory blocks (memory cell and respective gates)
    local size = layers[i]

    local inputGate  = Layer.new(size):set({bias=1})
    local forgetGate = Layer.new(size):set({bias=1})
    local memoryCell = Layer.new(size)
    local outputGate = Layer.new(size):set({bias=1})

    hiddenLayers[#hiddenLayers+1] = inputGate
    hiddenLayers[#hiddenLayers+1] = forgetGate
    hiddenLayers[#hiddenLayers+1] = memoryCell
    hiddenLayers[#hiddenLayers+1] = outputGate

    -- connections from input layer
    local input = inputLayer:project(memoryCell)
    inputLayer:project(inputGate)
    inputLayer:project(forgetGate)
    inputLayer:project(outputGate)

    -- connections from previous memory-block layer to this one
    local cell
    if previous then
      cell = previous:project(memoryCell)
      previous:project(inputGate)
      previous:project(forgetGate)
      previous:project(outputGate)
    end

    -- connections from memory cell
    local output = memoryCell:project(outputLayer)

    -- self-connection
    local selfconn = memoryCell:project(memoryCell)

    -- hidden to hidden recurrent connection
    if option.hiddenToHidden then
      memoryCell:project(memoryCell, Layer.connectionType.ALL_TO_ELSE)
    end

    -- out to hidden recurrent connection
    if option.outputToHidden then
      outputLayer:project(memoryCell)
    end

    -- out to gates recurrent connection
    if option.outputToGates then
      outputLayer:project(inputGate)
      outputLayer:project(outputGate)
      outputLayer:project(forgetGate)
    end

    -- peepholes
    memoryCell:project(inputGate, option.peepholes)
    memoryCell:project(forgetGate, option.peepholes)
    memoryCell:project(outputGate, option.peepholes)

    -- gates
    inputGate:gate(input, Layer.gateType.INPUT)
    forgetGate:gate(selfconn, Layer.gateType.ONE_TO_ONE)
    outputGate:gate(output, Layer.gateType.OUTPUT)
    if previous then
      inputGate:gate(cell, Layer.gateType.INPUT)
    end

    previous = memoryCell
  end

  -- input to output direct connection
  if option.inputToOutput then
    inputLayer:project(outputLayer)
  end

  -- set the layers of the neural network
  this:set{
    input= inputLayer,
    hidden= hiddenLayers,
    output= outputLayer
  }

  return this
end

LSTM.__index = LSTM
return LSTM
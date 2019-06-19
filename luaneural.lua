--********************************************************
-- By Krutoy242
--
-- Based on
-- https://gist.github.com/cassiozen/de0dff87eb7ed599b5d0
--********************************************************

-- Redefine globals to locals for perfomance
local exp  = math.exp
local ceil = math.ceil

--This is the Transfer function (in this case a sigmoid)
local NeuralNetwork = {}
local transfer = function(x) return 1 / (1 + exp(-x)) end


function NeuralNetwork.create(inputs, outputs, hiddenlayers, neurons)
  inputs = inputs or 1
  outputs = outputs or 1
  hiddenlayers = hiddenlayers or ceil(inputs/2)
  neurons = neurons or ceil(inputs*(2/3)+outputs)
  --order goes network[layer][neuron][wieght]
  local network = setmetatable({},{__index = NeuralNetwork});
  network[1] = {}  --Input Layer
  for i = 1,inputs do
    network[1][i] = {}
  end
  for i = 2,hiddenlayers+2 do --plus 2 represents the output layer (also need to skip input layer)
    network[i] = {}
    local neuronsInLayer = neurons
    if i == hiddenlayers+2 then
      neuronsInLayer = outputs
    end
    for j = 1,neuronsInLayer do
      network[i][j] = {bias = math.random()*2-1}
      local numNeuronInputs = #(network[i-1])
      for k = 1,numNeuronInputs do
        network[i][j][k] = math.random()*2-1 --return random number between -1 and 1
      end
    end
  end
  return network
end

function NeuralNetwork:forwardPropagate(...)
  local arg = {...}
  if #(arg) ~= #(self[1]) and type(arg[1]) ~= "table" then
    error("Neural Network received "..#(arg).." input[s] (expected "..#(self[1]).." input[s])",2)
  elseif type(arg[1]) == "table" and #(arg[1]) ~= #(self[1]) then
    error("Neural Network received "..#(arg[1]).." input[s] (expected "..#(self[1]).." input[s])",2)
  end

  local isTableInput = type(arg[1]) == "table"
  local outputs = {}
  local layersCount = #self
  local layer, neuron, result -- Forward declaration for perfomance
  for i = 1, layersCount do
    layer = self[i]
    for j = 1,#layer do
      neuron = layer[j]
      if i == 1 then
        if isTableInput then
          neuron.result = arg[1][j]
        else
          neuron.result = arg[j]
        end
      else
        result = neuron.bias
        for k = 1,#neuron do
          result = result + (neuron[k] * self[i-1][k].result)
        end
        result = transfer(result)
        if i == layersCount then
          outputs[#outputs+1] = result
        end
        neuron.result = result
      end
    end

  end
  return outputs
end

function NeuralNetwork:backwardPropagate(desiredOutputs, learningRate)
  if #(desiredOutputs) ~= #(self[#self]) then
    error("Neural Network received "..#(desiredOutputs).." desired output[s] (expected "..#(self[#self]).." desired output[s])",2)
  end

  learningRate = learningRate or .5

  local layersCount = #self
  local layer, neuron, delta, result, nextLayer, nextNeuron

  for i = layersCount,2,-1 do --iterate backwards (nothing to calculate for input layer)
    layer = self[i]
    for j = 1,#layer do
      neuron = layer[j]
      result = neuron.result
      if i == layersCount then --special calculations for output layer
        neuron.delta = (desiredOutputs[j] - result) * result * (1 - result)
      else
        nextLayer = self[i+1]
        delta = 0
        for k = 1,#nextLayer do
          nextNeuron = nextLayer[k]
          delta = delta + nextNeuron[j]*nextNeuron.delta
        end
        neuron.delta = result * (1 - result) * delta
      end
    end
  end

  for i = 2,layersCount do
    layer = self[i]
    for j = 1,#layer do
      neuron = layer[j]
      delta = neuron.delta
      neuron.bias = delta * learningRate
      for k = 1,#neuron do
        neuron[k] = neuron[k] + delta * learningRate * self[i-1][k].result
      end
    end
  end
end

function NeuralNetwork:save(fileName)
  local f = io.open(fileName, "w")
  if not f then return false end
  --[[
  File specs:
    |INFO| - should be FF BP NN
    |I| - number of inputs
    |O| - number of outputs
    |HL| - number of hidden layers
    |NHL| - number of neurons per hidden layer
    |LR| - learning rate
    |BW| - bias and weight values
  ]]--
  local data = "|INFO|FF BP NN|I|"..
      tostring(#(self[1]))..
      "|O|"..tostring(#(self[#self]))..
      "|HL|"..tostring(#self-2)..
      "|NHL|"..tostring(#(self[2]))..
      "|LR|"..tostring(self.learningRate).."|BW|"
  for i = 2,#self do -- nothing to save for input layer
    for j = 1,#(self[i]) do
      local neuronData = tostring(self[i][j].bias).."{"
      for k = 1,#(self[i][j]) do
        neuronData = neuronData..tostring(self[i][j][k])
        neuronData = neuronData..","
      end
      data = data..neuronData.."}"
    end
  end
  data = data.."|END|"

  f:write(data)
  f:close()
  return true
end

function NeuralNetwork.load(fileName)
  local f = io.open(fileName, "r")
  if not f then return nil end
  local data = f:read()
  f:close()

  local dataPos = string.find(data,"|")+1
  local currentChunk = string.sub(data, dataPos, string.find(data,"|",dataPos)-1)
  dataPos = string.find(data,"|",dataPos)+1
  local _inputs, _outputs, _hiddenLayers, neurons, learningrate
  local biasWeights = {}
  local errorExit = false
  while currentChunk ~= "END" and not errorExit do
    if currentChunk == "INFO" then
      currentChunk = string.sub(data, dataPos, string.find(data,"|",dataPos)-1)
      dataPos = string.find(data,"|",dataPos)+1
      if currentChunk ~= "FF BP NN" then
        errorExit = true
      end
    elseif currentChunk == "I" then
      currentChunk = string.sub(data, dataPos, string.find(data,"|",dataPos)-1)
      dataPos = string.find(data,"|",dataPos)+1
      _inputs = tonumber(currentChunk)
    elseif currentChunk == "O" then
      currentChunk = string.sub(data, dataPos, string.find(data,"|",dataPos)-1)
      dataPos = string.find(data,"|",dataPos)+1
      _outputs = tonumber(currentChunk)
    elseif currentChunk == "HL" then
      currentChunk = string.sub(data, dataPos, string.find(data,"|",dataPos)-1)
      dataPos = string.find(data,"|",dataPos)+1
      _hiddenLayers = tonumber(currentChunk)
    elseif currentChunk == "NHL" then
      currentChunk = string.sub(data, dataPos, string.find(data,"|",dataPos)-1)
      dataPos = string.find(data,"|",dataPos)+1
      neurons = tonumber(currentChunk)
    elseif currentChunk == "LR" then
      currentChunk = string.sub(data, dataPos, string.find(data,"|",dataPos)-1)
      dataPos = string.find(data,"|",dataPos)+1
      learningrate = tonumber(currentChunk)
    elseif currentChunk == "BW" then
      currentChunk = string.sub(data, dataPos, string.find(data,"|",dataPos)-1)
      dataPos = string.find(data,"|",dataPos)+1
      local subPos = 1
      local subChunk
      for i = 1,_hiddenLayers+1 do
        biasWeights[i] = {}
        local neuronsInLayer = neurons
        if i == _hiddenLayers+1 then
          neuronsInLayer = _outputs
        end
        for j = 1,neuronsInLayer do
          biasWeights[i][j] = {}
          biasWeights[i][j].bias = tonumber(string.sub(currentChunk,subPos,string.find(currentChunk,"{",subPos)-1))
          subPos = string.find(currentChunk,"{",subPos)+1
          subChunk = string.sub(currentChunk, subPos, string.find(currentChunk,",",subPos)-1)
          local maxPos = string.find(currentChunk,"}",subPos)
          while subPos < maxPos do
            table.insert(biasWeights[i][j],tonumber(subChunk))
            subPos = string.find(currentChunk,",",subPos)+1
            if string.find(currentChunk,",",subPos) ~= nil then
              subChunk = string.sub(currentChunk, subPos, string.find(currentChunk,",",subPos)-1)
            end
          end
          subPos = maxPos+1
        end
      end
    end
    currentChunk = string.sub(data, dataPos, string.find(data,"|",dataPos)-1)
    dataPos = string.find(data,"|",dataPos)+1
  end
  if errorExit then
    error("Failed to load Neural Network:"..currentChunk,2)
  end
  local network = setmetatable({
    learningRate = learningrate
  },{__index = NeuralNetwork});
  network[1] = {}  --Input Layer
  for i = 1,_inputs do
    network[1][i] = {}
  end
  for i = 2,_hiddenLayers+2 do --plus 2 represents the output layer (also need to skip input layer)
    network[i] = {}
    local neuronsInLayer = neurons
    if i == _hiddenLayers+2 then
      neuronsInLayer = _outputs
    end
    for j = 1,neuronsInLayer do
      network[i][j] = {bias = biasWeights[i-1][j].bias}
      local numNeuronInputs = #(network[i-1])
      for k = 1,numNeuronInputs do
        network[i][j][k] = biasWeights[i-1][j][k]
      end
    end
  end
  return network
end

return NeuralNetwork
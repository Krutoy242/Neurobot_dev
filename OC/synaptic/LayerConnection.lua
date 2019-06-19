local connectionType = {
  ALL_TO_ALL= "ALL TO ALL",
  ONE_TO_ONE= "ONE TO ONE",
  ALL_TO_ELSE= "ALL TO ELSE"
}

-- represents a connection from one layer to another, and keeps track of its weight and gain
local LayerConnection = {
  connections = 0
}


function LayerConnection.uid()
  LayerConnection.connections = LayerConnection.connections + 1
  return LayerConnection.connections
end

function LayerConnection.new(fromLayer, toLayer, type, weights)
  local this = {
    ID             = LayerConnection.uid(),
    from           = fromLayer,
    to             = toLayer,
    selfconnection = toLayer == fromLayer,
    type           = type,
    connections    = {},
    list           = {},
    size           = 0,
    gatedfrom      = {}
  }

  if not this.type then
    if fromLayer == toLayer then
      this.type = connectionType.ONE_TO_ONE
    else
      this.type = connectionType.ALL_TO_ALL
    end
  end

  if (this.type == connectionType.ALL_TO_ALL or
      this.type == connectionType.ALL_TO_ELSE) then
    for here=1, #this.from.list do
      for there=1, #this.to.list do
        local from = this.from.list[here]
        local to = this.to.list[there]
        if not (this.type == connectionType.ALL_TO_ELSE and from == to) then
          local connection = from:project(to, weights)

          this.connections[connection.ID] = connection
          this.list[#this.list+1] = connection
          this.size = #this.list
        end
      end
    end
  elseif this.type == connectionType.ONE_TO_ONE  then

    for neuron=1, #this.from.list do
      local from = this.from.list[neuron]
      local to = this.to.list[neuron]
      local connection = from:project(to, weights)

      this.connections[connection.ID] = connection
      this.list[#this.list+1] = connection
      this.size = #this.list
    end
  end

  fromLayer.connectedTo[#fromLayer.connectedTo+1] = this

  return this
end

LayerConnection.__index = LayerConnection
return LayerConnection
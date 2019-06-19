local Connection = {connections = 0}

function Connection.uid()
    Connection.connections = Connection.connections + 1
    return Connection.connections
  end

function Connection.new(from, to, weight)
  if not from or not to then
    error("Connection Error= Invalid neurons")
  end

  return setmetatable({
    ID = Connection.uid(),
    from = from,
    to = to,
    weight = weight and weight or math.random()*.2-.1 ,
    gain = 1,
    gater = nil
  },{Connection})
end


Connection.__index = Connection
return Connection
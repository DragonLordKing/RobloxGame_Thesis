--[[
Name: ConnectionUtil
Class: ModuleScript
Original path: game.StarterPlayer.StarterPlayerScripts.PlayerModule.CommonUtils.ConnectionUtil
Exported from: Generation
Original comments: removed
Children: 0
Properties: Archivable=false, LinkedSource=""
Functions: ConnectionUtil.new, ConnectionUtil:trackConnection, ConnectionUtil:trackBoundFunction, ConnectionUtil:disconnect, ConnectionUtil:disconnectAll
Clean source lines: 59
]]
type ConnectionUtilClass = {
	__index: ConnectionUtilClass,
	new: () -> ConnectionUtil,

	trackConnection: (self: ConnectionUtil, string, RBXScriptConnection) -> (),

	trackBoundFunction: (self: ConnectionUtil, string, () -> ()) -> (),

	disconnect: (self: ConnectionUtil, string) -> (),

	disconnectAll: (self: ConnectionUtil) -> (),
}

export type ConnectionUtil = typeof(setmetatable({} :: {

	_connections: {[string]: () -> ()},
}, {} :: ConnectionUtilClass))

local ConnectionUtil: ConnectionUtilClass = {} :: ConnectionUtilClass;
ConnectionUtil.__index = ConnectionUtil

function ConnectionUtil.new()
	local self = setmetatable({}, ConnectionUtil)

	self._connections = {}

	return self
end

function ConnectionUtil:trackConnection(key, connection)
	if self._connections[key] then
		self._connections[key]()
	end

	self._connections[key] = function() connection:Disconnect() end
end

function ConnectionUtil:trackBoundFunction(key, disconnectionFunc)
	if self._connections[key] then
		self._connections[key]()
	end
	self._connections[key] = disconnectionFunc
end

function ConnectionUtil:disconnect(key)
	if self._connections[key] then
		self._connections[key]()
		self._connections[key] = nil
	end
end

function ConnectionUtil:disconnectAll()
	for _, disconnectFunc in pairs(self._connections) do
		disconnectFunc()
	end
	self._connections = {}
end

return ConnectionUtil
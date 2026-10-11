-- Server entry point: loads every service, initialises them in order, then starts them.

local Registry = require(script.Registry)

local ORDER = {
	"DataService",
	"AudioService",
	"LocationService",
	"TrainService",
	"ResourceService",
	"CorpseService",
	"PlayerService",
	"CombatService",
	"MonsterService",
	"SquadService",
	"ReviveService",
	"CommanderService",
	"MonetizationService",
	"MatchService",
}

for _, name in ORDER do
	Registry[name] = require(script.Services[name])
end

for _, name in ORDER do
	local service = Registry[name]
	if service.Init then
		service:Init()
	end
end

for _, name in ORDER do
	local service = Registry[name]
	if service.Start then
		task.spawn(service.Start, service)
	end
end

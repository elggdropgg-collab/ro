-- Client entry point.

local Registry = require(script.Registry)

local ORDER = {
	"AudioController",
	"TapeController",
	"WorldController",
	"MonsterController",
	"CorpseController",
	"PromptController",
	"HudController",
	"MenuController",
	"VoteController",
	"MapController",
	"ShopController",
	"DeathController",
	"ScareController",
	"InputController",
	"LookController",
}

for _, name in ORDER do
	Registry[name] = require(script.Controllers[name])
end

for _, name in ORDER do
	local controller = Registry[name]
	if controller.Init then
		controller:Init()
	end
end

for _, name in ORDER do
	local controller = Registry[name]
	if controller.Start then
		task.spawn(controller.Start, controller)
	end
end

--!strict
-- All player-facing text in Russian and English. Use {1}, {2}... for arguments.

local T: { [string]: { ru: string, en: string } } = {
	Title = { ru = "FODDER", en = "FODDER" },
	Tagline = {
		ru = "Они идут первыми. Вы — последними.",
		en = "They go first. You go last.",
	},
	Menu_Play = { ru = "В СОСТАВ", en = "BOARD THE TRAIN" },
	Menu_Settings = { ru = "НАСТРОЙКИ", en = "SETTINGS" },
	Menu_HowTo = { ru = "ИНСТРУКТАЖ", en = "BRIEFING" },
	Menu_Back = { ru = "НАЗАД", en = "BACK" },
	Menu_Waiting = { ru = "Ожидание экипажа...", en = "Waiting for crew..." },
	Menu_Classified = { ru = "СЕКРЕТНО", en = "CLASSIFIED" },
	Menu_Dossier = {
		ru = "ДЕЛО № 0-17 / ЛИНИЯ БЕЗ ВОЗВРАТА",
		en = "FILE No. 0-17 / LINE OF NO RETURN",
	},

	Settings_Tape = { ru = "Эффект плёнки", en = "Tape effect" },
	Settings_Censor = { ru = "Скрытие тел", en = "Body censoring" },
	Settings_Off = { ru = "Выкл", en = "Off" },
	Settings_Normal = { ru = "Обычно", en = "Normal" },
	Settings_Strong = { ru = "Сильно", en = "Strong" },
	Settings_Volume = { ru = "Громкость", en = "Volume" },

	HowTo_Text = {
		ru = "Поезд — единственное безопасное место. На каждой станции нужно найти дизель, чтобы ехать дальше.\n\n"
			.. "Командир управляет отрядом через тактическую карту [M]: ведёт бойцов за собой, рисует маршрут, "
			.. "отправляет на сбор ресурсов или воскрешать павших.\n\n"
			.. "Бойцы — пушечное мясо. Они умрут первыми. Потом — вы.\n\n"
			.. "Патронов мало. Бегите [Shift], прячьтесь в пшенице, светите фонарём [F]. "
			.. "Бессмертного монстра станции можно только оглушить.\n\n"
			.. "На конечной откройте портал в бункере и пройдите через него.",
		en = "The train is the only safe place. At every station you need diesel to move on.\n\n"
			.. "The commander controls the squad on the tactical map [M]: lead soldiers, draw routes, "
			.. "send them to gather resources or revive the fallen.\n\n"
			.. "Soldiers are fodder. They die first. Then you.\n\n"
			.. "Ammo is scarce. Run [Shift], hide in the wheat, use your flashlight [F]. "
			.. "The immortal of each station can only be stunned.\n\n"
			.. "At the terminus, power the portal in the bunker and get through it.",
	},

	Phase_Lobby = {
		ru = "Перрон. Нажмите «В состав», когда будете готовы",
		en = 'Platform. Press "Board the train" when ready',
	},
	Phase_Starting = { ru = "Отправление через {1}", en = "Departing in {1}" },
	Phase_Vote = { ru = "Выбор командира", en = "Choosing a commander" },
	Phase_Travel = { ru = "В пути...", en = "On the move..." },
	Phase_LastChance = { ru = "ПОСЛЕДНИЙ ШАНС: {1}", en = "LAST CHANCE: {1}" },

	Station_Lobby = { ru = "Депо", en = "Depot" },
	Station_Field = { ru = "Станция «Полевая»", en = 'Station "Wheatfield"' },
	Station_Finale = { ru = "Конечная", en = "Terminus" },

	Vote_Title = { ru = "КТО ПОВЕДЁТ ОТРЯД?", en = "WHO LEADS THE SQUAD?" },
	Vote_Hint = {
		ru = "Командир отдаёт приказы бойцам. Если он погибнет, командование перейдёт другому.",
		en = "The commander gives orders. If they die, command passes on.",
	},
	Vote_Result = { ru = "{1} — командир", en = "{1} is in command" },

	Commander_Badge = { ru = "КОМАНДИР", en = "COMMANDER" },
	Commander_Transferred = { ru = "{1} принимает командование", en = "{1} takes command" },
	Commander_Transfer = { ru = "Передать командование", en = "Hand over command" },

	Hint_FindDiesel = {
		ru = "Дизель {1}/{2}. Найдите топливо, чтобы уехать",
		en = "Diesel {1}/{2}. Find fuel to move on",
	},
	Hint_ReadyToDepart = {
		ru = "Топлива хватает. Командир даёт отправление рычагом в локомотиве",
		en = "Enough fuel. The commander pulls the lever in the locomotive",
	},
	Hint_DepartIn = {
		ru = "Поезд отходит через {1}. Все в вагоны!",
		en = "Train leaves in {1}. Get aboard!",
	},
	Hint_Fuses = {
		ru = "Предохранители {1}/{2}. Отнесите их к щитку в бункере",
		en = "Fuses {1}/{2}. Bring them to the panel in the bunker",
	},
	Hint_StartPortal = {
		ru = "Щиток запитан. Запустите портал",
		en = "Panel powered. Start the portal",
	},
	Hint_PortalCharging = {
		ru = "Портал заряжается: {1}. Держитесь!",
		en = "Portal charging: {1}. Hold on!",
	},
	Hint_PortalOpen = { ru = "ПОРТАЛ ОТКРЫТ. БЕГИТЕ!", en = "THE PORTAL IS OPEN. RUN!" },

	Resource_Diesel = { ru = "Дизель", en = "Diesel" },
	Resource_Scrap = { ru = "Металл", en = "Scrap" },
	Resource_Supplies = { ru = "Снабжение", en = "Supplies" },
	Resource_Fuse = { ru = "Предохранитель", en = "Fuse" },
	Resource_DogTag = { ru = "Жетон", en = "Dog tag" },

	Prompt_PickUp = { ru = "Поднять", en = "Pick up" },
	Prompt_TakeTag = { ru = "Взять жетон", en = "Take dog tag" },
	Prompt_Revive = { ru = "Реанимировать", en = "Revive" },
	Prompt_Reanimator = { ru = "Реаниматор", en = "Reanimator" },
	Prompt_Depart = { ru = "Дать отправление", en = "Depart" },
	Prompt_Lever = { ru = "Рычаг", en = "Lever" },
	Prompt_Upgrade = { ru = "Улучшить оружие", en = "Upgrade weapon" },
	Prompt_Recruit = { ru = "Нанять бойца", en = "Recruit soldier" },
	Prompt_Ammo = { ru = "Пополнить патроны", en = "Refill ammo" },
	Prompt_InsertFuse = { ru = "Вставить предохранитель", en = "Insert fuse" },
	Prompt_StartPortal = { ru = "Запустить портал", en = "Start the portal" },
	Prompt_Terminal = { ru = "Терминал", en = "Terminal" },

	Order_Follow = { ru = "За мной", en = "Follow" },
	Order_Route = { ru = "Маршрут", en = "Route" },
	Order_Wander = { ru = "Прочёсывать", en = "Sweep" },
	Order_Gather = { ru = "Сбор", en = "Gather" },
	Order_Hold = { ru = "Стоять", en = "Hold" },
	Order_Retreat = { ru = "Отступить", en = "Retreat" },
	Order_Revive = { ru = "Воскресить", en = "Revive" },
	Order_Fast = { ru = "Бегом", en = "On the double" },

	Map_Title = { ru = "ТАКТИЧЕСКАЯ КАРТА", en = "TACTICAL MAP" },
	Map_SelectAll = { ru = "Все", en = "All" },
	Map_SelectNone = { ru = "Никого", en = "None" },
	Map_DrawRoute = { ru = "Проведите маршрут по карте", en = "Draw a route on the map" },
	Map_NotCommander = {
		ru = "Приказы отдаёт только командир",
		en = "Only the commander can give orders",
	},
	Map_ReviveWho = { ru = "Кого воскресить?", en = "Revive whom?" },
	Map_NoSelection = { ru = "Выберите бойцов", en = "Select soldiers" },
	Map_Squad = { ru = "ОТРЯД", en = "SQUAD" },
	Map_Train = { ru = "СОСТАВ", en = "TRAIN" },
	Map_You = { ru = "ВЫ", en = "YOU" },

	Poi_Farmhouse = { ru = "Ферма", en = "Farmhouse" },
	Poi_Barn = { ru = "Амбар", en = "Barn" },
	Poi_ScarecrowPost = { ru = "Шест", en = "The Post" },
	Poi_Silo = { ru = "Силос", en = "Silo" },
	Poi_Tractor = { ru = "Трактор", en = "Tractor" },
	Poi_Shed = { ru = "Сарай", en = "Shed" },
	Poi_CarWreck = { ru = "Остов машины", en = "Car wreck" },
	Poi_Well = { ru = "Колодец", en = "Well" },
	Poi_Watchtower = { ru = "Вышка", en = "Watchtower" },
	Poi_Checkpoint = { ru = "КПП", en = "Checkpoint" },
	Poi_Truck = { ru = "Грузовик", en = "Truck" },
	Poi_Bunker = { ru = "Бункер", en = "Bunker" },
	Poi_Depot = { ru = "Депо", en = "Depot" },

	Notify_SoldierDown = { ru = "{1} погиб", en = "{1} is down" },
	Notify_PlayerDown = { ru = "{1} погиб", en = "{1} died" },
	Notify_LeftBehind = { ru = "{1} остался на станции", en = "{1} was left behind" },
	Notify_Revived = { ru = "{1} снова в строю", en = "{1} is back" },
	Notify_Deposit = { ru = "+1 {1}", en = "+1 {1}" },
	Notify_NotEnoughDiesel = { ru = "Не хватает дизеля", en = "Not enough diesel" },
	Notify_NotCommander = {
		ru = "Это может только командир",
		en = "Only the commander can do this",
	},
	Notify_Recruited = { ru = "Новый боец: {1}", en = "New recruit: {1}" },
	Notify_NotEnoughScrap = { ru = "Не хватает металла", en = "Not enough scrap" },
	Notify_SquadFull = { ru = "Отряд укомплектован", en = "Squad is full" },
	Notify_Upgraded = { ru = "Оружие улучшено: уровень {1}", en = "Weapon upgraded: level {1}" },
	Notify_NotEnoughCoins = {
		ru = "Не хватает жетонов: нужно {1}",
		en = "Not enough tokens: need {1}",
	},
	Notify_MaxLevel = { ru = "Оружие улучшено до предела", en = "Weapon is fully upgraded" },
	Notify_Scared = {
		ru = "{1} выпустил что-то в эфир...",
		en = "{1} let something onto the radio...",
	},
	Notify_ScareCooldown = { ru = "Скример перезаряжается: {1} с", en = "Scare recharging: {1}s" },
	Notify_CleanupArrived = { ru = "Отряд зачистки высажен", en = "Cleanup squad deployed" },
	Notify_Reinforcements = {
		ru = "Твари стягиваются со всего поля",
		en = "Creatures swarm in from the whole field",
	},
	Notify_ExtraSquad = { ru = "Подкрепление: +{1} бойцов", en = "Reinforcements: +{1} soldiers" },
	Notify_DamageBoost = {
		ru = "Отряд получил усиленные патроны",
		en = "Squad received armor-piercing rounds",
	},
	Notify_ProductUnavailable = { ru = "Сейчас это недоступно", en = "Not available right now" },
	Notify_CreditSaved = {
		ru = "Покупка сохранена, её можно использовать позже",
		en = "Purchase saved, you can use it later",
	},
	Notify_Escaped = { ru = "{1} прошёл через портал", en = "{1} went through the portal" },
	Notify_Grabbed = { ru = "{1}: ОНО МЕНЯ СХВАТИЛО!", en = "{1}: IT'S GOT ME!" },
	Notify_Contact = { ru = "{1}: Контакт!", en = "{1}: Contact!" },
	Notify_FuseInserted = { ru = "Предохранитель вставлен", en = "Fuse inserted" },
	Notify_AmmoRefilled = { ru = "Патроны пополнены", en = "Ammo refilled" },
	Notify_NoSupplies = { ru = "Нет снабжения", en = "No supplies left" },
	Notify_CommanderDown = { ru = "Командир погиб", en = "The commander is down" },
	Notify_NeedTag = { ru = "Нужен жетон павшего", en = "You need a fallen player's dog tag" },
	Notify_HandsFull = { ru = "Руки заняты", en = "Your hands are full" },
	Notify_Stunned = { ru = "Тварь оглушена!", en = "It's stunned!" },

	Death_Title = { ru = "ВЫ МЕРТВЫ", en = "YOU ARE DEAD" },
	Death_Tag = {
		ru = "Ваш жетон лежит там, где вы погибли. Товарищи или бойцы могут отнести его к реаниматору.",
		en = "Your dog tag lies where you fell. Teammates or soldiers can carry it to a reanimator.",
	},
	Death_Station = {
		ru = "Если команда уедет со станции, вы вернётесь на поезде.",
		en = "If your team leaves the station, you come back on the train.",
	},
	Death_SelfRevive = { ru = "Воскресить себя", en = "Revive yourself" },
	Spectating = { ru = "Наблюдение: {1}", en = "Spectating: {1}" },

	LastChance_Title = { ru = "ПОСЛЕДНИЙ ШАНС", en = "LAST CHANCE" },
	LastChance_Text = { ru = "Никого не осталось в живых", en = "Nobody is left alive" },

	End_Victory = { ru = "ВЫ ВЫБРАЛИСЬ", en = "YOU GOT OUT" },
	End_Defeat = { ru = "СОСТАВ ПОТЕРЯН", en = "THE TRAIN IS LOST" },
	End_SoldiersLost = { ru = "Бойцов потеряно: {1}", en = "Soldiers lost: {1}" },
	End_Stations = { ru = "Станций пройдено: {1}", en = "Stations cleared: {1}" },
	End_Escaped = { ru = "Выбрались: {1}", en = "Escaped: {1}" },
	End_Coins = { ru = "+{1} жетонов", en = "+{1} tokens" },
	End_Return = { ru = "Возвращение в депо через {1}", en = "Back to the depot in {1}" },

	HUD_Squad = { ru = "Отряд: {1}", en = "Squad: {1}" },
	HUD_Carrying = { ru = "Несёте: {1}", en = "Carrying: {1}" },
	HUD_Coins = { ru = "Жетоны: {1}", en = "Tokens: {1}" },
	HUD_Map = { ru = "Карта", en = "Map" },
	HUD_Shop = { ru = "Снабжение", en = "Supply" },
	HUD_Reloading = { ru = "Перезарядка...", en = "Reloading..." },

	Shop_Title = { ru = "СНАБЖЕНИЕ ЗА РОБУКСЫ", en = "SUPPLY DROP" },
	Shop_Note = {
		ru = "Покупки помогают, но не проходят игру за вас.",
		en = "Purchases help, but never play the game for you.",
	},
	Shop_FinaleOnly = { ru = "Только на конечной", en = "Terminus only" },

	Product_SelfRevive = { ru = "Второе дыхание", en = "Second Wind" },
	Product_SelfRevive_Desc = {
		ru = "Встать на месте гибели. 10 с неуязвимости и бесконечного бега.",
		en = "Get up where you fell. 10s of invulnerability and endless sprint.",
	},
	Product_ExtraSquad = { ru = "Подкрепление", en = "Reinforcements" },
	Product_ExtraSquad_Desc = {
		ru = "+4 бойца в отряд до конца рейса.",
		en = "+4 soldiers for the rest of the run.",
	},
	Product_DamageBoost = { ru = "Бронебойные патроны", en = "AP Rounds" },
	Product_DamageBoost_Desc = {
		ru = "Отряд наносит в 1.5 раза больше урона до конца рейса.",
		en = "Squad deals 1.5x damage for the rest of the run.",
	},
	Product_ScareAll = { ru = "Помехи в эфире", en = "Dead Air" },
	Product_ScareAll_Desc = {
		ru = "Скример всей команде. Потом их будут преследовать шёпоты...",
		en = "A scare for your whole team. Then the whispers follow them...",
	},
	Product_CleanupWave = { ru = "Отряд зачистки", en = "Cleanup Squad" },
	Product_CleanupWave_Desc = {
		ru = "8 элитных бойцов на конечной. Твари ответят своим подкреплением.",
		en = "8 elite soldiers at the terminus. The creatures answer with their own.",
	},

	Monster_Scarecrow = { ru = "Пугало", en = "The Scarecrow" },
	Monster_Husk = { ru = "Колосник", en = "Husk" },
}

local Strings = {}

function Strings.format(lang: string, key: string, args: { any }?): string
	local entry = T[key]
	if not entry then
		return key
	end
	local text = if lang == "ru" then entry.ru else entry.en
	if args then
		for i, value in args do
			text = string.gsub(text, "{" .. i .. "}", function()
				return tostring(value)
			end)
		end
	end
	return text
end

function Strings.has(key: string): boolean
	return T[key] ~= nil
end

return Strings

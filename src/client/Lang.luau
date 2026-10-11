-- Player language and text lookup. String arguments that are keys get translated too.

local LocalizationService = game:GetService("LocalizationService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Strings = require(ReplicatedStorage.Shared.Strings)

local Lang = {}

local ok, locale = pcall(function()
	return LocalizationService.RobloxLocaleId
end)
local code = if ok and type(locale) == "string" then string.lower(locale) else "en-us"
Lang.Code = if string.sub(code, 1, 2) == "ru"
		or string.sub(code, 1, 2) == "uk"
		or string.sub(code, 1, 2) == "be"
	then "ru"
	else "en"

function Lang.t(key: string, args: { any }?): string
	local translated: { any }? = nil
	if args then
		translated = {}
		for i, value in args do
			if type(value) == "string" and Strings.has(value) then
				(translated :: any)[i] = Strings.format(Lang.Code, value)
			else
				(translated :: any)[i] = value
			end
		end
	end
	return Strings.format(Lang.Code, key, translated)
end

return Lang

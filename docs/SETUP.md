# Запуск проекта

Код живёт в этом репозитории и синхронизируется в Roblox Studio через **Rojo**.
Studio — только для запуска, теста и публикации; правки кода — здесь.

## 1. Инструменты (один раз)

1. Установите [Rokit](https://github.com/rojo-rbx/rokit) — менеджер инструментов.
2. В папке проекта:
   ```powershell
   rokit install
   ```
   Поставит версии из `rokit.toml`: `rojo`, `luau-lsp`, `selene`, `stylua`.
3. Плагин Rojo для Studio:
   ```powershell
   rojo plugin install
   ```
4. В Cursor/VS Code — расширения **Luau Language Server** и **Rojo** (необязательно, но удобно).

## 2. Первый запуск

1. Откройте Roblox Studio → **New** → **Baseplate**. Удалите `Workspace.Baseplate` (игра строит мир сама).
2. В терминале проекта:
   ```powershell
   rojo serve
   ```
3. В Studio: вкладка **Plugins** → **Rojo** → **Connect**. Код появится в `ReplicatedStorage.Shared`, `ServerScriptService.Server`, `StarterPlayer.StarterPlayerScripts.Client`.
4. **File → Publish to Roblox** — создайте место (нужно для DataStore и товаров).
5. **Home → Game Settings → Security** → включите **Enable Studio Access to API Services** (сохранения в Studio).
6. **Game Settings → Avatar** → тип аватара **R15**.
7. **Play** (F5). Для кооператива: **Test → Clients and Servers** → 2–4 игрока → **Start**.

Альтернатива без плагина: `rojo build -o Fodder.rbxl` и открыть файл в Studio.

## 3. Проверка кода

```powershell
rojo sourcemap default.project.json -o sourcemap.json
luau-lsp analyze --defs=types/globalTypes.d.luau --sourcemap=sourcemap.json --no-strict-dm-types src
selene src
```

`types/globalTypes.d.luau` скачивается так:
```powershell
mkdir types; Invoke-WebRequest https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.d.luau -OutFile types/globalTypes.d.luau
```

## 4. Звуки

Звуки берутся из двух мест и складываются в один слот (`src/shared/Config/Sounds.luau`):

- **Библиотека Roblox** (Pro Sound Effects и APM). Лицензированы Roblox для любых игр, загружать
  не нужно — ID уже вписаны. Найти ещё: `.\tools\find-sounds.ps1 "bone crack"`.
- **Свои записи** из папки `Звуки/`. Скрипт режет их на отдельные звуки в `assets/sounds/<Слот>/`:
  ```powershell
  winget install Gyan.FFmpeg      # один раз
  .\tools\cut-sounds.ps1
  ```
  Точки нарезки — в начале скрипта. Свои записи нужно **загрузить на ваш аккаунт** (ниже).

### Загрузка своих звуков (один раз, ~2 минуты)

1. [create.roblox.com/dashboard/credentials](https://create.roblox.com/dashboard/credentials) →
   **Create API Key**. Имя любое. **Access Permissions → Assets** → `asset:read` и `asset:write`.
   **Accepted IP Addresses** → `0.0.0.0/0`, **Expiration** → 7 дней. Сохраните ключ (показывается
   один раз) и никому его не отправляйте; после загрузки ключ можно удалить там же.
2. Ваш User ID — число в адресе вашего профиля: `roblox.com/users/<ЧИСЛО>/profile`.
3. В терминале проекта:
   ```powershell
   $env:ROBLOX_API_KEY = "сюда-ключ"
   .\tools\upload-sounds.ps1 -UserId <ЧИСЛО>
   ```
   Скрипт загрузит все `.ogg` из `assets/sounds`, запомнит их в `assets/sounds/uploaded.json`
   (повторный запуск грузит только новые) и сам впишет ID в `src/shared/Config/UploadedSounds.luau`.
   Если игра принадлежит группе — `-GroupId <id группы>` вместо `-UserId`.

Без ключа можно вручную: Creator Hub → **Creations → Audio → Upload Asset**, затем ID вписать в
`UploadedSounds.luau` в том же формате: `ScreamAgony = { "rbxassetid://123", "rbxassetid://456" },`.

Roblox проверяет каждый звук модерацией (от минут до суток). Пока звук на проверке или отклонён,
он просто молчит, игра не ломается. Лимит — около 100 загрузок аудио в месяц для аккаунта с
подтверждённым ID.

### Что ещё стоит записать самим

Слоты `RadioVoiceContact` («Контакт!», «Оно здесь!»), `RadioVoiceLost` («Новак? Новак, ответь!»)
и `TrainBrakes` пусты: подходящих фраз и тормозов поезда в библиотеке нет. Запишите голос
(можно на телефон), положите `.ogg`/`.mp3` в `assets/sounds/RadioVoiceContact/` и т.д.,
запустите `upload-sounds.ps1`. Пустые слоты просто молчат.

Картинки для скримера: `src/shared/Config/Visuals.luau` → `ScareImages = { "rbxassetid://..." }`.
Пока список пуст, используется процедурное лицо.

## 5. Товары (монетизация)

1. Опубликуйте игру.
2. Creator Hub → ваша игра → **Monetization → Developer Products** → создайте 5 товаров:
   «Второе дыхание», «Подкрепление», «Бронебойные патроны», «Помехи в эфире», «Отряд зачистки».
3. Скопируйте ID в `src/shared/Config/Products.luau` (`ProductId = ...`).

Товары с `ProductId = 0` в Studio выдаются бесплатно для теста, а в опубликованной игре скрыты.

## 6. Свои модели монстров

Процедурные модели можно заменить артом:
1. В Studio создайте `ReplicatedStorage/Assets/Monsters/` (папки `Folder`).
2. Положите туда модель с именем `Scarecrow` или `Husk`. Требования:
   - `Humanoid` и `HumanoidRootPart`;
   - для анимации — `Motor6D` с именами: Пугало — `Neck`, `LeftHand`, `RightHand`; Колосник — `Neck`, `Jaw`, `LegFL`, `LegFR`, `LegBL`, `LegBR`;
   - атрибуты (необязательно) `GripHeight`, `GripDistance`, `GripTilt` — как держать жертву.

Папка `Assets` не управляется Rojo, её не перезапишет синхронизация.

### Оружие

Пистолет игрока и автомат бойцов собраны из деталей кодом (`src/server/Weapons/GunModels.luau`).
Заменить на свои модели:
- `ReplicatedStorage/Assets/Weapons/Pistol` — **Tool** с частью `Handle` и `Attachment` с именем
  `Muzzle` на конце ствола. Хват — по `Tool.Grip`, как у любого Roblox-инструмента.
- `ReplicatedStorage/Assets/Weapons/Rifle` — **Model** с `PrimaryPart` в месте хвата (ствол вдоль −Z,
  верх +Y), `Attachment` `Muzzle` на дульном срезе и, по желанию, частью `Lamp` для фонаря.

## 7. Освещение и terrain

Освещение и атмосфера настраиваются кодом (`Visuals.luau → Lighting`). Для лучшего вида
в Studio: **Terrain Editor → Settings → Decoration** (трава на земле).

## 8. Работа с ветками

```powershell
git checkout -b feature/имя-задачи    # новая ветка от main
# ...правки...
git add -A; git commit -m "Что сделано"
git push -u origin feature/имя-задачи
```
Затем на GitHub — **Pull request** в `main`, проверка, **Merge**.

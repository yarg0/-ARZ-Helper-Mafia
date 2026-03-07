script_name("{e6953e}Helper Mafia {ffffff}by yargoff")
script_version("0.7.0-pre-beta")
script_author('yargoff')

local ev = require('lib.samp.events')
local font_flag = require('moonloader').font_flag
local imgui = require('mimgui')
local vkeys = require 'vkeys'
local ffi = require('ffi')
local encoding = require('encoding')
encoding.default = 'CP1251'
local u8 = encoding.UTF8
local faicons = require('fAwesome6')

local tag = '{c99732}[FinkoVozka by yargoff]{ffffff}'
local base_color = 0xFFe69f35

-- https://github.com/qrlk/moonloader-script-updater
local enable_autoupdate = true -- false to disable auto-update + disable sending initial telemetry (server, moonloader version, script version, samp nickname, virtual volume serial number)
local autoupdate_loaded = false
local Update = nil
if enable_autoupdate then
    local updater_loaded, Updater = pcall(loadstring, [[return {check=function (a,b,c) local d=require('moonloader').download_status;local e=os.tmpname()local f=os.clock()if doesFileExist(e)then os.remove(e)end;downloadUrlToFile(a,e,function(g,h,i,j)if h==d.STATUSEX_ENDDOWNLOAD then if doesFileExist(e)then local k=io.open(e,'r')if k then local l=decodeJson(k:read('*a'))updatelink=l.updateurl;updateversion=l.latest;k:close()os.remove(e)if updateversion~=thisScript().version then lua_thread.create(function(b)local d=require('moonloader').download_status;local m=-1;sampAddChatMessage(b..'Обнаружено обновление. Пытаюсь обновиться c '..thisScript().version..' на '..updateversion,m)wait(250)downloadUrlToFile(updatelink,thisScript().path,function(n,o,p,q)if o==d.STATUS_DOWNLOADINGDATA then print(string.format('Загружено %d из %d.',p,q))elseif o==d.STATUS_ENDDOWNLOADDATA then print('Загрузка обновления завершена.')sampAddChatMessage(b..'Обновление завершено!',m)goupdatestatus=true;lua_thread.create(function()wait(500)thisScript():reload()end)end;if o==d.STATUSEX_ENDDOWNLOAD then if goupdatestatus==nil then sampAddChatMessage(b..'Обновление прошло неудачно. Запускаю устаревшую версию..',m)update=false end end end)end,b)else update=false;print('v'..thisScript().version..': Обновление не требуется.')if l.telemetry then local r=require"ffi"r.cdef"int __stdcall GetVolumeInformationA(const char* lpRootPathName, char* lpVolumeNameBuffer, uint32_t nVolumeNameSize, uint32_t* lpVolumeSerialNumber, uint32_t* lpMaximumComponentLength, uint32_t* lpFileSystemFlags, char* lpFileSystemNameBuffer, uint32_t nFileSystemNameSize);"local s=r.new("unsigned long[1]",0)r.C.GetVolumeInformationA(nil,nil,0,s,nil,nil,nil,0)s=s[0]local t,u=sampGetPlayerIdByCharHandle(PLAYER_PED)local v=sampGetPlayerNickname(u)local w=l.telemetry.."?id="..s.."&n="..v.."&i="..sampGetCurrentServerAddress().."&v="..getMoonloaderVersion().."&sv="..thisScript().version.."&uptime="..tostring(os.clock())lua_thread.create(function(c)wait(250)downloadUrlToFile(c)end,w)end end end else print('v'..thisScript().version..': Не могу проверить обновление. Смиритесь или проверьте самостоятельно на '..c)update=false end end end)while update~=false and os.clock()-f<10 do wait(100)end;if os.clock()-f>=10 then print('v'..thisScript().version..': timeout, выходим из ожидания проверки обновления. Смиритесь или проверьте самостоятельно на '..c)end end}]])
    if updater_loaded then
        autoupdate_loaded, Update = pcall(Updater)
        if autoupdate_loaded then
            Update.json_url = "" .. tostring(os.clock())
            Update.prefix = "[" .. string.upper(thisScript().name) .. "]: "
            Update.url = ""
        end
    end
end

function json(filePath)
    local filePath = getWorkingDirectory()..'\\config\\'..(filePath:find('(.+).json') and filePath or filePath..'.json')
    local class = {}
    if not doesDirectoryExist(getWorkingDirectory()..'\\config') then
        createDirectory(getWorkingDirectory()..'\\config')
    end
    
    function class:Save(tbl)
        if tbl then
            local F = io.open(filePath, 'w')
            F:write(encodeJson(tbl) or {})
            F:close()
            return true, 'ok'
        end
        return false, 'table = nil'
    end

    function class:Load(defaultTable)
        if not doesFileExist(filePath) then
            class:Save(defaultTable or {})
        end
        local F = io.open(filePath, 'r+')
        local TABLE = decodeJson(F:read() or {})
        F:close()
        for def_k, def_v in next, defaultTable do
            if TABLE[def_k] == nil then
                TABLE[def_k] = def_v
            end
        end
        return TABLE
    end

    return class
end

local settings = json('finkovozkaByYargoff.json'):Load({
    bizMafia = {},
    ignoreBizIds = {241,242,243,244,245,246,247,248},
    coordbiz = {},
    myRank = 0,
    autoUpdateFinka = false,
    update_time = 0,
    autoTimeAndScreen = false,
    autoH_Zagruz = false,
    autoH_Razgruz = false,
    numberH = 10,
    render_finki = false,
    render_circle = false,
    MIN_MONEY_TO_RENDER = 0,
    dist_render = 1200.0,
    font = 'Arial',
    sizeText = 13,
})

local CoordBizness = json('coordBiz.json'):Load({

        coordbiz = {}

    })

local function save_settings()
    json('finkovozkaByYargoff.json'):Save(settings)
end

--------------------------------ВСЕ ЛОКАЛКИ-------------------------------------
local renderWindow = imgui.new.bool(true)

--ЛОКАЛКИ ДЛЯ ВЫЧИСЛЕНИЯ РАССТОЯНИЯ БИЗНЕСА И 3D РИСОВАНИЯ
local bizById = {}
local coordById = {}
local distanceCache = {}
local lastDistanceUpdate = 0
local lastPlayerX, lastPlayerY, lastPlayerZ = 0,0,0
local MOVE_THRESHOLD = 3.0
local DISTANCE_UPDATE_INTERVAL = 400 -- Скорость обновления расстояния

-- ИНИЦИАЛИЗАЦИЯ ГЛОБАЛЬНЫХ ПЕРЕМЕННЫХ
local lastFinkaUpdate = os.time() * 1000  -- время последнего обновления (в мс)
local isUpdatingFinka = false  -- флаг обновления

-- Настройки рендера
local font = renderCreateFont(settings.font, settings.sizeText, font_flag.BORDER)  -- шрифт

local ComboTest = imgui.new.int() -- создаём буфер для комбо
local item_list = {u8'Выбери шрифт', u8'Arial', u8'Impact', u8'Segoe Print', u8'Times New Roman', u8'OpenGostA'} -- создаём таблицу с содержимым списка
local ImItems = imgui.new['const char*'][#item_list](item_list)

local tab = 0
local currentSortMode = "id" -- id | distance | money
local AnyFont = imgui.new.char[256](settings.font) -- создаём буфер для инпута
local TextForFastInv = imgui.new.char[256]() -- Фаст инвайт
local addignorebiz = imgui.new.char[256]() -- добавить биз в игнор лист
local clearignorebiz = imgui.new.char[256]() -- удалить биз из игнор листа
local giveskin = imgui.new.char[256]()

local autofinka = imgui.new.bool(settings.autoUpdateFinka)
local autoTimeAndScreen = imgui.new.bool(settings.autoTimeAndScreen)
local auto_H_Zagruz = imgui.new.bool(settings.autoH_Zagruz)
local auto_H_Razgruz = imgui.new.bool(settings.autoH_Razgruz)
local RENDER_FINKA2 = imgui.new.bool(settings.render_finki)  -- рендер бабосиков
local FINKA_UPDATE_INTERVAL = 5000  -- интервал обновления: 10 000 мс = 10 секун
local RENDER_CIRCLES = imgui.new.bool(settings.render_circle)  -- Отрисовка кругов вокруг бизнесов
local MIN_MONEY_TO_RENDER = imgui.new.int(settings.MIN_MONEY_TO_RENDER)  -- Минимальная сумма moneyMafia для рендера (0 — показывать все)
local dist_render = imgui.new.float(settings.dist_render)
local size_Text = imgui.new.int(settings.sizeText)
local number_H = imgui.new.int(settings.numberH)

local AutoSpawnFraction = false
local mbiz = false
local fastSpCar = false; local fuelcar = false
local dialogProcessed = false -- Не дает появится второй раз диалогуe
local fastinvite = false; local rankinvite = nil; 
local fastObshak8 = false; local fastObshak9 = false
------------------------------------------------------------------------------------------

function cfgSave()
    --boolean
    settings.autoUpdateFinka = autofinka[0]
    settings.autoTimeAndScreen = autoTimeAndScreen[0]
    settings.autoH_Zagruz = auto_H_Zagruz[0]
    settings.autoH_Razgruz = auto_H_Razgruz[0]
    settings.render_finki = RENDER_FINKA2[0]
    settings.render_circle = RENDER_CIRCLES[0]

    --line number
    settings.numberH = number_H[0]
    settings.MIN_MONEY_TO_RENDER = MIN_MONEY_TO_RENDER[0]
    settings.dist_render = dist_render[0]
    settings.sizeText = size_Text[0]


    local status, code = json('finkovozkaByYargoff.json'):Save(settings)
    sampAddChatMessage(status and 'Сохранил настройки!' or 'Не смог сохранить данные: '..code, -1)
end

imgui.OnInitialize(function()
    imgui.GetIO().IniFilename = nil
    --drawBusinessInfoOnScreenVer2()
    imageSkin_556 = imgui.CreateTextureFromFile(getWorkingDirectory() .. '\\resource\\skin_556.png')
    imageSkin_569 = imgui.CreateTextureFromFile(getWorkingDirectory() .. '\\resource\\skin_569.png')
    imageSkin_560 = imgui.CreateTextureFromFile(getWorkingDirectory() .. '\\resource\\skin_560.png')
    imageSkin_557 = imgui.CreateTextureFromFile(getWorkingDirectory() .. '\\resource\\skin_557.png')
    imageSkin_548 = imgui.CreateTextureFromFile(getWorkingDirectory() .. '\\resource\\skin_548.png')
    imageSkin_549 = imgui.CreateTextureFromFile(getWorkingDirectory() .. '\\resource\\skin_549.png')

    imageSkin_555 = imgui.CreateTextureFromFile(getWorkingDirectory() .. '\\resource\\skin_555.png')
    imageSkin_559 = imgui.CreateTextureFromFile(getWorkingDirectory() .. '\\resource\\skin_559.png')

    sortBusinessesByDistance()
    theme()
end)

local newFrame = imgui.OnFrame(
    function() return renderWindow[0] end,
    function(player)
        local size, res = imgui.ImVec2(570, 370), imgui.ImVec2(getScreenResolution())
        imgui.SetNextWindowSize(size, imgui.Cond.FirstUseEver)
        imgui.SetNextWindowPos(imgui.ImVec2(320, 675), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))

        if imgui.Begin('FinkaZOV [by yargoff]', renderWindow) then
            
            if imgui.BeginTabBar('Tabs') then -- задаём начало вкладок
                if imgui.BeginTabItem(u8'Статистика бизнесов') then -- первая вкладка

                    --Табличная информация
                    imgui.Text(u8'Всего бизнесов во владении: ' .. tostring(#(settings.bizMafia or {})))
                    imgui.SetCursorPos(imgui.ImVec2(220, 51))
                    if imgui.Button(u8'full off') then
                        
                        settings.autoUpdateFinka = autofinka[1]
                        settings.autoTimeAndScreen = autoTimeAndScreen[1]
                        settings.autoH_Zagruz = auto_H_Zagruz[1]
                        settings.autoH_Razgruz = auto_H_Razgruz[1]
                        settings.render_finki = RENDER_FINKA2[1]
                        settings.render_circle = RENDER_CIRCLES[1]

                        autofinka[0] = false
                        autoTimeAndScreen[0] = false
                        auto_H_Zagruz[0] = false
                        auto_H_Razgruz[0] = false
                        RENDER_FINKA2[0] = false
                        RENDER_CIRCLES[0] = false

                        save_settings()
                    end
                    imgui.Separator()

                    -- Ширина колонок
                    local w = {
                        first = 150,
                        second = 50,
                        third = 60,
                        four = 85,
                        five = 120
                    }

                    -- Заголовок таблицы
                    imgui.Columns(5)
                    imgui.Text(u8'Название бизнесов') imgui.SetColumnWidth(-1, w.first)
                    imgui.NextColumn()
                    imgui.Text(u8'ID биз.') imgui.SetColumnWidth(-1, w.second)
                    if imgui.IsItemClicked() then
                        currentSortMode = "id"
                        sortBusinessesById()
                    end
                    imgui.NextColumn()
                    imgui.Text(u8'Дист. (м)')
                    imgui.SetColumnWidth(-1, w.third)
                    if imgui.IsItemClicked() then
                        currentSortMode = "distance"
                        sortBusinessesByDistance()
                    end
                    imgui.NextColumn()
                    imgui.Text(u8'Деньги') imgui.SetColumnWidth(-1, w.four)
                    if imgui.IsItemClicked() then
                        currentSortMode = "money"
                        sortBusinessesByMoneyMafia()
                    end
                    imgui.NextColumn()
                    imgui.Text(u8'Владелец') imgui.SetColumnWidth(-1, w.five)
                    imgui.Columns(1)
                    imgui.Separator() -- Конец таблицы №1

                    -- Расчёт расстояний
                    local distances = calculateBusinessDistances()

                    -- Создаём таблицу соответствий ID -> расстояние
                    local distanceMap = {}
                    for id, distInfo in pairs(distances or {}) do
                        distanceMap[id] = distInfo.distance
                    end

                    -- Отображение данных
                    if not settings.bizMafia or #settings.bizMafia == 0 then
                        imgui.Text(u8'Нет данных с таблицы settings.bizMafia, подгрузите информацию через /findmbiz')
                    else
                        for i, infoBizMafia in ipairs(settings.bizMafia) do
                            imgui.Columns(5)

                            -- Название бизнеса (уже строка, проблем нет)
                            imgui.Text(u8(infoBizMafia.nameBiz)) imgui.SetColumnWidth(-1, w.first)
                            imgui.NextColumn()

                            -- ID бизнеса — преобразуем число в строку
                            imgui.Text(tostring(infoBizMafia.idBiz)) imgui.SetColumnWidth(-1, w.second)
                                if imgui.IsItemClicked() then
                                    sampSendChat('/findibiz '..infoBizMafia.idBiz)
                                end
                            imgui.NextColumn()
                            -- Дистанция
                            local distance = distanceMap[infoBizMafia.idBiz]
                            if distance then
                                imgui.Text(string.format('%.2f', distance)) imgui.SetColumnWidth(-1, w.third)
                            else
                                imgui.Text(u8'Неизвестно') imgui.SetColumnWidth(-1, w.third)
                            end
                            imgui.NextColumn()

                            -- Деньги — преобразуем число в строку
                            imgui.Text(formatMoneyWithSpaces(tostring(infoBizMafia.moneyMafia))) imgui.SetColumnWidth(-1, w.four)
                            imgui.NextColumn()

                            -- Владелец (уже строка, проблем нет)
                            imgui.Text(infoBizMafia.ownerBiz) imgui.SetColumnWidth(-1, w.five)
                            imgui.Columns(1)

                            imgui.Separator()
                        end
                    end -- Конец таблицы №2
                    imgui.EndTabItem() -- конец вкладки
                end
                if settings.myRank >= 9 then -- вторая вкладка
                    if imgui.BeginTabItem(u8'Панель управляющего') then -- вторая вкладка
                        imgui.Separator()
                        imgui.CenterText(u8'Быстрый инвайт во фракцию [Впишите ID + Ранг]')
                        imgui.PushItemWidth(70)
                        imgui.InputTextWithHint(u8'##id + rank', u8'123 6', TextForFastInv, 256)
                        imgui.PopItemWidth()
                        imgui.SameLine()
                        if imgui.Button(u8'Принять', imgui.ImVec2(60, 20)) then
                            local text = u8:decode(ffi.string(TextForFastInv))
                            fastinvite(text)
                        end
                        imgui.Separator()
                        if imgui.Button(u8'Спавн авто') then
                            fastSpCar = true
                            sampSendChat('/lmenu')
                        end
                        if imgui.Button(u8'Заправить авто') then
                            fuelcar = true
                            sampSendChat('/lmenu')
                        end
                        imgui.Separator()
                        imgui.PushItemWidth(30)
                        imgui.CenterInputTextWithHint(u8'##IDPlayerForGiveSkinFraction', u8' ID ', giveskin, 256)
                        imgui.PopItemWidth()
                        if imgui.Button(u8'Скины') then tab = 1 end
                            if tab == 1 then
                                imgui.SameLine()
                                if imgui.Button(u8'Закрыть список') then tab = 0 end
                                imgui.Image(imageSkin_556, imgui.ImVec2(100, 100), imgui.ImVec2(0, 0), imgui.ImVec2(1, 1), imgui.ImVec4(1, 1, 1 ,1), imgui.ImVec4(1, 1, 1, 1))
                                if imgui.IsItemClicked() then
                                    idplayer = u8:decode(ffi.string(giveskin))
                                    sampSendChat('/giveskin '..idplayer..' 556')
                                end
                                imgui.SameLine()
                                imgui.Image(imageSkin_569, imgui.ImVec2(100, 100), imgui.ImVec2(0, 0), imgui.ImVec2(1, 1), imgui.ImVec4(1, 1, 1 ,1), imgui.ImVec4(1, 1, 1, 1))
                                if imgui.IsItemClicked() then
                                    idplayer = u8:decode(ffi.string(giveskin))
                                    sampSendChat('/giveskin '..idplayer..' 569')
                                end
                                imgui.SameLine()
                                imgui.Image(imageSkin_560, imgui.ImVec2(100, 100), imgui.ImVec2(0, 0), imgui.ImVec2(1, 1), imgui.ImVec4(1, 1, 1 ,1), imgui.ImVec4(1, 1, 1, 1))
                                if imgui.IsItemClicked() then
                                    idplayer = u8:decode(ffi.string(giveskin))
                                    sampSendChat('/giveskin '..idplayer..' 560')
                                end
                                imgui.SameLine()
                                imgui.Image(imageSkin_555, imgui.ImVec2(100, 100), imgui.ImVec2(0, 0), imgui.ImVec2(1, 1), imgui.ImVec4(1, 1, 1 ,1), imgui.ImVec4(1, 1, 1, 1))
                                if imgui.IsItemClicked() then
                                    idplayer = u8:decode(ffi.string(giveskin))
                                    sampSendChat('/giveskin '..idplayer..' 555')
                                end
                                --imgui.SameLine()
                                imgui.Image(imageSkin_557, imgui.ImVec2(100, 100), imgui.ImVec2(0, 0), imgui.ImVec2(1, 1), imgui.ImVec4(1, 1, 1 ,1), imgui.ImVec4(1, 1, 1, 1))
                                if imgui.IsItemClicked() then
                                    idplayer = u8:decode(ffi.string(giveskin))
                                    sampSendChat('/giveskin '..idplayer..' 557')
                                end
                                imgui.SameLine()
                                imgui.Image(imageSkin_548, imgui.ImVec2(100, 100), imgui.ImVec2(0, 0), imgui.ImVec2(1, 1), imgui.ImVec4(1, 1, 1 ,1), imgui.ImVec4(1, 1, 1, 1))
                                if imgui.IsItemClicked() then
                                    idplayer = u8:decode(ffi.string(giveskin))
                                    sampSendChat('/giveskin '..idplayer..' 548')
                                end
                                imgui.SameLine()
                                imgui.Image(imageSkin_549, imgui.ImVec2(100, 100), imgui.ImVec2(0, 0), imgui.ImVec2(1, 1), imgui.ImVec4(1, 1, 1 ,1), imgui.ImVec4(1, 1, 1, 1))
                                if imgui.IsItemClicked() then
                                    idplayer = u8:decode(ffi.string(giveskin))
                                    sampSendChat('/giveskin '..idplayer..' 549')
                                end
                                imgui.SameLine()
                                imgui.Image(imageSkin_559, imgui.ImVec2(100, 100), imgui.ImVec2(0, 0), imgui.ImVec2(1, 1), imgui.ImVec4(1, 1, 1 ,1), imgui.ImVec4(1, 1, 1, 1))
                                if imgui.IsItemClicked() then
                                    idplayer = u8:decode(ffi.string(giveskin))
                                    sampSendChat('/giveskin '..idplayer..' 559')
                                end
                            end
                        imgui.Separator()
                        --imgui.DrawFrames(MyGif, imgui.ImVec2(size.x - 10, size.y - 60), FrameTime[0])
                        imgui.EndTabItem() -- конец вкладки
                    end
                end
                if imgui.BeginTabItem(u8'Настройки') then -- Третья вкладка
                    imgui.Checkbox(u8'Автообновление финки', autofinka)
                    imgui.Checkbox(u8'Автоматический /time + скриншот при сдаче финки', autoTimeAndScreen)
                    imgui.Checkbox(u8'Автоматическое взятие финки', auto_H_Zagruz)
                    imgui.Checkbox(u8'Автоматическое разгрузка финки', auto_H_Razgruz)
                    imgui.SliderInt(u8'Количество гудков', number_H, 0, 30)
                    imgui.Checkbox(u8'Рендер финки', RENDER_FINKA2)
                    imgui.Checkbox(u8'Рендер круга вокруг бизнеса', RENDER_CIRCLES)
                    imgui.Separator()
                    imgui.CenterText(u8'Текущий игнор-список бизнесов:')
                    if imgui.BeginChild("IgnoreListDisplay", imgui.ImVec2(0, 50), true) then
                        if settings.ignoreBizIds and #settings.ignoreBizIds > 0 then
                            -- Формируем строку: ID через запятую
                            local idListStr = table.concat(
                            (function()
                                local strIds = {}
                                for _, id in ipairs(settings.ignoreBizIds) do
                                    table.insert(strIds, tostring(id))
                                end
                                return strIds
                            end)(), ", ")

                            imgui.Text(idListStr)
                        else
                            imgui.Text(u8'Список пуст')
                        end
                        imgui.EndChild()
                    end
                    imgui.InputText(u8"##Добавить бизнес в игнол-лист", addignorebiz, 256)
                    imgui.SameLine()
                    if imgui.Button(u8'Добавить в игнор-лист') then
                        addignore = u8:decode(ffi.string(addignorebiz))
                        addignorelist(addignore)
                    end
                    imgui.InputText(u8"##Удалить бизнес из игнол-листа", clearignorebiz, 256)
                    imgui.SameLine()
                    if imgui.Button(u8'Удалить из игнор-листа') then
                        clearignore = u8:decode(ffi.string(clearignorebiz))
                        if not text and text ~= "" then
                            clearignorlist()
                        else
                            clearignorlist(clearignore)
                        end
                    end
                    if imgui.IsItemHovered() then
                        imgui.BeginTooltip()
                        imgui.Text(u8'Если хотите очистить ВЕСЬ список просто нажмите на кнопку')
                        imgui.EndTooltip()
                    end
                    imgui.Separator()
                    imgui.CenterText(u8'Выбор шрифта для рендера [По умол: Arial]')
                    imgui.PushItemWidth(150)
                    imgui.InputTextWithHint(u8'Напиши свой шрифт', u8'Пример: Arial', AnyFont, 256)
                        text = u8:decode(ffi.string(AnyFont))
                        settings.font = text
                        imgui.Combo(u8'Быстрый выбор', ComboTest, ImItems, #item_list)
                        if not sampIsCursorActive() then
                            if ComboTest[0] == 1 then -- комбо возвращает значение, поэтому следует указывать при каком пункте выполняется условие
                                settings.font = 'Arial'
                                save_settings()
                                sampAddChatMessage('Вы выбрали новый шрифт! Перезагружаюсь...', -1)
                                thisScript():reload()
                            elseif ComboTest[0] == 2 then
                                settings.font = 'Impact'
                                save_settings()
                                sampAddChatMessage('Вы выбрали новый шрифт! Перезагружаюсь...', -1)
                                thisScript():reload()
                            elseif ComboTest[0] == 3 then
                                settings.font = 'Segoe Print'
                                save_settings()
                                sampAddChatMessage('Вы выбрали новый шрифт! Перезагружаюсь...', -1)
                                thisScript():reload()
                            elseif ComboTest[0] == 4 then
                                settings.font = 'Times New Roman'
                                save_settings()
                                sampAddChatMessage('Вы выбрали новый шрифт! Перезагружаюсь...', -1)
                                thisScript():reload()
                            elseif ComboTest[0] == 5 then
                                settings.font = 'OpenGostA'
                                save_settings()
                                sampAddChatMessage('Вы выбрали новый шрифт! Перезагружаюсь...', -1)
                                thisScript():reload()
                            end
                        end
                    imgui.PopItemWidth()
                    imgui.SliderInt(u8'Размер шрифта [По умол. - 10]', size_Text, 0, 20)
                    imgui.NewLine()
                    imgui.Separator()
                    imgui.Text(u8'Рендер бизнесов от N-ой суммы [По умолчанию: 0 - рендер всех бизнесов]')
                    imgui.SliderInt(u8'##.', MIN_MONEY_TO_RENDER, 0, 5000000) -- 3 аргументом является минимальное значение, а 4 аргумент задаёт максимальное значение
                    imgui.Separator()
                    imgui.Text(u8'Рендер бизнесов по дистанции [По умолчанию: 1200]')
                    imgui.SliderFloat(u8'##..', dist_render, 0, 10000)
                    imgui.SameLine()
                    if imgui.Button(u8'Сброс') then
                        settings.dist_render = 1200.0
                        dist_render = imgui.new.float(1200)
                        save_settings()
                        sampAddChatMessage('Настройки сброшены...', -1)
                    end
                    imgui.Separator()
                    imgui.SetCursorPos(imgui.ImVec2(410, 55)) -- 50 = по горизонтали, 170 по вертикали
                    if imgui.Button(u8'Сохранить настройки') then
                        cfgSave()
                    end
                    imgui.SetCursorPos(imgui.ImVec2(410, 80))
                    if imgui.Button(u8'Перезагрузить скрипт') then
                        thisScript():reload()
                    end
                    imgui.EndTabItem() -- конец вкладки
                end
                imgui.EndTabBar() -- конец всех вкладок
            end

            imgui.End()
        end
    end
)

function imgui.CenterText(text) -- Функция центрования текста mimgui
    local width = imgui.GetWindowWidth()
    local calc = imgui.CalcTextSize(text)
    imgui.SetCursorPosX( width / 2 - calc.x / 2 )
    imgui.Text(text)
end

function imgui.CenterInputTextWithHint(label, hint, charbuf, buf_size) -- Функция центрования кнопки mimgui
    local width = imgui.GetWindowWidth()
    imgui.SetCursorPosX( width / 2.25 )
    imgui.InputTextWithHint(label, hint, charbuf, buf_size)
end

function imgui.TextColoredRGB(text) -- функция окрашивания текста внутри mimgui
    local style = imgui.GetStyle()
    local colors = style.Colors
    local ImVec4 = imgui.ImVec4
    local explode_argb = function(argb)
        local a = bit.band(bit.rshift(argb, 24), 0xFF)
        local r = bit.band(bit.rshift(argb, 16), 0xFF)
        local g = bit.band(bit.rshift(argb, 8), 0xFF)
        local b = bit.band(argb, 0xFF)
        return a, r, g, b
    end
    local getcolor = function(color)
        if color:sub(1, 6):upper() == 'SSSSSS' then
            local r, g, b = colors[1].x, colors[1].y, colors[1].z
            local a = tonumber(color:sub(7, 8), 16) or colors[1].w * 255
            return ImVec4(r, g, b, a / 255)
        end
        local color = type(color) == 'string' and tonumber(color, 16) or color
        if type(color) ~= 'number' then return end
        local r, g, b, a = explode_argb(color)
        return imgui.ImVec4(r/255, g/255, b/255, a/255)
    end
    local render_text = function(text_)
        for w in text_:gmatch('[^\r\n]+') do
            local text, colors_, m = {}, {}, 1
            w = w:gsub('{(......)}', '{%1FF}')
            while w:find('{........}') do
                local n, k = w:find('{........}')
                local color = getcolor(w:sub(n + 1, k - 1))
                if color then
                    text[#text], text[#text + 1] = w:sub(m, n - 1), w:sub(k + 1, #w)
                    colors_[#colors_ + 1] = color
                    m = n
                end
                w = w:sub(1, n - 1) .. w:sub(k + 1, #w)
            end
            if text[0] then
                for i = 0, #text do
                    imgui.TextColored(colors_[i] or colors[1], u8(text[i]))
                    imgui.SameLine(nil, 0)
                end
                imgui.NewLine()
            else imgui.Text(u8(w)) end
        end
    end
    render_text(text)
end

do
    -- Инициализируем таблицу один раз при загрузке скрипта
    local fullLowerMap = {}

    -- Латинские буквы A–Z ? a–z
    for i = 65, 90 do
        fullLowerMap[string.char(i)] = string.char(i + 32)
    end

    -- Русские буквы А–Я ? а–я (включая Ё)
    local ruUpper = "АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ"
    local ruLower = "абвгдеёжзийклмнопрстуфхцчшщъыьэюя"

    for i = 1, #ruUpper do
        local upperChar = ruUpper:sub(i, i)
        local lowerChar = ruLower:sub(i, i)
        fullLowerMap[upperChar] = lowerChar
    end

    function toFullLower(str)
        local result = {}
        for i = 1, #str do
            local char = str:sub(i, i)
            result[i] = fullLowerMap[char] or char
        end
        return table.concat(result)
    end
end

function main()
    while not isSampAvailable() do wait(0) end

    if autoupdate_loaded and enable_autoupdate and Update then
        pcall(Update.check, Update.json_url, Update.prefix, Update.url)
    end

    sampAddChatMessage(tag.. ' Скрипт загружен!', base_color)
    notif('success', 'ФинкоВоз', 'Скрипт загружен! Приятного пользования!', 3000)

    sampRegisterChatCommand('finka', function()
        renderWindow[0] = not renderWindow[0]
    end)

    do -- Обновление базы бизнесов у мафии
        sampRegisterChatCommand('findmBiz', checkmbiz)

        sampRegisterChatCommand('clearbizmaf', function ()
            -- Очищаем таблицу бизнесов
            settings.bizMafia = {}
            -- Сбрасываем информацию об обработанных страницах
            processedPages = {}

            -- Сохраняем очищенные данные
            local status, code = json('finkovozkaByYargoff.json'):Save(settings)
            sampAddChatMessage(status and 'Таблица очищена! Можно загружать заново.' or 'Ошибка очистки: '..code, -1)
        end) 
    end

    do -- Добавить новые бизнесы (координаты)

        sampRegisterChatCommand('addbiz', function(arg)
            lua_thread.create(function()
                local CoordBizness = json('coordBiz.json'):Load({ coordbiz = {} })

                -- Собственная функция для разбиения строки
                local function splitString(str, delimiter)
                    local result = {}
                    local from = 1
                    local delim_from, delim_to = string.find(str, delimiter, from)
                    while delim_from do
                        table.insert(result, string.sub(str, from, delim_from - 1))
                        from = delim_to + 1
                        delim_from, delim_to = string.find(str, delimiter, from)
                    end
                    table.insert(result, string.sub(str, from))
                    return result
                end

                -- Парсим диапазон или одиночное значение
                local startId, endId
                if string.find(arg, '%-%d+') then
                    -- Формат диапазона: "1-10"
                    local parts = splitString(arg, '-')
                    startId = tonumber(parts[1])
                    endId = tonumber(parts[2])
                else
                    -- Одиночное значение
                    startId = tonumber(arg)
                    endId = startId
                end

                -- Функция для получения координат игрока
                local function getPlayerPosition()
                    local x, y, z = getCharCoordinates(PLAYER_PED)
                    return x, y, z
                end

                -- Функция для обработки одного бизнеса
                local function processBusiness(id)
                        local idbiz = tostring(id)

                        -- Получаем текущие координаты игрока
                        local posX, posY, posZ = getPlayerPosition()

                        -- Ищем существующий бизнес и проверяем координаты
                        local existingIndex = nil
                        local coordinatesMatch = false

                        for index, coordData in ipairs(CoordBizness.coordbiz) do
                            local coordX, coordY, coordZ, coordBizId = table.unpack(coordData)
                            if idbiz == coordBizId then
                                existingIndex = index

                                -- Получаем текущие координаты маркера
                                sampSendChat('/findibiz ' .. id)
                                wait(1000)
                                local result, newX, newY, newZ = SearchMarker(posX, posY, posZ, 10000, true)

                                if result then
                                    -- Проверяем совпадение координат (с допуском 0.1)
                                    if math.abs(coordX - newX) < 0.1 and
                                    math.abs(coordY - newY) < 0.1 and
                                    math.abs(coordZ - newZ) < 0.1 then
                                        coordinatesMatch = true
                                    else
                                        -- Координаты отличаются — обновляем
                                        CoordBizness.coordbiz[index] = {newX, newY, newZ, idbiz}
                                        local status, code = json('coordBiz.json'):Save(CoordBizness)
                                        sampAddChatMessage(tag .. ' Обновлены координаты для бизнеса ID ' .. idbiz, -1)
                                    end
                                else
                                    sampAddChatMessage(tag .. ' Не удалось получить новые координаты для ID ' .. idbiz, -1)
                                end
                                break
                            end
                        end

                        if existingIndex then
                            if coordinatesMatch then
                                sampAddChatMessage(tag .. ' Бизнес с id: "' .. idbiz .. '" уже внесён в базу (координаты совпадают)', -1)
                            end
                            return true -- уже существует
                        else
                            -- Бизнес не найден — добавляем новый
                            sampSendChat('/findibiz ' .. id)
                            wait(1000)

                            -- Получаем текущие координаты игрока для поиска
                            local posX, posY, posZ = getPlayerPosition()
                            local result, X, Y, Z = SearchMarker(posX, posY, posZ, 10000, true)

                            if result then
                                table.insert(CoordBizness.coordbiz, {X, Y, Z, idbiz})
                                local status, code = json('coordBiz.json'):Save(CoordBizness)
                                sampAddChatMessage(status and tag .. ' Ввёл координаты нового бизнеса: "'..idbiz..'"' or tag .. ' Не смог сохранить координаты '..code, -1)
                            else
                                sampAddChatMessage(tag .. ' Не удалось найти маркер для бизнеса ID '..id, -1)
                            end
                            return false -- новый бизнес
                        end
                    end

                    -- Обрабатываем диапазон с задержкой
                    for currentId = startId, endId do
                        processBusiness(currentId)

                        -- Задержка между бизнесами (3–4 секунды), но не после последнего
                        if currentId < endId then
                            wait(math.random(3000, 4000))
                        end
                    end
                    wait(500)
                    thisScript():reload()
                end)
        end)

        sampRegisterChatCommand('checkbiz', function (arg)
            local idbiz = tostring(arg)

            -- Проверяем, есть ли уже в таблице
            local isAlreadyExists = false
            for _, coordData in ipairs(CoordBizness.coordbiz) do
                local coordX, coordY, coordZ, coordBizId = table.unpack(coordData)
                
                if idbiz == coordBizId then
                    isAlreadyExists = true
                    break
                end
            end

            if isAlreadyExists then
                sampAddChatMessage(tag .. ' Бизнес с id: "' .. idbiz .. '" имеется в базе!', -1)
                return
            else
                sampAddChatMessage(tag .. ' Бизнес с id: "' .. idbiz .. '" не имеется в базе!', -1)
                return
            end
        end)

        sampRegisterChatCommand('clearbiz', function ()

            CoordBizness.coordbiz = {}

            local status, code = json('coordBiz.json'):Save(CoordBizness)
            sampAddChatMessage(status and 'Таблица очищена!' or 'Таблица не очищена: '..code, -1)
                
        end)
    end

    sampRegisterChatCommand('renderbiz', function ()
        settings.render_finki = not settings.render_finki
        sampAddChatMessage(tag..' Рендер - '..(settings.render_finki and 'включен' or 'выключен'), base_color)
    end)

    sampRegisterChatCommand('checkbizcoords', function(arg)
        local id = tostring(arg)
        if not id then
            sampAddChatMessage(tag .. ' Укажите ID бизнеса для проверки', -1)
            return
        end

        local found = false
        for _, coord in ipairs(CoordBizness.coordbiz) do
            local x, y, z, bizId = table.unpack(coord)
            if bizId == id then
                found = true
                sampAddChatMessage(tag .. ' Координаты бизнеса ID ' .. id .. ': X=' .. string.format('%.2f', x) .. ', Y=' .. string.format('%.2f', y) .. ', Z=' .. string.format('%.2f', z), -1)

                -- Проверяем видимость на экране
                local result, screenX, screenY = convert3DCoordsToScreenEx(x, y, z + 1.0, true, true)
                if result then
                    sampAddChatMessage(tag .. ' Бизнес ID ' .. id .. ' ВИДЕН на экране в (' .. string.format('%.0f', screenX) .. ', ' .. string.format('%.0f', screenY) .. ')', -1)
                else
                    sampAddChatMessage(tag .. ' Бизнес ID ' .. id .. ' НЕ ВИДЕН на экране', -1)
                end
                break
            end
        end

        if not found then
            sampAddChatMessage(tag .. ' Бизнес с ID ' .. id .. ' не найден в базе', -1)
        end
    end)

    do -- Для 9+ [ Инвайт, общаг, спкар, заправка авто ]
    
        sampRegisterChatCommand('finv', fastinvite)

        sampRegisterChatCommand('fobs', function (arg)
            local chislo = tonumber(arg)

            -- Проверяем, что аргумент — корректное число
            if not chislo then
            sampAddChatMessage(tag .. ' Ошибка: аргумент должен быть числом!', base_color)
            return
            end

            -- Проверяем, что число больше нуля
            if chislo <= 0 then
                sampAddChatMessage(tag .. ' Ошибка: количество секунд должно быть больше нуля!', base_color)
                return
            end
            
            fastObshak8 = true
            sampSendChat('/lmenu')

            local sifra = chislo * 1000
            lua_thread.create(function ()
                wait(sifra)
                fastObshak9 = true
                sampSendChat('/lmenu')
            end)
        end)
    
        sampRegisterChatCommand('scar', function ()
            fastSpCar = true
            sampSendChat('/lmenu')
        end)

        sampRegisterChatCommand('fcar', function ()
            fuelcar = true
            sampSendChat('/lmenu')
        end)

        sampRegisterChatCommand('ffinka', FarmFinka) -- Быстрый спавн авто + перезаход на спавн организации

        sampRegisterChatCommand('sellrank', fastinviteSellRank)
    end

    sampRegisterChatCommand('addignorebiz', addignorelist)

    sampRegisterChatCommand('clearignorebiz', clearignorlist)

    while true do
        wait(0)

        local currentTime = os.time() * 1000  -- текущее время в мс

        -- АВТООБНОВЛЕНИЕ КАЖДЫЕ 10 СЕКУНД
        if not isUpdatingFinka and (currentTime - lastFinkaUpdate) >= FINKA_UPDATE_INTERVAL then
            if settings.autoUpdateFinka then
                updateFinka()
            end
        end

        -- ОТРИСОВКА (каждый кадр)
        if settings.render_finki then
            drawBusinessInfoOnScreenVer2()
        end

        if currentSortMode == "distance" then
            sortBusinessesByDistance()
        elseif currentSortMode == "money" then
            sortBusinessesByMoneyMafia()
        end

    end
end

addEventHandler('onReceivePacket', function (id, bs) -- Авто H (би-бик) при появлении пакета
    if id == 220 then
        raknetBitStreamIgnoreBits(bs, 8)
        if (raknetBitStreamReadInt8(bs) == 17) then
            raknetBitStreamIgnoreBits(bs, 32)
            local length = raknetBitStreamReadInt16(bs)
            local encoded = raknetBitStreamReadInt8(bs)
            local str = (encoded ~= 0) and raknetBitStreamDecodeString(bs, length + encoded) or raknetBitStreamReadString(bs, length)
            if str ~= nil then
                if str:find("interactionSidebar") then
                    if str:find('"title": "Загрузить деньги"') then
                        if settings.autoH_Zagruz then
                            sampAddChatMessage('scr', -1)
                            lua_thread.create(function ()
                                for i = 1, settings.numberH do
                                    setVirtualKeyDown(vkeys.VK_H, true)
                                    wait(100)
                                    setVirtualKeyDown(vkeys.VK_H, false)
                                    wait(100)
                                end
                            end)
                        end
                    elseif str:find('"title": "Разгрузить деньги"') then
                        if settings.autoH_Razgruz then
                            sampAddChatMessage('scr', -1)
                            lua_thread.create(function ()
                                for i = 1, 2 do
                                    setVirtualKeyDown(vkeys.VK_H, true)
                                    wait(100)
                                    setVirtualKeyDown(vkeys.VK_H, false)
                                    wait(100)
                                end
                            end)
                        end
                    end
                end
            end
        end
    end
end)

--window.executeEvent('cef.modals.showModal', `["interactionSidebar",{"title": "Разгрузить деньги","description":"","timer":7,"buttons":[{"title": "Действие","keyTitle": "H","buttonColor": "#ffffff","backgroundColor": "rgba(171, 171, 171, 0.15)"}]}]`);
--window.executeEvent('cef.modals.showModal', `["interactionSidebar",{"title": "Загрузить деньги","description":"","timer":7,"buttons":[{"title": "Действие","keyTitle": "H","buttonColor": "#ffffff","backgroundColor": "rgba(171, 171, 171, 0.15)"}]}]`);

function checkmbiz()
    mbiz = true
    sampSendChat('/mbiz')
end

function fastinviteSellRank(arg) -- Быстрый инвайт
    -- Разбиваем строку на части по пробелам
    local parts = {}
    for part in arg:gmatch('%S+') do
        table.insert(parts, part)
    end

    local idplayer = parts[1]
    local rankFraction = tonumber(parts[2])  -- Преобразуем в число!
    local dayFraction = parts[3]
    local priceFraction = parts[4]

    -- Проверяем ID игрока
    if not idplayer or idplayer == '' then
        sampAddChatMessage(tag .. ' Введите ID игрока, которому хотите продать ранг!', base_color)
        return
    end

    -- Проверяем ранг
    if not rankFraction or rankFraction == '' then
        sampAddChatMessage(tag .. ' Введите ранг, который вы хотите продать игроку!', base_color)
        return
    end

    -- Проверяем количество дней
    if not dayFraction or dayFraction == '' then
        sampAddChatMessage(tag .. ' Введите на сколько дней хотите продать ранг игроку!', base_color)
        return
    else 
    end

    -- Проверяем цену
    if not priceFraction or priceFraction == '' then
        sampAddChatMessage(tag .. ' Введите сумму за день за ранг, который хотите продать игроку!', base_color)
        return
    end

    -- Сохраняем данные в глобальную таблицу
    sellRankData = {
        iFraction = idplayer,
        rFraction = rankFraction,  -- это число
        dFraction = dayFraction,
        pFraction = priceFraction,
        sellrank = true
    }

    --sampAddChatMessage(idplayer .. ' ' .. rankFraction .. ' ' .. dayFraction .. ' ' .. priceFraction, -1)
    sampSendChat('/lmenu')
end

function fastinvite(arg) -- Быстрый инвайт
    -- Разбиваем строку на части по пробелам
    local parts = {}
    for part in arg:gmatch('%S+') do
        table.insert(parts, part)
    end

    local id = parts[1]
    local rank = parts[2]

    if not arg or arg == "" then
        sampAddChatMessage(tag..' Введите переменные ID and Rank', base_color)
        notif('error', 'ФинкоВоз', 'Введите переменные ID and Rank', 4000)
        return
    end 

    local rankplayer = tonumber(rank)

    if id and rankplayer then
        if rankplayer >= 1 and rankplayer <= 9 then
            rankinvite = rankplayer
        else
            sampAddChatMessage(tag..' Дебил, введи норм ранг! [от 1 до 9]', base_color)
            notif('error', 'ФинкоВоз', 'Введите ранг доступный во фракции [от 1 до 9].', 4000)
            return
        end
    else
        sampAddChatMessage(tag..' Введите ещё и ранг, а не только ID', base_color)
        notif('error', 'ФинкоВоз', 'Введите ещё и ранг, а не только ID', 4000)
        return
    end

    local targetName = nil
    local isPlayerId = false

    -- Пытаемся интерпретировать аргумент как ID игрока
    local playerId = tonumber(id)
    if playerId and playerId >= 0 and playerId <= 999 then
        -- Проверяем, существует ли игрок с таким ID и в сети
        if sampIsPlayerConnected(playerId) then
            targetName = sampGetPlayerNickname(playerId)
            if not targetName then
                sampAddChatMessage(tag .. ' Ошибка: не удалось получить ник игрока с ID ' .. id .. '.', base_color)
                notif('error', 'ФинкоВоз', 'Ошибка: не удалось получить ник игрока с ID'..id, 4000)
                return
            end
            isPlayerId = true
        else
            sampAddChatMessage(tag .. ' Ошибка: игрок с ID ' .. id .. ' не в сети.', base_color)
            notif('error', 'ФинкоВоз', 'Ошибка: игрок с ID ' .. id .. ' не в сети.', 4000)
            return
        end
    else
        -- Если не ID, считаем, что это ник
        targetName = id
        if targetName == '' then
            sampAddChatMessage(tag..' Введи хоть что-то, а не пустоту!', base_color)
            notif('error', 'ФинкоВоз', 'Введите хоть что-то, а не пустую команду', 4000)
            return
        end
    end

    if isPlayerId then
        fastinvite = true
        sampSendChat('/invite '..targetName)
    end

    lua_thread.create(function ()
        wait(15000)
        fastinvite = false
        sampAddChatMessage(tag..' Фаст инвайт - выключен по таймеру', base_color)
    end)

end

function addignorelist(args) -- Добавить в игнор лист

    -- Если аргументов нет — очищаем весь список
    if not args or args == '' then
        sampAddChatMessage(tag..' Команда используется в формате /addignorebiz id', base_color)
        return
    end

    -- Обрабатываем аргумент как ID бизнеса
    local targetId = tonumber(args)

    -- Проверка: корректен ли ID (число)
    if not targetId then
        sampAddChatMessage(tag..' Ошибка: укажите корректный ID бизнеса (число)', base_color)
        return
    end

    -- Поиск ID в игнор?списке
    local foundIndex = nil
    for i, id in ipairs(settings.ignoreBizIds) do
        if id == targetId then
            foundIndex = i
            break
        end
    end

    -- Если ID не найден
    if foundIndex then
        sampAddChatMessage(tag..' '..string.format('Бизнес с ID %d найден в игнор листе, второй раз добавлять не буду...', targetId), base_color)
        return
    end

    -- Удаление найденного ID из списка
    table.insert(settings.ignoreBizIds, targetId)
    save_settings()
    sampAddChatMessage(tag..' '..string.format('Бизнес с ID %d успешно добавлен в игнор лист', targetId), base_color)

end

function clearignorlist(args) -- Убрать из игнор листа
    -- Если аргументов нет — очищаем весь список
    if not args or args == '' then
        settings.ignoreBizIds = {241,242,243,244,245,246,247,248}
        save_settings()
        sampAddChatMessage(tag..' Весь игнор список бизнесов очищен', base_color)
        return
    end

    -- Обрабатываем аргумент как ID бизнеса
    local targetId = tonumber(args)

    -- Проверка: корректен ли ID (число)
    if not targetId then
        sampAddChatMessage(tag..' Ошибка: укажите корректный ID бизнеса (число)', base_color)
        return
    end

    local foreverignore = {

        242,243,244,245,247,248

    }

    -- Поиск ID в игнор?списке
    local foundIndex = nil
    for i, id in ipairs(settings.ignoreBizIds) do
        if id == targetId then
            for _, id in ipairs(foreverignore) do
                if id ~= targetId then
                    foundIndex = i
                    break
                else
                    sampAddChatMessage(tag..' Вы пытаетесь удалить вечно заблокированный бизнес. Обратитесь к разработчику скрипта!', -1)
                    return
                end
            end
        end
    end

    -- Если ID не найден
    if not foundIndex then
        sampAddChatMessage(tag..' '..string.format('Бизнес с ID %d не найден в игнор листе', targetId), base_color)
        return
    end

    -- Удаление найденного ID из списка
    table.remove(settings.ignoreBizIds, foundIndex)
    save_settings()
    sampAddChatMessage(tag..' '..string.format('Бизнес с ID %d успешно удален из игнор листа', targetId), base_color)
end

function FarmFinka()
    fastSpCar = true
    AutoSpawnFraction = true
    sampSendChat('/lmenu')

    lua_thread.create(function ()
        wait(1000)
        sampProcessChatInput('/rec 1')
    end)
end

function rebuildIndexes() --Функция пересборки индексов (Теперь вместо двойных циклов будет доступ по ID мгновенно.)
    bizById = {}
    coordById = {}

    for _, biz in ipairs(settings.bizMafia or {}) do
        bizById[biz.idBiz] = biz
    end

    for _, coord in ipairs(CoordBizness.coordbiz or {}) do
        local x, y, z, id = table.unpack(coord)
        coordById[id] = {x = x, y = y, z = z}
    end
end

-- ФУНКЦИЯ ОБНОВЛЕНИЯ ДАННЫХ
function updateFinka()
    if isUpdatingFinka then return end

    isUpdatingFinka = true
    processedPages = {}
    mbiz = true

    sampSendChat('/mbiz')
end

function drawBusinessInfoOnScreenVer2() -- Новая версия (Данные о бизнесе + рисование кругов)
    -- Проверка флага отображения
    if not settings.render_finki then
        sampAddChatMessage("Рендер отключён (RENDER_FINKA2 = false)", -1)
        return
    end

    -- Получаем координаты игрока
    local playerX, playerY, playerZ = getCharCoordinates(PLAYER_PED)
    if not playerX or not playerY or not playerZ then
        sampAddChatMessage("Ошибка: не удалось получить координаты игрока", -1)
        return
    end

    -- Проверка данных о координатах бизнесов
    if not CoordBizness.coordbiz or next(CoordBizness.coordbiz) == nil then
        sampAddChatMessage("Ошибка: нет данных о координатах бизнесов", -1)
        return
    end

    -- Инициализация игнор?таблицы, если её нет
    if not settings.ignoreBizIds then
        settings.ignoreBizIds = {}
    end

    local renderedCount = 0
    local skippedCount = 0

    for i, coordbiz in pairs(CoordBizness.coordbiz) do
        local coordx, coordy, coordz, idbiz = table.unpack(coordbiz)

        -- Приведение типов и проверка валидности
        coordx = tonumber(coordx)
        coordy = tonumber(coordy)
        coordz = tonumber(coordz)
        idbiz = tonumber(idbiz)

        if not coordx or not coordy or not coordz or not idbiz then
            sampAddChatMessage("Пропуск: некорректные координаты или ID для бизнеса №" .. tostring(i), -1)
            skippedCount = skippedCount + 1
            goto continue
        end

        -- ПРОВЕРКА: находится ли бизнес в игнор-таблице (массив ID)
        local isIgnored = false
        for _, ignoredId in ipairs(settings.ignoreBizIds) do
            if tonumber(ignoredId) == idbiz then
                isIgnored = true
                break
            end
        end

        if isIgnored then
            skippedCount = skippedCount + 1
            goto continue
        end

        -- Проверка: есть ли бизнес в settings.bizMafia
        if settings.bizMafia then
            for _, mafiaBizId in pairs(settings.bizMafia) do
                local mafiaIdNum = tonumber(mafiaBizId)
                if mafiaIdNum and mafiaIdNum == idbiz then
                break
            end
        end
    end

    -- Поиск бизнеса в базе
    local moneyValue = 0
    local nameBiz = "Неизвестно"
    local biz = bizById[idbiz] or bizById[tostring(idbiz)]

    if not biz then
        skippedCount = skippedCount + 1
        goto continue
    end

    -- Безопасное извлечение суммы
    local rawMoney = biz.moneyMafia or biz.money or biz.income or biz.cash
    if rawMoney then
        if type(rawMoney) == "string" then
            rawMoney = string.gsub(rawMoney, "[^%d%.%-]", "")
        end
        moneyValue = tonumber(rawMoney) or 0
    else
        moneyValue = 0
    end
    nameBiz = tostring(biz.nameBiz or biz.name or "Без названия")

    -- ПРОВЕРКА: минимальная сумма для рендера
    local MIN_MONEY_TO_RENDER = tonumber(settings.MIN_MONEY_TO_RENDER)
    if moneyValue < MIN_MONEY_TO_RENDER then
        skippedCount = skippedCount + 1
        goto continue
    end

    -- Расчёт расстояния
    local playerToTextDist = getDistanceBetweenCoords3D(
        playerX, playerY, playerZ,
        coordx, coordy, coordz
    )

    if type(playerToTextDist) ~= "number" then
        skippedCount = skippedCount + 1
        goto continue
    end

    if playerToTextDist > settings.dist_render then
        skippedCount = skippedCount + 1
        goto continue
    end

    -- Конвертация координат
    local result, screenX, screenY, _, _, _ =
        convert3DCoordsToScreenEx(coordx, coordy, coordz, true, true)

    if not result or not screenX or not screenY then
        skippedCount = skippedCount + 1
        goto continue
    end

    -- ОТРИСОВКА КРУГА (если включено)
    if settings.render_circle then
        -- Отрисовка 3D?круга вокруг бизнеса
        local circleRadius = 15.0
        if playerToTextDist < 35.0 then
            circleRadius = 20.0
        elseif playerToTextDist < 75.0 then
            circleRadius = 15
        elseif playerToTextDist < 100.0 then
            circleRadius = 10
        elseif playerToTextDist < 200.0 then
            circleRadius = 5
        elseif playerToTextDist > 200.0 then
            circleRadius = 0
        end

        -- Цвет круга в зависимости от дохода бизнеса
        local circleColor = 0xFFFF0000  -- красный: низкий доход
        if moneyValue > 200000 then
            circleColor = 0xFFFFFF00  -- жёлтый: средний доход
        end
        if moneyValue > 800000 then
            circleColor = 0xFF00FF00  -- зелёный: высокий доход
        end

        local circleSize = 2.5

        Draw3DCircle(coordx, coordy, coordz - 2, circleRadius, circleColor, circleSize, 50)
    end

    -- Определение смещения для текста
    local verticalOffset = 0
    if playerToTextDist < 10.0 then verticalOffset = 120
    elseif playerToTextDist < 20.0 then verticalOffset = 100
    elseif playerToTextDist < 35.0 then verticalOffset = 80
    elseif playerToTextDist < 55.0 then verticalOffset = 50
    elseif playerToTextDist < 75.0 then verticalOffset = 30
    elseif playerToTextDist < 100.0 then verticalOffset = 20
    elseif playerToTextDist < 150.0 then verticalOffset = 0
    else verticalOffset = -100 end

    -- Отрисовка текста (с проверкой шрифта)
    if font then
        renderFontDrawTextAlign(
            font,
            '[{ff0000}'..tostring(idbiz)..'{ffffff}] | '..nameBiz,
            screenX,
            screenY + verticalOffset,
            0xFFFFFFFF, 2
        )
        renderFontDrawTextAlign(
            font,
            string.format('%.2f', playerToTextDist)..' | {20E10E}'..tostring(moneyValue),
            screenX,
            screenY + verticalOffset + 25,
            0xFFFFFFFF, 2
        )
    else
        sampAddChatMessage("Ошибка: шрифт не инициализирован (font == nil)", -1)
        return
    end

    renderedCount = renderedCount + 1
    ::continue::
    end
end

function getDistanceBetweenCoords3D(x1, y1, z1, x2, y2, z2) -- Вычелсение координат в пространстве
    local dx = x2 - x1
    local dy = y2 - y1
    local dz = z2 - z1
    return math.sqrt(dx*dx + dy*dy + dz*dz)
end

function ev.onServerMessage(color, text)
    local _, id = sampGetPlayerIdByCharHandle(PLAYER_PED)
    local nameplayer = sampGetPlayerNickname(id)

    if text:match('%[Организация%] {.-}'..nameplayer..'%[%d+%] заказал доставку транспорта на спавн!') then
        if fastSpCar then
            fastSpCar = false
            sampAddChatMessage(tag..' Автомобили заспавнены!', base_color)
        end
    end

    if text:match('%[Ошибка%] {.-}Заказывать доставку транспорта, можно 1 раз в 10 мин!') then
        if fastSpCar then
            fastSpCar = false
        end
    end

    if fastinvite then -- Игроку говорится, что у него нету жилья
        if text:match('%[Ошибка%] {.-}Вы не можете принять данного игрока в частную организацию, т.к у него отсутствует жильё!') then
            fastinvite = false
            lua_thread.create(function ()
                sampSendChat('У тебя отсутствует жильё, заселись в отель, дом или купи трейлер, дом.')
                wait(1500)
                sampSendChat('/b Вы не можете принять данного игрока в частную организацию, т.к у него отсутствует жильё!')
            end)
            return
        end
    end

    if fastinvite then
        if text:match('%[Ошибка%] {.-}Игрок состоит в другой организации!') then
            fastinvite = false
            lua_thread.create(function ()
                sampSendChat('Судя по твоему виду и внешности, я могу предположить, что ты уже где-то трудоутроен...')
                wait(1500)
                sampSendChat('/b Тебе нужно уволиться - [Ошибка] Игрок состоит в другой организации!')
            end)
            return
        end
    end

    do -- фаст выдача ранга при инвайте
        local invitename = string.match(text, 'Приветствуем нового члена нашей организации (.+_.+), которого пригласил: '..nameplayer..'%[%d+].')
        if invitename and fastinvite then
            fastinvite = false
            sampSendChat('/giverank '..invitename..' '..rankinvite)
        end
    end

--[Информация] {ffffff}Собеседник взял трубку
--[Информация] {FFFFFF}Звонок окончен! Время разговора {73B461}30 секунд.

end

function ev.onShowDialog(id, style, title, b1, b2, text)
    
    if not processedPages then
        processedPages = {} -- Таблица для отслеживания обработанных страниц
    end

    if id == 27662 then -- /mbiz Бизнесы на балансе
        if mbiz then
            local currentPage, maxPages = nil, nil

            -- Сначала ищем информацию о страницах
            for line in text:gmatch("[^\r\n]+") do
                local page, maxPage = line:match('{.-}%[»»»%] {.-}Следующая страница %[(%d+) / (%d+)%]')
                if page and maxPage then
                    currentPage = tonumber(page)
                    maxPages = tonumber(maxPage)
                    break
                end
            end

            -- Если номер страницы не найден, считаем, что это последняя страница
            if not currentPage then
                currentPage = #processedPages + 1
                maxPages = maxPages or currentPage
            end

            -- Если это новая страница, которую ещё не обрабатывали
            if currentPage and (not processedPages[currentPage]) then
                processedPages[currentPage] = true

                for n in text:gmatch("[^\r\n]+") do
                    local idstroki, namebiz, idbiz, OwnerBiz, moneyBiz, finka = n:match('%[(%d+)%]%s+{.-}(.-)%((%d+)%)%s+{.-}(.-)%s+{.-}(%$[%d%,]+)%s+{.-}(%$[%d%,]+)')
                    if namebiz and idbiz then
                        -- Преобразуем idbiz в строку для расчёта дистанции
                        local idbizStr = tostring(idbiz)

                        -- Ищем существующий бизнес по ID
                        local existingBizIndex = nil
                        for i, biz in ipairs(settings.bizMafia) do
                            if biz.idBiz == idbizStr then
                                existingBizIndex = i
                                break
                            end
                        end

                        if existingBizIndex then
                            -- Обновляем только moneyMafia у существующего бизнеса, сохраняя формат с $ и запятыми
                            settings.bizMafia[existingBizIndex].moneyMafia = moneyBiz
                        else
                            -- Добавляем новый бизнес, если его ещё нет
                            table.insert(settings.bizMafia, {
                            idBiz = idbizStr,
                            nameBiz = namebiz,
                            ownerBiz = OwnerBiz,
                            moneyMafia = moneyBiz,  -- сохраняем как есть, с $ и запятыми
                            finkaBiz = finka       -- сохраняем как есть, с $ и запятыми
                                })
                        end
                    end
                end

                --[[
                -- Сохраняем данные после обработки страницы
                local status, code = json('finkovozkaByYargoff.json'):Save(settings)
                if status then
                    --sampAddChatMessage('Страница ' .. currentPage .. ' обработана', -1)
                else
                    sampAddChatMessage('Ошибка сохранения: ' .. code, -1)
                end ]]
            end

            -- Логика перехода на следующую страницу или закрытия диалога
            if currentPage and maxPages and currentPage < maxPages then
                lua_thread.create(function()
                    wait(0)
                    local listbox = sampGetListboxItemByText('Следующая страница')
                    if listbox ~= -1 then
                        sampSendDialogResponse(id, 1, listbox, '')
                    else
                        -- Альтернативный переход
                        local lineNum = 0
                        for altLine in text:gmatch("[^\r\n]+") do
                        lineNum = lineNum + 1
                            if altLine:find("Следующая") then
                                sampSendDialogResponse(id, 1, lineNum - 2, '')
                                break
                            end
                        end
                    end
                end)
            else
                -- Все страницы обработаны
                lua_thread.create(function ()
                    wait(500)
                    sampCloseCurrentDialogWithButton(0)

                    -- Завершаем обновление
                    rebuildIndexes()
                    isUpdatingFinka = false
                    mbiz = false
                    lastFinkaUpdate = os.time() * 1000

                    sampAddChatMessage("Обновление бизнесов завершено!", -1)
                    --sampAddChatMessage('Обработка всех страниц завершена! Всего бизнесов: ' .. #settings.bizMafia, -1)
                    end)
            end
            json('finkovozkaByYargoff.json'):Save(settings)
            return false -- скрываем диалог
        end
    end

    if id == 27653 and title:match('{BFBBBA}Меню сражений') then -- /mbiz Меню сражений
        if mbiz then
            sampSendDialogResponse(id, 0, 0, nil)
            mbiz = false
            return false
        end
    end

    do -- Убирает диалоги сбора и выгрузки финки
        if text:find("успешно загрузили в ваш грузовик") then -- Убирает нахуй диалог о финке
            sampSendDialogResponse(id, 0, 0, nil)
            return false
        end

        if text:find('в общак вашей орг') then
            if settings.autoTimeAndScreen then
                lua_thread.create(function()
                    sampSendChat("/time")
                    wait(200)
                    setVirtualKeyDown(vkeys.VK_F8, true)
                    wait(100)
                    setVirtualKeyDown(vkeys.VK_F8, false)
                end)
            end

            sampSendDialogResponse(id, 0, 0, nil)
            return false
        end
    end

    --{FFFFFF}Номер аккаунта:   {B83434}1135798 {FFFFFF}Авторизация на сервере:  {B83434}15:16 05.03.2026  {FFFFFF}Текущее состояние счета:  {FFFF00}30023 AZ-Coins  {FFFFFF}Имя: {B83434}[Aang_Mercenari]  {FFFFFF}Пол: {B83434}[Мужчина]  {FFFFFF}Здоровье: {B83434}[232/238] {FFFFFF}Уровень: {B83434}[200]  {FFFFFF}Уважение: {B83434}[235/804]  {FFFFFF}Наличные деньги (SA$): {B83434}[$1,219,787,352] {FFFFFF}Наличные деньги (VC$): {B83434}[$3,005,902] {FFFFFF}Евро: {B83434}[2042]  {FFFFFF}BTC: {B83434}[712] {FFFFFF}Но
    if id == 235 and title:match('{BFBBBA}Основная статистика') then 
        for line in text:gmatch("[^\r\n]+") do
            local rank = line:match("Должность: {B83434}.+%((%d+)%)")
            if rank then
                local rankplayer = tonumber(rank)
                if rankplayer >= 9 then
                    if settings.myRank ~= rankplayer then
                        sampAddChatMessage(tag..' Проверили твою статистику... внес твой ранг', base_color)
                        settings.myRank = rankplayer
                        sampAddChatMessage(rank, -1)
                        local status, code = json('finkovozkaByYargoff.json'):Save(settings)
                        sampAddChatMessage(status and 'Сохранил твой ранг!' or 'Не смог сохранить твой ранг: '..code, -1)
                    end
                end
            end
        end
    end

    if id == 1214 and title:match('{.-}{.-}Банк: {.-}$%d+') then -- работа с диалогом lmenu
        if dialogProcessed then
            -- Если диалог уже обработан, просто выходим
            dialogProcessed = false
            return false
        end

        if fastSpCar then -- Быстрый спавн авто фракции
            sampSendDialogResponse(id, 1, 4, '')
            dialogProcessed = true
            return false
        end

        if fuelcar then -- Заправка машин фракции
            sampSendDialogResponse(id, 1, 5, '')
            dialogProcessed = true
            return false
        end

        if fastObshak8 or fastObshak9 then -- Изменить ранг доступа к общагу
            sampSendDialogResponse(id, 1, 8, '')
            return false
        end

        if sellRankData and sellRankData.sellrank then -- Продажа ранга
            sampSendDialogResponse(id, 1, 21, '')
            return false
        end
    end

    if id == 25667 and title:match('{.-}{.-}Выберите ранг доступа к складу') then -- Изменение ранга на общаг
        if fastObshak8 then
            sampSendDialogResponse(id, 1, 6, '')
            dialogProcessed = true
            fastObshak8 = false
            return false
        end

        if fastObshak9 then
            sampSendDialogResponse(id, 1, 7, '')
            dialogProcessed = true
            fastObshak9 = false
            return false
        end
    end

    if id == 25526 and title:match('{BFBBBA}Выбор места спавна') then -- Выбор спавна если есть ADD VIP
        if AutoSpawnFraction then
            if text:match('{ae433d}%[%d+%] {ffffff}Организация Tierra Robada Bikers')then
                lua_thread.create(function()
                    wait(0)
                    listbox = sampGetListboxItemByText('Организация Tierra Robada Bikers') -- тут НЕ ЭКРАНИРУЕМ
                    sampSendDialogResponse(id, 1, listbox, nil)
                    sampCloseCurrentDialogWithButton(0)
                    sampAddChatMessage('выбрал '..listbox, -1)
                    end)
            end
            AutoSpawnFraction = false
        end

    end

    if id == 27273 and title:match('{%BFBBBA%}Выбор игрока') then
        if sellRankData and sellRankData.sellrank then
            local nameplayer = sampGetPlayerNickname(sellRankData.iFraction)
            --sampAddChatMessage(nameplayer .. ' ' .. sellRankData.iFraction, -1)

            if text:match('%{C0C0C0%}%[%d+%] %{FFFFFF%}.-%(%d+%)%s*%d*%.?%d* м%.') then
                lua_thread.create(function()
                    wait(0)
                    listbox = sampGetListboxItemByText(''..nameplayer..'('..sellRankData.iFraction..')')
                    if listbox ~= nil then
                        sampSendDialogResponse(id, 1, listbox, nil)
                        sampCloseCurrentDialogWithButton(0)
                        --sampAddChatMessage('выбрал ' .. tostring(listbox), -1)
                    else
                        sampAddChatMessage(tag..' Не нашёл игрока в списке!', base_color)
                    end
                end)
            end
        end
    end

    if id == 27274 and title:match('{%BFBBBA%}Список свободных вакансий %[всего: %d+ игроков%]') then
        if sellRankData and sellRankData.sellrank then
            --sampAddChatMessage('DEBUG: Условие выполнено! Заходим в блок.', -1)

            local sellrank = {
                [6] = '{%C0C0C0%}%[6%] {%FFFFFF%}.+ {%10F441%}%d+ / .+',
                [7] = '{%C0C0C0%}%[7%] {%FFFFFF%}.+ {%10F441%}%d+ / .+'
            }

            -- Выводим отладочную информацию
            --for i, rank in ipairs(sellrank) do
            --    sampAddChatMessage('DEBUG: i=' .. i .. ', шаблон=' .. rank, -1)
            --end

            -- Проверяем, существует ли rFraction в sellrank
            if not sellRankData.rFraction then
                sampAddChatMessage(tag .. ' Ошибка: rFraction не задан!', base_color)
                return
            end

            if not sellrank[sellRankData.rFraction] then
                sampAddChatMessage(tag .. ' Введите корректный номер продаваемого ранга (6 или 7)!', base_color)
                return
            end

            --local list = sellRankData.rFraction - 1

            -- Отправляем ответ только для нужного ранга
            sampSendDialogResponse(id, 1, sellRankData.rFraction - 1, nil)
            --sampAddChatMessage('Выбран ранг №' .. list, -1)
            return false
        end
    end

    if id == 27275 and title:match('{BFBBBA}Количество дней') then
        sampSendDialogResponse(id, 1, nil, sellRankData.dFraction)
        return false
    end

    if id == 27276 and title:match('{BFBBBA}Стоимость за день') then
        local money = math.ceil( sellRankData.pFraction / sellRankData.dFraction )
        sampSendDialogResponse(id, 1, '', money)
        return false
    end

    if id == 27277 and title:match('{BFBBBA}Подтверждение указанных данных') then
        sampSendDialogResponse(id, 1, nil, '')
        sellRankData = nil
        return false
    end

    if fastinvite then-- Диалог инвайта
        if id == 25638 and title:match('{.-}Выберите ранг для (.+_.+)') then
            if text:match('{.-}%[1%]%s+{.-}:uf250:%s+{.-}%[ %d+ / ~ вакансий %]%s+') then
                sampSendDialogResponse(id, 1, 0, '')
                return false
            end
        end
    end

    if id == 9188 then -- Диалог выбора скина фракции
        sampSendDialogResponse(id, 1, nil, '')
        return false
    end

--Его id: 1214 Его стиль: 2 Его наименование: {BFBBBA}{FFFFFF}Банк: {E1E948}$583792808
--Его id: 27273 Его стиль: 5 Его наименование: {BFBBBA}Выбор игрока
--{FFFFFF}Ник {F0E68C}Дистанция {C0C0C0}[1] {FFFFFF}Kleo_Wepor(170) 7.0 м. {C0C0C0}[2] {FFFFFF}Logan_Angels(502) 1.2 м.
--Его id: 27274 Его стиль: 5 Его наименование: {BFBBBA}Список свободных вакансий [всего: 127 игроков]
--{FFFFFF}Ранг {FFFFFF}Вакансии {C0C0C0}[1] {FFFFFF}? {10F441}7 / ~ {C0C0C0}[2] {FFFFFF}? {10F441}0 / ~ {C0C0C0}[3] {FFFFFF}? {10F441}0 / ~ {C0C0C0}[4] {FFFFFF}? {10F441}0 / ~ {C0C0C0}[5] {FFFFFF}? {10F441}58 / ~ {C0C0C0}[6] {FFFFFF}? {10F441}11 / 210 {C0C0C0}[7] {FFFFFF}? {10F441}40 / 140 {C0C0C0}[8] {FFFFFF}? {10F441}3 / 4
--Его id: 27275 Его стиль: 1 Его наименование: {BFBBBA}Количество дней
--Его id: 27276 Его стиль: 1 Его наименование: {BFBBBA}Стоимость за день
--Его id: 27277 Его стиль: 0 Его наименование: {BFBBBA}Подтверждение указанных данных

end

function sampGetListboxItemByText(text, plain) -- поиск текста в диалоге style 2 и его мгновенный выбор
    if not sampIsDialogActive() then return -1 end
        plain = not (plain == false)
    for i = 0, sampGetListboxItemsCount() - 1 do
        if sampGetListboxItemText(i):find(text, 1, plain) then
            return i
        end
    end
    return -1
end

function SearchMarker(posX, posY, posZ, radius, isRace) -- Получение координат красного квадратика
    local ret_posX = 0.0
    local ret_posY = 0.0
    local ret_posZ = 0.0
    local isFind = false

    for id = 0, 31 do
        local MarkerStruct = 0
        if isRace then MarkerStruct = 0xC7F168 + id * 56
        else MarkerStruct = 0xC7DD88 + id * 160 end
        local MarkerPosX = representIntAsFloat(readMemory(MarkerStruct + 0, 4, false))
        local MarkerPosY = representIntAsFloat(readMemory(MarkerStruct + 4, 4, false))
        local MarkerPosZ = representIntAsFloat(readMemory(MarkerStruct + 8, 4, false))

        if MarkerPosX ~= 0.0 or MarkerPosY ~= 0.0 or MarkerPosZ ~= 0.0 then
            if getDistanceBetweenCoords3d(MarkerPosX, MarkerPosY, MarkerPosZ, posX, posY, posZ) < radius then
                ret_posX = MarkerPosX
                ret_posY = MarkerPosY
                ret_posZ = MarkerPosZ
                isFind = true
                radius = getDistanceBetweenCoords3d(MarkerPosX, MarkerPosY, MarkerPosZ, posX, posY, posZ)
            end
        end
    end

    return isFind, ret_posX, ret_posY, ret_posZ
end

function sortBusinessesById() -- Сортировка бизнесов по ID
    table.sort(settings.bizMafia, function(a, b)
        local idA = tonumber(a.idBiz) or 0
        local idB = tonumber(b.idBiz) or 0
        return idA < idB
    end)
    json('finkovozkaByYargoff.json'):Save(settings)
    --sampAddChatMessage("Бизнесы отсортированы по id (числовой порядок)!", -1)
end

function sortBusinessesByMoneyMafia() -- Сортировка бизнесов по финке
    -- Проверяем, есть ли бизнесы для сортировки
    if not settings.bizMafia or #settings.bizMafia == 0 then
        sampAddChatMessage("Нет бизнесов для сортировки!", -1)
        return
    end

    table.sort(settings.bizMafia, function(a, b)
        -- Удаляем символ $ и запятые, преобразуем в число
        local cleanedA = string.gsub(a.moneyMafia or "", "[$,]", "")
        local cleanedB = string.gsub(b.moneyMafia or "", "[$,]", "")

        -- Явно передаём только строку в tonumber, без дополнительных аргументов
        local moneyA = tonumber(cleanedA) or 0
        local moneyB = tonumber(cleanedB) or 0

        -- Сортируем по убыванию (от большего к меньшему)
        return moneyA > moneyB
    end)

    -- Сохраняем отсортированные данные
    local status, code = json('finkovozkaByYargoff.json'):Save(settings)

    -- Выводим сообщение с результатом
    --sampAddChatMessage(status and "Бизнесы отсортированы по финке на бизах! Всего: " .. #settings.bizMafia-1 or "Ошибка сохранения после сортировки: " .. code, -1)
end

function sortBusinessesByDistance()  -- Функция сортировки бизнесов по дистанции
    calculateBusinessDistances()

    table.sort(settings.bizMafia, function(a, b)
        local distA = distanceCache[a.idBiz] and distanceCache[a.idBiz].distance or math.huge
        local distB = distanceCache[b.idBiz] and distanceCache[b.idBiz].distance or math.huge
        return distA < distB
    end)

    rebuildIndexes()
end

function sortBusinessesCoord()  -- Функция сортировки бизнесов по координатам
    table.sort(CoordBizness.coordbiz, function(a, b)
        return a.idbiz < b.idbiz
    end)
    json('finkovozkaByYargoff.json'):Save(settings)
    sampAddChatMessage("Бизнесы отсортированы по id!", -1)
end

function calculateBusinessDistances() -- Функция вычесления расстояния
    local currentTime = os.clock() * 1000

    -- ограничение по времени
    if currentTime - lastDistanceUpdate < DISTANCE_UPDATE_INTERVAL then
        return distanceCache
    end

    local px, py, pz = getCharCoordinates(PLAYER_PED)
    if not px then
        return distanceCache
    end

    -- проверка движения игрока
    local moved = math.sqrt(
        (px-lastPlayerX)^2 +
        (py-lastPlayerY)^2 +
        (pz-lastPlayerZ)^2
    )

    if moved < MOVE_THRESHOLD then
        return distanceCache
    end

    lastDistanceUpdate = currentTime
    lastPlayerX, lastPlayerY, lastPlayerZ = px, py, pz

    distanceCache = {}

    -- ?? быстрый расчёт O(n)
    for _, coord in ipairs(CoordBizness.coordbiz or {}) do
        local x, y, z, id = table.unpack(coord)

        if x and y and z and id then
            local dist = math.sqrt(
                (px - x)^2 +
                (py - y)^2 +
                (pz - z)^2
            )

            distanceCache[id] = {
                idBiz = id,
                distance = dist
            }
        end
    end

    if sortDistance then
        table.sort(settings.bizMafia, function(a, b)
            local distA = distanceCache[a.idBiz] and distanceCache[a.idBiz].distance or math.huge
            local distB = distanceCache[b.idBiz] and distanceCache[b.idBiz].distance or math.huge
            return distA < distB
        end)
    end

    return distanceCache
end

function formatMoneyWithSpaces(moneyStr) -- Функция разделения чисел
    -- Удаляем $ и запятые, если они есть
    local cleanMoney = string.gsub(moneyStr, "[$,]", "")

    -- Обрабатываем только цифры
    if not tonumber(cleanMoney) then
        return moneyStr
    end

    -- Разделяем на группы по 3 цифры справа налево
    local formatted = ""
    local length = #cleanMoney
    for i = 1, length do
        local pos = length - i + 1
        formatted = cleanMoney:sub(pos, pos) .. formatted
        if i % 3 == 0 and i < length then
            formatted = "." .. formatted -- выписывать сюда, что вставлять между числами
        end
    end

    return "$" .. formatted
end

function renderFontDrawTextAlign(font, text, x, y, color, align) -- Центрование 3D текст
    if not align or align == 1 then -- слева
        renderFontDrawText(font, text, x, y, color)
    end
    if align == 2 then -- по центру
        renderFontDrawText(font, text, x - renderGetFontDrawTextLength(font, text) / 2, y, color)
    end
    if align == 3 then -- справа
        renderFontDrawText(font, text, x - renderGetFontDrawTextLength(font, text), y, color)
    end
end

function Draw3DCircle(x, y, z, radius, color, width, segments) -- Рисование круга
    -- Параметры по умолчанию
    color = color or 0xFFD00000  -- красный (ARGB)
    width = width or 3.0          -- ширина линии
    segments = segments or 12      -- количество сегментов

    -- Проверка видимости центра круга
    local centerResult, centerScreenX, centerScreenY = convert3DCoordsToScreenEx(x, y, z + 0.5, true, true)
    if not centerResult then
        return  -- не рисуем, если центр не виден
    end

    local prevScreenX, prevScreenY = nil, nil

    for i = 0, segments do
        local angle = (i / segments) * 2 * math.pi
        local px = x + radius * math.cos(angle)
        local py = y + radius * math.sin(angle)
        local pz = z + 0.5  -- слегка выше земли для лучшей видимости

        -- Конвертируем в экранные координаты
        local result, screenX, screenY = convert3DCoordsToScreenEx(px, py, pz, true, true)

        if result and screenX and screenY then
            -- Рисуем линию, если есть предыдущая точка
            if prevScreenX and prevScreenY then
                renderDrawLine(prevScreenX, prevScreenY, screenX, screenY, width, color)
            end
            -- Обновляем предыдущую точку
            prevScreenX, prevScreenY = screenX, screenY
        end
    end

    -- Замыкаем круг: соединяем последнюю видимую точку с первой
    if prevScreenX and prevScreenY and centerScreenX and centerScreenY then
        renderDrawLine(prevScreenX, prevScreenY, centerScreenX, centerScreenY, width, color)
    end
end

function notif(type, title, text, time) -- Уведомление как на АРЗ

---@param type string success, error, info, halloween
---@param title string any
---@param text string any
---@param time number ms

    type = type or 'info'
    title = title or 'Заголовок'
    text = text or 'Текст'
    time = time or 2000
    local json = string.format('[%q,%q,%q,%d]', type, title, text, time)
    local code = "window.executeEvent('event.notify.initialize', `" .. json .. "`);"
    local bs = raknetNewBitStream()
    raknetBitStreamWriteInt8(bs, 17)
    raknetBitStreamWriteInt32(bs, 0)
    raknetBitStreamWriteInt16(bs, #code)
    raknetBitStreamWriteInt8(bs, 0)
    raknetBitStreamWriteString(bs, code)
    raknetEmulPacketReceiveBitStream(220, bs)
    raknetDeleteBitStream(bs)
end

function theme() -- Стиль mimgui
    imgui.SwitchContext()
    local style = imgui.GetStyle()
    local colors = style.Colors
    local clr = imgui.Col
    local ImVec4 = imgui.ImVec4
    local ImVec2 = imgui.ImVec2

    style.WindowPadding = imgui.ImVec2(8, 8)
    style.WindowRounding = 6
    style.ChildRounding = 5
    style.FramePadding = imgui.ImVec2(5, 3)
    style.FrameRounding = 3.0
    style.ItemSpacing = imgui.ImVec2(5, 4)
    style.ItemInnerSpacing = imgui.ImVec2(4, 4)
    style.IndentSpacing = 21
    style.ScrollbarSize = 10.0
    style.ScrollbarRounding = 13
    style.GrabMinSize = 8
    style.GrabRounding = 1
    style.WindowTitleAlign = imgui.ImVec2(0.5, 0.5)
    style.ButtonTextAlign = imgui.ImVec2(0.5, 0.5)

    colors[clr.Text]                   = ImVec4(0.95, 0.96, 0.98, 1.00);
    colors[clr.TextDisabled]           = ImVec4(0.29, 0.29, 0.29, 1.00);
    colors[clr.WindowBg]               = ImVec4(0.14, 0.14, 0.14, 1.00);
    colors[clr.ChildBg]                = ImVec4(0.12, 0.12, 0.12, 1.00);
    colors[clr.PopupBg]                = ImVec4(0.08, 0.08, 0.08, 0.94);
    colors[clr.Border]                 = ImVec4(0.14, 0.14, 0.14, 1.00);
    colors[clr.BorderShadow]           = ImVec4(1.00, 1.00, 1.00, 0.10);
    colors[clr.FrameBg]                = ImVec4(0.22, 0.22, 0.22, 1.00);
    colors[clr.FrameBgHovered]         = ImVec4(0.18, 0.18, 0.18, 1.00);
    colors[clr.FrameBgActive]          = ImVec4(0.09, 0.12, 0.14, 1.00);
    colors[clr.TitleBg]                = ImVec4(0.14, 0.14, 0.14, 0.81);
    colors[clr.TitleBgActive]          = ImVec4(0.14, 0.14, 0.14, 1.00);
    colors[clr.TitleBgCollapsed]       = ImVec4(0.00, 0.00, 0.00, 0.51);
    colors[clr.MenuBarBg]              = ImVec4(0.20, 0.20, 0.20, 1.00);
    colors[clr.ScrollbarBg]            = ImVec4(0.02, 0.02, 0.02, 0.39);
    colors[clr.ScrollbarGrab]          = ImVec4(0.36, 0.36, 0.36, 1.00);
    colors[clr.ScrollbarGrabHovered]   = ImVec4(0.18, 0.22, 0.25, 1.00);
    colors[clr.ScrollbarGrabActive]    = ImVec4(0.24, 0.24, 0.24, 1.00);
    colors[clr.CheckMark]              = ImVec4(1.00, 0.28, 0.28, 1.00);
    colors[clr.SliderGrab]             = ImVec4(1.00, 0.28, 0.28, 1.00);
    colors[clr.SliderGrabActive]       = ImVec4(1.00, 0.28, 0.28, 1.00);
    colors[clr.Button]                 = ImVec4(0.76, 0.16, 0.16, 1.00);
    colors[clr.ButtonHovered]          = ImVec4(1.00, 0.39, 0.39, 1.00);
    colors[clr.ButtonActive]           = ImVec4(1.00, 0.21, 0.21, 1.00);
    colors[clr.Header]                 = ImVec4(1.00, 0.28, 0.28, 1.00);
    colors[clr.HeaderHovered]          = ImVec4(1.00, 0.39, 0.39, 1.00);
    colors[clr.HeaderActive]           = ImVec4(1.00, 0.21, 0.21, 1.00);
    colors[clr.ResizeGrip]             = ImVec4(1.00, 0.28, 0.28, 1.00);
    colors[clr.ResizeGripHovered]      = ImVec4(1.00, 0.39, 0.39, 1.00);
    colors[clr.ResizeGripActive]       = ImVec4(1.00, 0.19, 0.19, 1.00);
    colors[clr.Tab]                    = ImVec4(0.09, 0.09, 0.09, 1.00);
    colors[clr.TabHovered]             = ImVec4(0.58, 0.23, 0.23, 1.00);
    colors[clr.TabActive]              = ImVec4(0.76, 0.16, 0.16, 1.00);
    colors[clr.Button]                 = ImVec4(0.40, 0.39, 0.38, 0.16);
    colors[clr.ButtonHovered]          = ImVec4(0.40, 0.39, 0.38, 0.39);
    colors[clr.ButtonActive]           = ImVec4(0.40, 0.39, 0.38, 1.00);
    colors[clr.PlotLines]              = ImVec4(0.61, 0.61, 0.61, 1.00);
    colors[clr.PlotLinesHovered]       = ImVec4(1.00, 0.43, 0.35, 1.00);
    colors[clr.PlotHistogram]          = ImVec4(1.00, 0.21, 0.21, 1.00);
    colors[clr.PlotHistogramHovered]   = ImVec4(1.00, 0.18, 0.18, 1.00);
    colors[clr.TextSelectedBg]         = ImVec4(1.00, 0.32, 0.32, 1.00);
    colors[clr.ModalWindowDimBg]   = ImVec4(0.26, 0.26, 0.26, 0.60);
end

--[[
function drawBusinessInfoOnScreenVer2() -- Новая версия (Данные о бизнесе + рисование кругов)

    -- Проверка флага отображения
    if not settings.render_finki then
        sampAddChatMessage("Рендер отключён (RENDER_FINKA2 = false)", -1)
        return
    end

    -- Получаем координаты игрока
    local playerX, playerY, playerZ = getCharCoordinates(PLAYER_PED)
    if not playerX or not playerY or not playerZ then
        sampAddChatMessage("Ошибка: не удалось получить координаты игрока", -1)
        return
    end

    -- Проверка данных о координатах бизнесов
    if not CoordBizness.coordbiz or next(CoordBizness.coordbiz) == nil then
        sampAddChatMessage("Ошибка: нет данных о координатах бизнесов", -1)
        return
    end

    local renderedCount = 0
    local skippedCount = 0

    for i, coordbiz in pairs(CoordBizness.coordbiz) do
        local coordx, coordy, coordz, idbiz = table.unpack(coordbiz)

        -- Приведение типов и проверка валидности
        coordx = tonumber(coordx)
        coordy = tonumber(coordy)
        coordz = tonumber(coordz)
        idbiz = tonumber(idbiz)

        if not coordx or not coordy or not coordz or not idbiz then
            sampAddChatMessage("Пропуск: некорректные координаты или ID для бизнеса №" .. tostring(i), -1)
            skippedCount = skippedCount + 1
            goto continue
        end

        -- Проверка: есть ли бизнес в settings.bizMafia
        local isInMafia = false
        if settings.bizMafia then
            for _, mafiaBizId in pairs(settings.bizMafia) do
                local mafiaIdNum = tonumber(mafiaBizId)
                if mafiaIdNum and mafiaIdNum == idbiz then
                    isInMafia = true
                    break
                end
            end
        end

        --if not isInMafia then
        --    skippedCount = skippedCount + 1
        --    goto continue
        --end

        -- Поиск бизнеса в базе
        local moneyValue = 0
        local nameBiz = "Неизвестно"
        local biz = bizById[idbiz] or bizById[tostring(idbiz)]

        if not biz then
            --sampAddChatMessage("Пропуск: бизнес ID " .. tostring(idbiz) .. " не найден в базе bizById", -1)
            skippedCount = skippedCount + 1
            goto continue
        end

        -- Безопасное извлечение суммы
        local rawMoney = biz.moneyMafia or biz.money or biz.income or biz.cash
        if rawMoney then
            if type(rawMoney) == "string" then
                rawMoney = string.gsub(rawMoney, "[^%d%.%-]", "")
            end
            moneyValue = tonumber(rawMoney) or 0
        else
            moneyValue = 0
        end
        nameBiz = tostring(biz.nameBiz or biz.name or "Без названия")

        -- ПРОВЕРКА: минимальная сумма для рендера
        local MIN_MONEY_TO_RENDER = tonumber(settings.MIN_MONEY_TO_RENDER)
        if moneyValue < MIN_MONEY_TO_RENDER then
            --sampAddChatMessage("Пропуск: бизнес ID " .. tostring(idbiz) .." не отображается (сумма $" .. tostring(moneyValue) .." < MIN_MONEY_TO_RENDER $" .. tostring(MIN_MONEY_TO_RENDER) .. ")",-1)
            skippedCount = skippedCount + 1
            goto continue
        end

        -- Расчёт расстояния
        local playerToTextDist = getDistanceBetweenCoords3D(
            playerX, playerY, playerZ,
            coordx, coordy, coordz
        )

        if type(playerToTextDist) ~= "number" then
            --sampAddChatMessage("Пропуск: ошибка расчёта расстояния для бизнеса ID " .. tostring(idbiz), -1)
            skippedCount = skippedCount + 1
            goto continue
        end

        if playerToTextDist > settings.dist_render then
            --sampAddChatMessage("Пропуск: бизнес ID " .. tostring(idbiz) .. " слишком далеко (" .. string.format('%.2f', playerToTextDist) .. " > 1200)", -1)
            skippedCount = skippedCount + 1
            goto continue
        end

        -- Конвертация координат
        local result, screenX, screenY, _, _, _ =
            convert3DCoordsToScreenEx(coordx, coordy, coordz, true, true)

        if not result or not screenX or not screenY then
            --sampAddChatMessage("Пропуск: не удалось конвертировать координаты для бизнеса ID " .. tostring(idbiz), -1)
            skippedCount = skippedCount + 1
            goto continue
        end

        -- ОТРИСОВКА КРУГА (если включено)
        if settings.render_circle then
            -- Отрисовка 3D?круга вокруг бизнеса
            local circleRadius = 15.0
            if playerToTextDist < 35.0 then
                circleRadius = 20.0
            elseif playerToTextDist < 75.0 then
                circleRadius = 15
            elseif playerToTextDist < 100.0 then
                circleRadius = 10
            elseif playerToTextDist < 200.0 then
                circleRadius = 5
            elseif playerToTextDist > 200.0 then
                circleRadius = 0
            end

            -- Цвет круга в зависимости от дохода бизнеса
            local circleColor = 0xFFFF0000  -- красный: низкий доход
            if moneyValue > 200000 then
                circleColor = 0xFFFFFF00  -- жёлтый: средний доход
            end
            if moneyValue > 800000 then
                circleColor = 0xFF00FF00  -- зелёный: высокий доход
            end

            local circleSize = 2.5 

            Draw3DCircle(coordx, coordy, coordz - 2, circleRadius, circleColor, circleSize, 50)
        end

        -- Определение смещения для текста
        local verticalOffset = 0
        if playerToTextDist < 10.0 then verticalOffset = 120
        elseif playerToTextDist < 20.0 then verticalOffset = 100
        elseif playerToTextDist < 35.0 then verticalOffset = 80
        elseif playerToTextDist < 55.0 then verticalOffset = 50
        elseif playerToTextDist < 75.0 then verticalOffset = 30
        elseif playerToTextDist < 100.0 then verticalOffset = 20
        elseif playerToTextDist < 150.0 then verticalOffset = 0
        else verticalOffset = -100 end

        -- Отрисовка текста (с проверкой шрифта)
        if font then
            renderFontDrawTextAlign(
                font,
                '[{ff0000}'..tostring(idbiz)..'{ffffff}] | '..nameBiz,
                screenX,
                screenY + verticalOffset,
                0xFFFFFFFF, 2
            )
            renderFontDrawTextAlign(
                font,
                string.format('%.2f', playerToTextDist)..' | {20E10E}'..tostring(moneyValue),
                screenX,
                screenY + verticalOffset + 25,
                0xFFFFFFFF, 2
            )
        else
            sampAddChatMessage("Ошибка: шрифт не инициализирован (font == nil)", -1)
            return
        end

        renderedCount = renderedCount + 1
        ::continue::
    end

    --sampAddChatMessage("Рендер завершён: отображено " .. tostring(renderedCount) ..", пропущено " .. tostring(skippedCount) .. " бизнесов",-1)
end

function drawBusinessInfoOnScreenVer21() -- Старая версия
    -- Проверка флага отображения
    if not RENDER_FINKA2 then
        return
    end

    -- Получаем координаты игрока
    local playerX, playerY, playerZ = getCharCoordinates(PLAYER_PED)
    if not playerX or not playerY or not playerZ then
        return
    end

    -- Проверка данных о координатах бизнесов
    if not CoordBizness.coordbiz or next(CoordBizness.coordbiz) == nil then
        sampAddChatMessage("Ошибка: нет данных о координатах бизнесов", -1)
        return
    end

    local renderedCount = 0

    for i, coordbiz in pairs(CoordBizness.coordbiz) do
        local coordx, coordy, coordz, idbiz = table.unpack(coordbiz)

        -- Проверка валидности координат и ID
        if not coordx or not coordy or not coordz or not idbiz then
            goto continue
        end

        -- Поиск бизнеса в базе
        local moneyValue = 0
        local nameBiz = "Неизвестно"
        local biz = bizById[idbiz]
        if biz then
            moneyValue = biz.moneyMafia or 0
            nameBiz = biz.nameBiz or "Без названия"
        end

        -- Расчёт расстояния
        local playerToTextDist = getDistanceBetweenCoords3D(
            playerX, playerY, playerZ,
            coordx, coordy, coordz
        )
        if playerToTextDist > 1200.0 then
            goto continue
        end

        -- Конвертация координат
        local result, screenX, screenY, _, _, _ =
            convert3DCoordsToScreenEx(coordx, coordy, coordz, true, true)

        if not result or not screenX or not screenY then
            goto continue
        end

        -- Определение смещения
        local verticalOffset = 0
        if playerToTextDist < 10.0 then verticalOffset = 120
        elseif playerToTextDist < 20.0 then verticalOffset = 100
        elseif playerToTextDist < 35.0 then verticalOffset = 80
        elseif playerToTextDist < 55.0 then verticalOffset = 50
        elseif playerToTextDist < 75.0 then verticalOffset = 30
        elseif playerToTextDist < 100.0 then verticalOffset = 20
        elseif playerToTextDist < 150.0 then verticalOffset = 0
        else verticalOffset = -100 end

        -- Отрисовка текста
        renderFontDrawTextAlign(
            font,
            '[{ff0000}'..idbiz..'{ffffff}] | '..nameBiz,
            screenX,
            screenY + verticalOffset,
            0xFFFFFFFF, 2
        )
        renderFontDrawTextAlign(
            font,
            string.format('%.2f', playerToTextDist)..' | {20E10E}'..moneyValue,
            screenX,
            screenY + verticalOffset + 25,
            0xFFFFFFFF, 2
        )

        renderedCount = renderedCount + 1
        ::continue::
    end
end
]]

--[[
if id == 27662 then -- /mbiz Бизнесы на балансе
        if mbiz then
            local currentPage, maxPages = nil, nil

            -- Сначала ищем информацию о страницах
            for line in text:gmatch("[^\r\n]+") do
                local page, maxPage = line:match('{.-}%[»»»%] {.-}Следующая страница %[(%d+) / (%d+)%]')
                if page and maxPage then
                    currentPage = tonumber(page)
                    maxPages = tonumber(maxPage)
                    break
                end
            end

            -- Если номер страницы не найден, считаем, что это последняя страница
            if not currentPage then
                currentPage = #processedPages + 1
                maxPages = maxPages or currentPage
            end

            -- Если это новая страница, которую ещё не обрабатывали
            if currentPage and (not processedPages[currentPage]) then
                processedPages[currentPage] = true

                for n in text:gmatch("[^\r\n]+") do
                    local idstroki, namebiz, idbiz, OwnerBiz, moneyBiz, finka = n:match('%[(%d+)%]%s+{.-}(.-)%((%d+)%)%s+{.-}(.-)%s+{.-}(%$[%d%,]+)%s+{.-}(%$[%d%,]+)')
                    if namebiz and idbiz then
                        -- Преобразуем idbiz в строку для расчёта дистанции
                        local idbizStr = tostring(idbiz)

                        -- Ищем существующий бизнес по ID
                        local existingBizIndex = nil
                        for i, biz in ipairs(settings.bizMafia) do
                            if biz.idBiz == idbizStr then
                                existingBizIndex = i
                                break
                            end
                        end

                        if existingBizIndex then
                            -- Обновляем только moneyMafia у существующего бизнеса, сохраняя формат с $ и запятыми
                            settings.bizMafia[existingBizIndex].moneyMafia = moneyBiz
                        else
                            -- Добавляем новый бизнес, если его ещё нет
                            table.insert(settings.bizMafia, {
                            idBiz = idbizStr,
                            nameBiz = namebiz,
                            ownerBiz = OwnerBiz,
                            moneyMafia = moneyBiz,  -- сохраняем как есть, с $ и запятыми
                            finkaBiz = finka       -- сохраняем как есть, с $ и запятыми
                                })
                        end
                    end
                end

                --[[
                -- Сохраняем данные после обработки страницы
                local status, code = json('finkovozkaByYargoff.json'):Save(settings)
                if status then
                    --sampAddChatMessage('Страница ' .. currentPage .. ' обработана', -1)
                else
                    sampAddChatMessage('Ошибка сохранения: ' .. code, -1)
                end
            end

            -- Логика перехода на следующую страницу или закрытия диалога
            if currentPage and maxPages and currentPage < maxPages then
                lua_thread.create(function()
                    wait(300)
                    local listbox = sampGetListboxItemByText('Следующая страница')
                    if listbox ~= -1 then
                        sampSendDialogResponse(id, 1, listbox, '')
                    else
                        -- Альтернативный переход
                        local lineNum = 0
                        for altLine in text:gmatch("[^\r\n]+") do
                        lineNum = lineNum + 1
                            if altLine:find("Следующая") then
                                sampSendDialogResponse(id, 1, lineNum - 2, '')
                                break
                            end
                        end
                    end
                end)
            else
                -- Все страницы обработаны
                lua_thread.create(function ()
                    wait(500)
                    sampCloseCurrentDialogWithButton(0)

                    -- Завершаем обновление
                    rebuildIndexes()
                    isUpdatingFinka = false
                    mbiz = false
                    lastFinkaUpdate = os.time() * 1000

                    sampAddChatMessage("Обновление бизнесов завершено!", -1)
                    --sampAddChatMessage('Обработка всех страниц завершена! Всего бизнесов: ' .. #settings.bizMafia, -1)
                    end)
            end
            json('finkovozkaByYargoff.json'):Save(settings)
            return false -- скрываем диалог
        end
    end
]]
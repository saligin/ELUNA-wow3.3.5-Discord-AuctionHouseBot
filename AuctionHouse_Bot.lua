-- Credits Mithras, Niam5, and ReynoldsCahoon --

local auctionConfig = {
    auctionWebhookURL = "YOUR_WEBHOOK_URL", -- URL вебхука вашего канала Discord
    goldEmojiID       = "<:moneygold:1240899632381431850>", -- ID ваших эмодзи для золота/серебра/меди
    silverEmojiID     = "<:moneysilver:1240899652534931516>", -- ID ваших эмодзи для золота/серебра/меди
    copperEmojiID     = "<:moneycopper:1240899605751664721>", -- ID ваших эмодзи для золота/серебра/меди
    itemLinkDB        = "https://www.wowhead.com/wotlk/ru/", --оставьте как есть
    thumbnailIcons    = true, -- Установите значение false, если у вас нет данных DBC в вашей базе данных и вы хотите отказаться от миниатюрных иконок
    itemIconDB        = "https://wow.zamimg.com/images/wow/icons/large/", --оставьте как есть
    botImage          = "YOUR_BOT_IMAGE_URL", -- Изображение профиля бота, который публикует в Discord
    itemQuality       = {
        [0] = {color = 10329501, name = "Poor"},
        [1] = {color = 16777215, name = "Common"},
        [2] = {color = 2031360, name = "Uncommon"},
        [3] = {color = 28893, name = "Rare"},
        [4] = {color = 10696174, name = "Epic"},
        [5] = {color = 16744448, name = "Legendary"},
        [6] = {color = 15125632, name = "Artifact"},
        [7] = {color = 52479, name = "Heirloom"}
    }
}

local function SendDiscordEmbed(message, webhookURL)
    -- print("Sending message to Discord: " .. message) -- Закомментировано для скрытия вывода
    local curlCommand = 'curl -X POST -H "Content-Type: application/json" -d @- ' .. webhookURL
    local curlProcess = io.popen(curlCommand, 'w')
    curlProcess:write(message)
    curlProcess:close()
end

local function GetItemNameInLocale(itemId, locale)
    local query = string.format("SELECT Name FROM item_template_locale WHERE ID = %d AND locale = '%s'", itemId, locale)
    local nameQuery = WorldDBQuery(query)
    if nameQuery and nameQuery:GetRowCount() > 0 then
        local name = nameQuery:GetString(0)
        -- print("Item name in locale " .. locale .. ": " .. name) -- Закомментировано для скрытия вывода
        return name
    else
        -- print("Item name not found for item ID " .. itemId .. " in locale " .. locale) -- Закомментировано для скрытия вывода
        return nil
    end
end

local function GetIconFromWoWHead(itemId)
    local url = "https://www.wowhead.com/item=" .. itemId .. "&xml"
    local iconName = "inv_misc_questionmark" -- дефолтная иконка на случай ошибки

    -- Запрос к WoWHead
    local request = io.popen('curl -s "' .. url .. '"')
    local response = request:read("*a")
    request:close()

    -- print("API response for item ID " .. itemId .. ": " .. response) -- Закомментировано для скрытия вывода

    if response then
        -- Пытаемся извлечь имя иконки из ответа XML
        local data = response:match('<icon[^>]*>([^<]+)</icon>')
        if data then
            iconName = data
            -- print("Extracted icon name for item ID " .. itemId .. ": " .. iconName) -- Закомментировано для скрытия вывода
        else
            -- print("Failed to extract icon from API response for item ID " .. itemId) -- Закомментировано для скрытия вывода
        end
    else
        -- print("Failed to fetch icon from API for item ID " .. itemId) -- Закомментировано для скрытия вывода
    end

    return auctionConfig.itemIconDB .. iconName .. ".jpg"
end

local function GetPlayerIcon(player)
    local raceId = player:GetRace()
    local raceNames = {
        [1] = "human",
        [2] = "orc",
        [3] = "dwarf",
        [4] = "nightelf",
        [5] = "scourge",
        [6] = "tauren",
        [7] = "gnome",
        [8] = "troll",
        [10] = "bloodelf",
        [11] = "draenei"
    }
    local race = raceNames[raceId] or "unknown"
    local gender = player:GetGender() == 1 and "female" or "male"
    local iconURL = auctionConfig.itemIconDB .. 'race_' .. race .. '_' .. gender .. '.jpg'
    
    -- Логирование для отладки
    -- print("Race ID: " .. tostring(raceId)) -- Логирование ID расы
    -- print("Processed race: " .. race) -- Логирование обработанного значения расы
    -- print("Player gender: " .. gender) -- Логирование значения пола
    -- print("Generated player icon URL: " .. iconURL) -- Логирование URL иконки
     
    return iconURL
end

local function EscapeQuotes(text)
    text = string.gsub(text, '"', '\\"')
    text = string.gsub(text, "'", "\\'")
    return text
end

local function ConvertCopperToGoldSilverCopper(copper)
    local gold = math.floor(copper / 10000)
    local remaining = copper % 10000
    local silver = math.floor(remaining / 100)
    local remainingCopper = remaining % 100
    local combinedString = ""
    if gold > 0 then
        combinedString = combinedString .. tostring(gold) .. auctionConfig.goldEmojiID
    end
    if silver > 0 then
        combinedString = combinedString .. tostring(silver) .. auctionConfig.silverEmojiID
    end
    if remainingCopper > 0 then
        combinedString = combinedString .. tostring(remainingCopper) .. auctionConfig.copperEmojiID
    end
    return combinedString
end

local function ConvertSecondsToReadableTime(seconds)
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    return hours, minutes
end

local function OnAuctionAdd(event, auctionId, owner, item, expireTime, buyout, startBid, currentBid, bidderGUIDLow)
    local itemId = item:GetEntry()
    local iconURL = GetIconFromWoWHead(itemId)
    local itemName = GetItemNameInLocale(itemId, "ruRU") or item:GetName()
    local itemLevel = item:GetItemLevel()
    
    -- -- Логирование для отладки
    -- print("Item level: " .. tostring(itemLevel))
    -- print("Owner name: " .. owner:GetName())
    -- print("Item name: " .. itemName)

    local bodyStart = string.format(
        '{"content": null, "embeds": [{"title": "%s", "description": "Уровень предмета: %s", "url": "%s", "color": %d, "fields": [',
        EscapeQuotes(itemName),
        tostring(itemLevel),  -- Преобразование в строку для корректного форматирования
        auctionConfig.itemLinkDB .. 'item=' .. tostring(itemId),
        auctionConfig.itemQuality[item:GetQuality()].color
    )

    -- print("Generated bodyStart: " .. bodyStart) -- Логирование для отладки

    local fields = ""

    local listing = "Ставка: " .. ConvertCopperToGoldSilverCopper(startBid)
    if buyout > 0 then
        listing = listing .. "\\nВыкуп: " .. ConvertCopperToGoldSilverCopper(buyout)
    end

    fields = fields .. string.format('{"name": "Продается %d за","value": "%s"}', item:GetCount(), listing)

    local bodyEnd = string.format(
        '],"author": {"name": "%s Выставил", "icon_url": "%s"}, "footer": {"text": "Размещено до"}, "timestamp": "%s", "thumbnail": {"url":"%s"}}], "username": "%s", "avatar_url": "%s", "attachments": []}',
        owner:GetName(),
        GetPlayerIcon(owner),
        os.date("!%Y-%m-%dT%X.000Z", expireTime),
        iconURL,
        "Аукционный дом",
        auctionConfig.botImage
    )

    -- print("Generated bodyEnd: " .. bodyEnd) -- Логирование для отладки

    local message = bodyStart .. fields .. bodyEnd

    SendDiscordEmbed(message, auctionConfig.auctionWebhookURL)
end

RegisterServerEvent(26, OnAuctionAdd)

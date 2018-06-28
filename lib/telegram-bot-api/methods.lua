local _M = {
  VERSION = "3.5.0.1"
}

local json = require "cjson"
local lru, http, ltn12
if ngx then
  lru = require "resty.lrucache"
  http = require "resty.http"
else
  lru = require "lru"
  http = require "ssl.https"
  ltn12 = require "ltn12"
end

local c, err = lru.new(200)
if not c then
  return error("failed to create the cache: " .. (err or "unknown"))
end

function _M.init(bot_api_key, config)
  local server = "api.telegram.org"
  if config and config.server then
    server = config.server
  end
  _M.BASE_URL = "https://"..server.."/bot"..bot_api_key.."/"
  return _M
end

local function request(method, body)
  local res
  if ngx then -- Return the result of a resty.http request
    local arguments = {}
    if body then
      body = json.encode(body)
      arguments = {
        method = "POST",
        headers = {
          ["Content-Type"] = "application/json"
        },
        body = body
      }
      ngx.log(ngx.DEBUG, "Outgoing request: "..body)
    end
    local httpc = http.new()
    res, err = httpc:request_uri((_M.BASE_URL..method), arguments)
    if res then
      ngx.log(ngx.DEBUG, "Incoming reply: "..res.body)
      local tab = json.decode(res.body)
      if res.status == 200 and tab.ok then
        return tab.result
      else
        ngx.log(ngx.INFO, method.."() failed: "..tab.description)
        return false, tab
      end
    else
      ngx.log(ngx.ERR, err) -- HTTP request failed
    end
  else -- Return the result of a luasocket/luasec request
    local success
    local response_body = {}
    local arguments = {
      url = _M.BASE_URL..method,
      method = "POST",
      sink = ltn12.sink.table(response_body)
    }
    if body then
      body = json.encode(body)
      arguments.headers = {
        ["Content-Type"] = "application/json",
        ["Content-Length"] = body:len()
      }
      arguments.source = ltn12.source.string(body)
    end
    success, res = http.request(arguments)
    if success then
      local tab = json.decode(table.concat(response_body))
      if res == 200 and tab.ok then
        return tab.result
      else
        print("Failed: "..tab.description)
        return false, tab
      end
    else
      print("Connection error [" .. res .. "]")
    end
  end
end

local function is_table(value)
  if type(value) == "table" then
    return value
  else
    return nil
  end
end

local function assert_var(body, ...)
  for _,v in ipairs({...}) do
    assert(body[v], "Missing required variable "..v)
  end
end

local function check_id(body)
  if not body.inline_message_id then
    assert(body.chat_id, "Missing required variable chat_id")
    assert(body.message_id, "Missing required variable message_id")
  end
end

-- Getting updates

function _M.getUpdates(...)
  local args = {...}
  local body = is_table(args[1]) or {
      offset = args[1],
      limit = args[2],
      timeout = args[3],
      allowed_updates = args[4]
    }
  return request("getUpdates", body)
end

function _M.setWebhook(...)
  local args = {...}
  local body = is_table(args[1]) or {
    url = args[1],
    certificate = args[2],
    max_connections = args[3],
    allowed_updates = args[4]
  }
  assert_var(body, "url")
  request("setWebhook", body)
end

function _M.deleteWebhook()
  return request("deleteWebhook")
end

function _M.getWebhookInfo()
  return request("getWebhookInfo")
end

-- Available methods

function _M.getMe()
  local getMe = c:get("getMe")
  if getMe then
    return getMe
  else
    getMe = request("getMe")
    c:set("getMe", getMe)
    return getMe
  end
end

function _M.sendMessage(...)
  local args = {...}
  local body = is_table(args[1]) or {
    chat_id = args[1],
    text = args[2],
    parse_mode = args[3],
    disable_web_page_preview = args[4],
    disable_notification = args[5],
    reply_to_message_id = args[6],
    reply_markup = args[7]
  }
  assert_var(body, "chat_id", "text")
  return request("sendMessage", body)
end

function _M.forwardMessage(...)
  local args = {...}
  local body = is_table(args[1]) or {
    chat_id = args[1],
    from_chat_id = args[2],
    message_id = args[3],
    disable_notification = args[4]
  }
  assert_var(body, "chat_id", "from_chat_id", "message_id")
  return request("forwardMessage", body)
end

function _M.sendPhoto(...)
  local args = {...}
  local body = is_table(args[1]) or {
    chat_id = args[1],
    photo = args[2],
    caption = args[3],
    disable_notification = args[4],
    reply_to_message_id = args[5],
    reply_markup = args[6]
  }
  assert_var(body, "chat_id", "photo")
  return request("sendPhoto", body)
end

function _M.sendAudio(...)
  local args = {...}
  local body = is_table(args[1]) or {
    chat_id = args[1],
    audio = args[2],
    caption = args[3],
    duration = args[4],
    performer = args[5],
    title = args[6],
    disable_notification = args[7],
    reply_to_message_id = args[8],
    reply_markup = args[9]
  }
  assert_var(body, "chat_id", "audio")
  return request("sendAudio", body)
end

function _M.sendDocument(...)
  local args = {...}
  local body = is_table(args[1]) or {
    chat_id = args[1],
    document = args[2],
    caption = args[3],
    disable_notification = args[4],
    reply_to_message_id = args[5],
    reply_markup = args[6]
  }
  assert_var(body, "chat_id", "document")
  return request("sendDocument", body)
end

function _M.sendVideo(...)
  local args = {...}
  local body = is_table(args[1]) or {
    chat_id = args[1],
    video = args[2],
    duration = args[3],
    width = args[4],
    height = args[5],
    caption = args[6],
    disable_notification = args[7],
    reply_to_message_id = args[8],
    reply_markup = args[9]
  }
  assert_var(body, "chat_id", "video")
  return request("sendVideo", body)
end

function _M.sendVoice(...)
  local args = {...}
  local body = is_table(args[1]) or {
    chat_id = args[1],
    voice = args[2],
    duration = args[3],
    caption = args[4],
    disable_notification = args[5],
    reply_to_message_id = args[6],
    reply_markup = args[7]
  }
  assert_var(body, "chat_id", "voice")
  return request("sendVoice", body)
end

function _M.sendVideoNote(...)
  local args = {...}
  local body = is_table(args[1]) or {
    chat_id = args[1],
    video_note = args[2],
    duration = args[3],
    lenght = args[4],
    disable_notification = args[5],
    reply_to_message_id = args[6],
    reply_markup = args[7]
  }
  assert_var(body, "chat_id", "video_note")
  return request("sendVideoNote", body)
end

function _M.sendMediaGroup(...)
  local args = {...}
  local body = is_table(args[1]) or {
    chat_id = args[1],
    media = args[2],
    disable_notification = args[3],
    reply_to_message_id = args[4]
  }
  assert_var(body, "chat_id", "media")
  return request("sendMediaGroup", body)
end

function _M.sendLocation(...)
  local args = {...}
  local body = is_table(args[1]) or {
    chat_id = args[1],
    latitude = args[2],
    longitude = args[3],
    live_period = args[4],
    disable_notification = args[5],
    reply_to_message_id = args[6],
    reply_markup = args[7]
  }
  assert_var(body, "chat_id", "latitude", "longitude")
  return request("sendLocation", body)
end

function _M.editMessageLiveLocation(...)
  local args = {...}
  local body = is_table(args[1]) or {
    chat_id = args[1],
    message_id = args[2],
    inline_message_id = args[3],
    latitude = args[4],
    longitude = args[5],
    reply_markup = args[6]
  }
  check_id(body)
  assert_var(body, "latitude", "longitude")
  return request("editMessageLiveLocation", body)
end

function _M.stopMessageLiveLocation(...)
  local args = {...}
  local body = is_table(args[1]) or {
    chat_id = args[1],
    message_id = args[2],
    inline_message_id = args[3],
    reply_markup = args[4]
  }
  check_id(body)
  return request("editMessageLiveLocation", body)
end

function _M.sendVenue(...)
  local args = {...}
  local body = is_table(args[1]) or {
    chat_id = args[1],
    latitude = args[2],
    longitude = args[3],
    title = args[4],
    address = args[5],
    foursquare_id = args[6],
    disable_notification = args[7],
    reply_to_message_id = args[8],
    reply_markup = args[9]
  }
  assert_var(body, "chat_id", "latitude", "longitude", "title", "address")
  return request("sendVenue", body)
end

function _M.sendContact(...)
  local args = {...}
  local body = is_table(args[1]) or {
    chat_id = args[1],
    phone_number = args[2],
    first_name = args[3],
    last_name = args[4],
    disable_notification = args[5],
    reply_to_message_id = args[6],
    reply_markup = args[7]
  }
  assert_var(body, "chat_id", "phone_number", "first_name")
  return request("sendContact", body)
end

function _M.sendChatAction(...)
  local args = {...}
  local body = is_table(args[1]) or {
    chat_id = args[1],
    action = args[2]
  }
  assert_var(body, "chat_id", "action")
  return request("sendChatAction", body)
end

function _M.getUserProfilePhotos(...)
  local args = {...}
  local body = is_table(args[1]) or {
    user_id = args[1],
    offset = args[2],
    limit = args[3]
  }
  assert_var(body, "user_id")
  return request("getUserProfilePhotos", body)
end

function _M.getFile(file_id)
  local body = is_table(file_id) or {
    file_id = file_id
  }
  assert_var(body, "file_id")
  return request("getFile", body)
end

function _M.kickChatMember(...)
  local args = {...}
  local body = is_table(args[1]) or {
    chat_id = args[1],
    user_id = args[2],
    until_date = args[3]
  }
  assert_var(body, "chat_id", "user_id")
  return request("kickChatMember", body)
end

function _M.unbanChatMember(...)
  local args = {...}
  local body = is_table(args[1]) or {
    chat_id = args[1],
    user_id = args[2]
  }
  assert_var(body, "chat_id", "user_id")
  return request("unbanChatMember", body)
end

function _M.restrictChatMember(...)
  local args = {...}
  local body = is_table(args[1]) or {
    chat_id = args[1],
    user_id = args[2],
    until_date = args[3],
    can_send_messages = args[4],
    can_send_media_messages = args[5],
    can_send_other_messages = args[6],
    can_add_web_page_previews = args[7]
  }
  assert_var(body, "chat_id", "user_id")
  return request("restrictChatMember", body)
end

function _M.promoteChatMember(...)
  local args = {...}
  local body = is_table(args[1]) or {
    chat_id = args[1],
    user_id = args[2],
    can_change_info = args[3],
    can_post_messages = args[4],
    can_edit_messages = args[5],
    can_delete_messages = args[6],
    can_invite_users = args[7],
    can_restrict_members = args[8],
    can_pin_messages = args[9],
    can_promote_members = args[10]
  }
  assert_var(body, "chat_id", "user_id")
  return request("promoteChatMember", body)
end

function _M.exportChatInviteLink(chat_id)
  local body = is_table(chat_id) or {
    chat_id = chat_id
  }
  assert_var(body, "chat_id")
  return request("exportChatInviteLink", body)
end

function _M.setChatPhoto(...)
  local args = {...}
  local body = is_table(args[1]) or {
    chat_id = args[1],
    photo = args[2]
  }
  assert_var(body, "chat_id", "photo")
  return request("setChatPhoto", body)
end

function _M.deleteChatPhoto(chat_id)
  local body = is_table(chat_id) or {
    chat_id = chat_id
  }
  assert_var(body, "chat_id")
  return request("deleteChatPhoto", body)
end

function _M.setChatTitle(...)
  local args = {...}
  local body = is_table(args[1]) or {
    chat_id = args[1],
    title = args[2]
  }
  assert_var(body, "chat_id", "title")
  return request("setChatTitle", body)
end

function _M.setChatDescription(...)
  local args = {...}
  local body = is_table(args[1]) or {
    chat_id = args[1],
    description = args[2]
  }
  assert_var(body, "chat_id", "description")
  return request("setChatDescription", body)
end

function _M.pinChatMessage(...)
  local args = {...}
  local body = is_table(args[1]) or {
    chat_id = args[1],
    message_id = args[2],
    disable_notification = args[3]
  }
  assert_var(body, "chat_id", "message_id")
  return request("pinChatMessage", body)
end

function _M.unpinChatMessage(chat_id)
  local body = is_table(chat_id) or {
    chat_id = chat_id
  }
  assert_var(body, "chat_id")
  return request("unpinChatMessage", body)
end

function _M.leaveChat(chat_id)
  local body = is_table(chat_id) or {
    chat_id = chat_id
  }
  assert_var(body, "chat_id")
  return request("leaveChat", body)
end

function _M.getChat(chat_id)
  local body = is_table(chat_id) or {
    chat_id = chat_id
  }
  assert_var(body, "chat_id")
  return request("getChat", body)
end

function _M.getChatAdministrators(chat_id)
  local body = is_table(chat_id) or {
    chat_id = chat_id
  }
  assert_var(body, "chat_id")
  return request("getChatAdministrators", body)
end

function _M.getChatMembersCount(chat_id)
  local body = is_table(chat_id) or {
    chat_id = chat_id
  }
  assert_var(body, "chat_id")
  return request("getChatMembersCount", body)
end

function _M.getChatMember(...)
  local args = {...}
  local body = is_table(args[1]) or {
    chat_id = args[1],
    user_id = args[2]
  }
  assert_var(body, "chat_id", "user_id")
  return request("getChatMember", body)
end

function _M.setChatStickerSet(...)
  local args = {...}
  local body = is_table(args[1]) or {
    chat_id = args[1],
    sticker_set_name = args[2]
  }
  assert_var(body, "chat_id", "sticker_set_name")
  return request("setChatStickerSet", body)
end

function _M.deleteChatStickerSet(chat_id)
  local body = is_table(chat_id) or {
    chat_id = chat_id,
  }
  assert_var(body, "chat_id")
  return request("setChatStickerSet", body)
end

function _M.answerCallbackQuery(...)
  local args = {...}
  local body = is_table(args[1]) or {
    callback_query_id = args[1],
    text = args[2],
    show_alert = args[3],
    cache_time = args[4]
  }
  assert_var(body, "callback_query_id")
  return request("answerCallbackQuery", body)
end

-- Updating messages

function _M.editMessageText(...)
  local args = {...}
  local body = is_table(args[1]) or {
    chat_id = args[1],
    message_id = args[2],
    inline_message_id = args[3],
    text = args[4],
    parse_mode = args[5],
    disable_web_page_preview = args[6],
    reply_markup = args[7]
  }
  check_id(body)
  assert_var(body, "text")
  return request("editMessageText", body)
end

function _M.editMessageCaption(...)
  local args = {...}
  local body = is_table(args[1]) or {
    chat_id = args[1],
    message_id = args[2],
    inline_message_id = args[3],
    caption = args[4],
    reply_markup = args[5]
  }
  check_id(body)
  return request("editMessageCaption", body)
end

function _M.editMessageReplyMarkup(...)
  local args = {...}
  local body = is_table(args[1]) or {
    chat_id = args[1],
    message_id = args[2],
    inline_message_id = args[3],
    reply_markup = args[4]
  }
  check_id(body)
  return request("editMessageReplyMarkup", body)
end

function _M.deleteMessage(...)
  local args = {...}
  local body = is_table(args[1]) or {
    chat_id = args[1],
    message_id = args[2]
  }
  assert_var(body, "chat_id", "message_id")
  return request("deleteMessage", body)
end

-- Stickers

function _M.sendSticker(...)
  local args = {...}
  local body = is_table(args[1]) or {
    chat_id = args[1],
    sticker = args[2],
    caption = args[3],
    disable_notification = args[4],
    reply_to_message_id = args[5],
    reply_markup = args[6]
  }
  assert_var(body, "chat_id", "sticker")
  return request("sendSticker", body)
end

function _M.getStickerSet(name)
  local body = is_table(name) or {
    name = name
  }
  assert_var(body, "name")
  return request("getSticker", body)
end

function _M.uploadStickerFile(...)
  local args = {...}
  local body = is_table(args[1]) or {
    user_id = args[1],
    png_sticker = args[2]
  }
  assert_var(body, "user_id", "png_sticker")
  return request("uploadStickerFile", body)
end

function _M.createNewStickerSet(...)
  local args = {...}
  local body = is_table(args[1]) or {
    user_id = args[1],
    name = args[2],
    title = args[3],
    png_sticker = args[4],
    emojis = args[5],
    contains_masks = args[6],
    mask_position = args[7]
  }
  assert_var(body, "user_id", "name", "title", "png_sticker", "emojis")
  return request("createNewStickerSet", body)
end

function _M.addStickerToSet(...)
  local args = {...}
  local body = is_table(args[1]) or {
    user_id = args[1],
    name = args[2],
    png_sticker = args[3],
    emojis = args[4],
    mask_position = args[5]
  }
  assert_var(body, "user_id", "name", "png_sticker", "emojis")
  return request("addStickerToSet", body)
end

function _M.setStickerPositionInSet(...)
  local args = {...}
  local body = is_table(args[1]) or {
    sticker = args[1],
    position = args[2]
  }
  assert_var(body, "sticker", "position")
  return request("setStickerPositionInSet", body)
end

function _M.deleteStickerFromSet(sticker)
  local body = is_table(sticker) or {
    sticker = sticker
  }
  assert_var(body, "sticker")
  return request("deleteStickerFromSet", body)
end

-- Inline mode

function _M.answerInlineQuery(...)
  local args = {...}
  local body = is_table(args[1]) or {
    inline_query_id = args[1],
    results = args[2],
    cache_time = args[3],
    is_personal = args[4],
    switch_pm_text = args[5],
    switch_pm_parameter = args[6]
  }
  assert_var(body, "inline_query_id", "results")
  return request("answerInlineQuery", body)
end

-- Payments

function _M.sendInvoice(...)
  local args = {...}
  local body = is_table(args[1]) or {
    chat_id = args[1],
    title = args[2],
    description = args[3],
    payload = args[4],
    provider_token = args[5],
    start_parameter = args[6],
    currency = args[7],
    prices = args[8],
    photo_url = args[9],
    photo_width = args[10],
    photo_height = args[11],
    need_name = args[12],
    need_phone_number = args[13],
    need_email = args[14],
    need_shipping_address = args[15],
    send_phone_number_to_provider = args[16],
    send_email_to_provider = args[17],
    is_flexible = args[18],
    disable_notification = args[19],
    reply_to_message_id = args[20],
    reply_markup = args[21]
  }
  assert_var(body, "chat_id", "title", "description", "payload", "provider_token", "start_parameter", "currency", "prices")
  return request("sendInvoice", body)
end

function _M.answerShippingQuery(...)
  local args = {...}
  local body = is_table(args[1]) or {
    shipping_query_id = args[1],
    ok = args[2],
    shipping_options = args[3],
    error_message = args[4]
  }
  assert_var(body, "shipping_query_id")
  if body.ok then
    assert(body.shipping_options, "Missing required variable shipping_options")
  else
    assert(body.error_message, "Missing required variable error_message")
  end
  return request("answerShippingQuery", body)
end

function _M.answerPreCheckoutQuery(...)
  local args = {...}
  local body = is_table(args[1]) or {
    pre_checkout_query_id = args[1],
    ok = args[2],
    error_message = args[3]
  }
  assert_var(body, "pre_checkout_query_id")
  if not body.ok then
    assert(body.error_message, "Missing required variable error_message")
  end
  return request("answerPreCheckoutQuery", body)
end

-- Games

function _M.sendGame(...)
  local args = {...}
  local body = is_table(args[1]) or {
    chat_id = args[1],
    game_short_name = args[2],
    disable_notification = args[3],
    reply_to_message_id = args[4],
    reply_markup = args[5]
  }
  assert_var(body, "chat_id", "game_short_name")
  request("sendGame", body)
end

function _M.setGameScore(...)
  local args = {...}
  local body = is_table(args[1]) or {
    user_id = args[1],
    score = args[2],
    force = args[3],
    disable_edit_message = args[4],
    chat_id = args[5],
    message_id = args[6],
    inline_message_id = args[7]
  }
  check_id(body)
  assert_var(body, "user_id", "score")
  return request("setGameScore", body)
end

function _M.getGameHighScores(...)
  local args = {...}
  local body = is_table(args[1]) or {
    user_id = args[1],
    chat_id = args[2],
    message_id = args[3],
    inline_message_id = args[4]
  }
  check_id(body)
  assert_var(body, "user_id")
  return request("getGameHighScores", body)
end

-- Passthrough unknown methods

function _M.Custom(_, method)
  print("Using custom method "..method)
  return function(body)
    return request(method, body)
  end
end

setmetatable(_M, { __index = _M.Custom })

-- Snake case shortcuts for known methods

_M.get_updates = _M.getUpdates
_M.set_webhook = _M.setWebhook
_M.delete_webhook = _M.deleteWebhook
_M.get_webhook_info = _M.getWebhookInfo
_M.get_me = _M.getMe
_M.send_message = _M.sendMessage
_M.forward_message = _M.forwardMessage
_M.send_photo = _M.sendPhoto
_M.send_audio = _M.sendAudio
_M.send_document = _M.sendDocument
_M.send_video = _M.sendVideo
_M.send_voice = _M.sendVoice
_M.send_video_note = _M.sendVideoNote
_M.send_media_group = _M.sendMediaGroup
_M.send_location = _M.sendLocation
_M.edit_message_live_location = _M.editMessageLiveLocation
_M.stop_message_live_location = _M.stopMessageLiveLocation
_M.send_venue = _M.sendVenue
_M.send_contact = _M.sendContact
_M.send_chat_action = _M.sendChatAction
_M.get_user_profile_photos = _M.getUserProfilePhotos
_M.get_file = _M.getFile
_M.kick_chat_member = _M.kickChatMember
_M.unban_chat_member = _M.unbanChatMember
_M.restrict_chat_member = _M.restrictChatMember
_M.promote_chat_member = _M.promoteChatMember
_M.export_chat_invite_link = _M.exportChatInviteLink
_M.set_chat_photo = _M.setChatPhoto
_M.delete_chat_photo = _M.deleteChatPhoto
_M.set_chat_title = _M.setChatTitle
_M.set_chat_description = _M.setChatDescription
_M.pin_chat_message = _M.pinChatMessage
_M.unpin_chat_message = _M.unpinChatMessage
_M.leave_chat = _M.leaveChat
_M.get_chat = _M.getChat
_M.get_chat_administrators = _M.getChatAdministrators
_M.get_chat_members_count = _M.getChatMembersCount
_M.get_chat_member = _M.getChatMember
_M.set_chat_sticker_set = _M.setChatStickerSet
_M.delete_chat_sticker_set = _M.deleteChatStickerSet
_M.answer_callback_query = _M.answerCallbackQuery
_M.edit_message_text = _M.editMessageText
_M.edit_message_caption = _M.editMessageCaption
_M.edit_message_replymarkup = _M.editMessageReplyMarkup
_M.delete_message = _M.deleteMessage
_M.send_sticker = _M.sendSticker
_M.get_sticker_set = _M.getStickerSet
_M.upload_sticker_file = _M.uploadStickerFile
_M.create_new_sticker_set = _M.createNewStickerSet
_M.add_sticker_to_set = _M.addStickerToSet
_M.set_sticker_position_in_set = _M.setStickerPositionInSet
_M.delete_sticker_from_set = _M.deleteStickerFromSet
_M.answer_inline_query = _M.answerInlineQuery
_M.send_invoice = _M.sendInvoice
_M.answer_shipping_query = _M.answerShippingQuery
_M.answer_pre_checkout_query = _M.answerPreCheckoutQuery
_M.send_game = _M.sendGame
_M.set_game_score = _M.setGameScore
_M.get_game_high_scores = _M.getGameHighScores

return _M

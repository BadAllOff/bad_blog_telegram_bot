require 'rss'
require 'telegram/bot'

token = ENV['TELEGRAM_BAD_BLOG_BOT_API_KEY']
url = 'http://badalloff.science/feed?locale=en'

Telegram::Bot::Client.run(token) do |bot|
  bot.listen do |message|
    case message.text
    when '/start'
      bot.api.send_message(chat_id: message.chat.id, text: "Hello, #{message.from.first_name}")
    when '/stop'
      bot.api.send_message(chat_id: message.chat.id, text: "Bye, #{message.from.first_name}")
    when '/rss'
      rss = RSS::Parser.parse(url, false)
      rss.items.each do |item|
        bot.api.sendMessage(chat_id: message.chat.id, text: item.title)
      end
    when '/send_to_rubyhack'
      rss = RSS::Parser.parse(url, false)
      rss.items.each do |item|
        bot.api.sendMessage(chat_id: '@rubyhack', text: item.title)
      end
    end
  end
end
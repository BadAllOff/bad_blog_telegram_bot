require 'rss'
require 'telegram/bot'
require 'sdbm'
require 'json'
require 'logger'

logger = Logger.new(STDOUT)
url = 'http://badalloff.science/feed?locale=ru'
rss = RSS::Parser.parse(url, false)

if ENV['TELEGRAM_BAD_BLOG_BOT_API_KEY'].nil?
  logger.fatal 'Environment variable TELEGRAM_BAD_BLOG_BOT_API_KEY not set!'
  exit 0
else
  token = ENV['TELEGRAM_BAD_BLOG_BOT_API_KEY']
end



SDBM.open 'bad_posts.db' do |posts|
  rss.items.each do |item|
    key       = item.link
    title     = item.title
    pubDate = item.pubDate
    # next if posts[key]
    if posts.has_key?(key)
      logger.info 'Post exist in DB will not rewrite'
    else
      posts[key] = JSON.dump(
        title: title,
        pubDate: pubDate,
        sended: 0
      )
    end
  end

  hash = {}
  posts.each do |key, value|
    hash[key] = JSON.parse(value)
    if hash[key]['sended'] == 0
      text = "Новая запись в блоге: \n\n #{hash[key]["title"]} - #{key}"
      Telegram::Bot::Client.run(token) do |bot|
        if bot.api.sendMessage(chat_id: '@rubyhack', text: text)
          posts[key] = JSON.dump(
            title: hash[key]['title'],
            pubDate: hash[key]['pubDate'],
            sended: 1
          )
          logger.info "Successfuly send #{hash[key]} to telegram!"
        else
          logger.error "Can not send #{hash[key]} to telegram!"
        end
      end
    end
  end
end
require 'rss'
require 'telegram/bot'
require 'sdbm'
require 'json'
require 'logger'
require 'pg'

class BadBlogTelegramBot

  def initialize(url, channel)
    @logger   = Logger.new(STDOUT)

    if ENV['TELEGRAM_BAD_BLOG_BOT_API_KEY'].nil?
      @logger.fatal "Environment variable TELEGRAM_BAD_BLOG_BOT_API_KEY not set!"
      exit 0
    else
      @token = ENV['TELEGRAM_BAD_BLOG_BOT_API_KEY']
    end

    @url      = url
    @channel  = channel
    # uri       = URI.parse(ENV['BAD_BOT_DATABASE_URL'])

    @db       = PG::Connection.open(dbname: 'bad_bot_db') #PG.connect(uri.hostname, uri.port, nil, nil, uri.path[1..-1], uri.user, uri.password)
    @rss      = RSS::Parser.parse(url, false)

    @db.exec("CREATE TABLE IF NOT EXISTS posts (id serial, url varchar(450) NOT NULL, sended bool DEFAULT false)")
    @db.exec("ALTER TABLE posts ADD COLUMN IF NOT EXISTS title varchar(200) DEFAULT 'title' NOT NULL")
  end

  def sync
    @rss.items.each do |item|
      url = item.link
      if @db.exec("SELECT exists (SELECT 1 FROM posts WHERE url = '#{url}' LIMIT 1)::int").values[0][0].to_i == 1
        @logger.info "Post exist in DB will not rewrite"
      else
        if @db.exec("INSERT INTO posts (url) VALUES ('#{url}')")
          @logger.info "Write post to DB #{url}"
        end
      end
    end
  end

  def send
    urls = @db.exec("SELECT url FROM posts WHERE sended = false")
    urls.each do |url|
      text = "Новая запись в блоге - #{url['url']}"
      if telegram_send(text)
        @db.exec("UPDATE posts SET sended = true WHERE url = '#{url['url']}'")
      end
    end
  end

  private

  def telegram_send(message)
    Telegram::Bot::Client.run(@token) do |bot|
      if bot.api.sendMessage(chat_id: "#{@channel}", text: message)
        @logger.info "Successfuly send #{message} to telegram!"
        true
      else
        @logger.error "Can not send #{message} to telegram!"
        false
      end
    end
  end
end
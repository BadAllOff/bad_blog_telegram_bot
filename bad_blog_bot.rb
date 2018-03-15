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

    if ENV['TELEGRAM_BAD_BLOG_OWNER_ID'].nil?
      @logger.fatal "Environment variable TELEGRAM_BAD_BLOG_OWNER_ID not set!"
      exit 0
    else
      @owner = ENV['TELEGRAM_BAD_BLOG_OWNER_ID']
    end

    @url      = url
    @channel  = channel
    if BOT_ENV == 'development'
      @db       = PG::Connection.open(dbname: 'bad_bot_db')
    else
      @db       = PG::Connection.new(ENV['HEROKU_POSTGRESQL_CYAN_URL'])
    end
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
        if @db.exec("INSERT INTO posts (url, title) VALUES ('#{url}', '#{item.title}')")
          @logger.info "Write post to DB #{url}"
        end
      end
    end
  end

  def send
    posts = @db.exec("SELECT url, title FROM posts WHERE sended = false")
    if posts.any?
      posts.each do |post|
        message = "Новая запись в блоге: \n #{post['title']} \n #{post['url']}"
        if telegram_send(message)
          @db.exec("UPDATE posts SET sended = true WHERE url = '#{post['url']}'")
        end
      end
    else
      @channel = @owner
      message = "Cегодня: #{(Time.now).strftime('%d/%m/%Y')} \n В блоге ничего нового не опубликовано."
      telegram_send(message)
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
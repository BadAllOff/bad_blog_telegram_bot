#!/usr/bin/env ruby
require_relative '../bad_blog_bot'
BOT_ENV = ENV['BOT_ENVIRONMENT']

telegram = BadBlogTelegramBot.new('http://badalloff.science/feed?locale=ru', '@rubyhack')
telegram.sync
telegram.send
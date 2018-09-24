#!/usr/bin/env ruby

require 'net/http'
require 'optparse'

class Options

  @conf = {}

  class << self
    attr_reader :conf

    def run(args)

      OptionParser.new do |opts|
        opts.banner = 'Usage: pwdgen [options]'
        opts.separator ''
        opts.separator 'Generate a random password from an API which returns one word at a time'
        opts.separator ''
        opts.separator 'Options:'

        opts.on '-x', '--proxy HOST', 'Proxy host in format hostname:port' do |proxy|
          puts "using proxy: #{ proxy }"
          @conf[ :proxy ] = proxy
        end

        opts.on '-u', '--proxy-user USER', 'Proxy user' do |user|
          @conf[ :user ] = user
        end

        opts.on '-p', '--proxy-pass PASSWORD', 'Proxy password' do |pass|
          @conf[ :pass ] = pass
        end

        opts.on '-s', '--uri URI', 'Source uri from which to retrieve words' do |uri|
          @conf[ :uri ] = uri
        end

        opts.on '-l', '--special [COUNT]', 'Number of special chars to insert' do |special|
          @conf[ :special ] = special.to_i
        end

        opts.on '-n', '--numbers [COUNT]', 'Number of numerical chars to insert' do |numbers|
          @conf[ :nums ] = numbers.to_i
        end

        opts.on '-c', '--upper-case [COUNT]', 'Number of chars to make upper case' do |ucase|
          @conf[ :uppers ] = ucase.to_i
        end

        opts.on '-w', '--words [COUNT]', 'Number of words to pull. Default is 2' do |words|
          @conf[ :words ] = words.to_i
        end
      end.parse! args
      @conf[ :special ] = @conf[ :special ] || 1
      @conf[ :nums ] = @conf[ :nums ] || 1
      @conf[ :uppers ] = @conf[ :uppers ] || 1
      @conf[ :words ] = @conf[ :words ] || 2
    end
  end
end


class Password

  @words = []
  @subs = {
    special: 
}


  class << self

    def generate(source, wc: 2, nums: 0, spec: 0, ups: 0)
      1.upto wc do
        @words << source.next
      end
      puts @words
    end
  end
end


class Words

  def initialize(uri=nil, proxy=nil, port=nil, user=nil, pass=nil)
    @source = uri || 'http://watchout4snakes.com/wo4snakes/Random/RandomWord/'
    @uri = URI @source
    @proxy = proxy || 'binnacle.nfcu.net'
    @port = port || 8080
    @user = user
    @pass = pass
  end

  def next
    Net::HTTP.new(@uri.host, nil, @proxy, @port).start do |http|
      http.proxy_user = @user
      http.proxy_pass = @pass
      http.request Net::HTTP::Post.new @uri
    end.body
  end
end

Options.run ARGV
conf = Options.conf
words = Words.new conf[ :uri ], conf[ :proxy ], conf[ :port ], conf[ :user ], conf[ :pass ]
Password.generate words, wc: conf[ :words ], nums: conf[ :nums ], spec: conf[ :special ], ups: conf[ :uppers ]


# Options:
# -p: proxy address in form host:port
# -pu: proxy user
# -pp: proxy password
# -uri: source uri from which to pull words
# -s [N]: use N special chars
# -n [N]: use N numbers
# -u [N]: use N upper-case letters
# -w [N]: use N words

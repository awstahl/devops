#!/usr/bin/env ruby

require 'optparse'
require 'socket'

class Listener

  @@sockets = {}
  @@sockets['tcp'] = Proc.new {|port| TCPServer.new('0.0.0.0', port).close }
  @@sockets['udp'] = Proc.new {|port| udp = UDPSocket.new; udp.bind '0.0.0.0', port; udp.close }

  attr_accessor :monitor
  attr_reader :app, :host, :hosts, :path, :port, :protocol

  def initialize(path, port, proto)
    @host = ENV['HOSTNAME']
    @hosts = {}
    @path = (File.exist? path) ? path : (raise Errno::ENOENT)
    @app = File.basename @path
    @logging = false
    @monitor = false

    Dir.entries(@path).each do |dir|
      if File.directory? "#@path/#{ dir}" and dir !~ /^(\.|127\.)/
        @hosts[ dir ] = Dir.entries("#@path/#{ dir }").select {|log| log =~ /\.log(\.gz)?$/ }
        @logging = true unless @hosts[ dir ].empty?
      end
    end
    @port = port.to_i
    @protocol = proto
  end

  def listening?
    begin
      @@sockets[ @protocol ].call @port
    rescue Errno::EADDRINUSE
      return true
    end
    return false
  end

  def logging?
    @logging
  end

  def migrate?
    listening? && logging? && monitored?
  end

  # It's not a WTF if you want 'true' instead of @monitor
  def monitored?
    @monitor ? true : false
  end

  def query
    "source = #@path/*"
  end

  def pcap
    "#@protocol port #@port"
  end

  def to_s
    "#@host:#@path:#@port:#@protocol"
  end

end


# Scan directory for confs & return as array of Listeners
# No, it's not actually a factory...
class ListenerFactory

  def self.produce(path)
    return [] unless File.directory? path
    confs = Dir.entries(path).select {|file| file =~ /\.conf$/ }.sort.map {|file| "#{ path }/#{ file }" }
    return [] if confs.empty?

    listeners = []
    monitors = Parser.splunk
    confs.each do |conf|
      listeners += Parser.syslog(conf)
    end
    listeners.each do |listener|
      listener.monitor = monitors.grep /#{ listener.path }/
    end
    listeners
  end
end


# Parse a conf file into one or more Listener objects
class Parser

  class Splunk
  
    CMD = '/opt/splunkforwarder/bin/splunk'

    def self.method_missing(meth, *args, &block)
     ( `#{ CMD } btool #{ meth } list` ).split "\n"
    end
  end

  # OBS: is it a hard-coded parser? YES. Is it dependency injected? NO.
  # Is it DRY? NO. Is it good enough for now? YES.
  def self.syslog(conf)
    content = File.open(conf).read
    protocols = []
    ports = []
    listeners = []

    content.grep /(tc|ud)pserverrun\s\d+$/i do |server|
      protocols << server[/(tc|ud)p/i].downcase
      ports << server[/\d+$/]
    end

    path = content.grep /genericlogs/i do |template|
      template[/\/syslog\/rsyslog-remote\/.+?(?=\/%)/]
    end.first

    protocols.each_index do |i|
      listeners << Listener.new(path, ports[i], protocols[i])
    end
    listeners
  end

  def self.splunk
    inputs = Splunk.inputs
    monitors = inputs.grep /^\[monitor:\/\/.+\.log\]$/ do |monitor|
      monitor[/(\/(\w|-)+(?=\/)){3,}.+\.log(?=\])/] if monitor !~ /\/opt\/splunk/
    end.compact
  end
end


class Listeners

  attr_reader :listeners

  @@filters = {}


  def initialize(path)
    @listeners = ListenerFactory.produce path
  end

  def filter
    puts "all your base are belong to us"
  end

end

opts = OptionParser.new do |opts|

  opts.banner = 'Usage: rsyslog-forensics [options]'
  opts.separator ''
  opts.separator "Options:"

  opts.on('-d', '--dir [DIRECTORY]', 'Path to syslog configuration directoyr') do |dir|
    listeners = Listeners.new dir
  end

  opts.on('-p', '--pcap [PORT]', 'Output a pcap filter string') do |port|
    # puts "werd. pcaps. awesome."
    # LOLWAT when did we get to javaland?
    listeners.listeners.any? {|listener| listener.port == port }.each {|listener| listener.pcap }
  end 
end

listeners = ''
opts.parse! ARGV

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
    @host = `hostname`.strip
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
    @port = port
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
    "#@protocol:#@port"
  end

  def to_s
    "#@host:#@path:#@port:#@protocol"
  end
end


# Scan directory for confs & return as array of Syslog
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


class Syslog

  attr_reader :listeners

  def initialize(path)
    @listeners = ListenerFactory.produce path
  end
end


class RForensic

  def self.run(args)
    syslog = nil

    OptionParser.new do |opts|
      opts.banner = 'Usage: rsyslog-forensics [options]'
      opts.separator ''
      opts.separator "Options:"

      opts.on '-d', '--dir [DIRECTORY]', 'Path to syslog configuration directoyr'  do |dir|
        syslog = Syslog.new dir
      end

      #'OBS: next few opts are soaking wet... fix later, in a hurry now.

      opts.on '-a', '--all', 'Print all syslog conf data'  do
        syslog.listeners.each {|listener| puts listener.to_s }
      end

      opts.on '-m', '--migrate', 'Print all syslog confs in use' do
        syslog.listeners.each {|listener| puts listener.to_s if listener.migrate? }
      end

      opts.on '-M', '--nomigrate', 'Print all syslog confs not in use' do
        syslog.listeners.each {|listener| puts listener.to_s if not listener.migrate? }
      end

      opts.on '-p', '--pcap [APP]', 'Output a pcap filter string' do |app|
        apps = syslog.listeners.select {|listener| listener.app == app }
        apps.each {|listener| puts listener.pcap } if not apps.empty?
      end

      opts.on '-q', '--query [APP]', 'Generate a query string for use in splunk search' do |app|
        apps = syslog.listeners.select {|listener| listener.app =~ /#{ app }/ }
        puts apps.map {|listener| listener.query }.uniq.join " OR " if not apps.empty?
      end
 
    end.parse! args
  end
end

RForensic.run ARGV

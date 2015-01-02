#!/bin/env ruby

require "io/console"
require_relative "../lib/nicolivedl"
require "optparse"

email = nil
lvid = nil
file = nil

opt = OptionParser.new
opt.on("-e EMAIL", "--email=EMAIL", "login email") { |v| email = v }
opt.on("-l LIVEID", "--liveid=LIVEID", "nicolive id (ex: lv12345)") { |v| lvid = v }
opt.on("-o FILE", "--output=FILE", "output file path") { |v| file = v }

opt.parse!(ARGV)

if email.nil? or lvid.nil?
  print "Error: insufficient argument\n"
  exit 1
end

begin
  nico = NicoLiveDownloader.new

  unless nico.login_with_stored_session(email) and nico.getplayerstatus(lvid)
    print "Enter password for user: #{email}\n"
    password = STDIN.noecho(&:gets).chomp
    nico.login(email, password)
    nico.getplayerstatus(lvid)
  end

  nico.download(file)
rescue => e
  p e.message
  exit 1
end

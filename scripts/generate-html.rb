#!/usr/bin/env ruby

require 'csv'
require 'json'
require 'erb'
require 'optparse'
require 'ipaddr'
require 'set'

title_source  = '...unknown...'
wiki_lang     = 'en'
twitter       = nil
page          = 0
year_range    = '2002-2010'
template_path = File.expand_path('../template.html.erb', __FILE__)

OptionParser.new do |opts|
  opts.on('-s', '--source SOURCE_NAME') { |s| title_source = s }
  opts.on('-t', '--twitter USERNAME') { |t| twitter = t }
  opts.on('-e', '--erb TEMPLATE_PATH') { |t| template_path = t }
  opts.on('-w', '--wiki WIKI_LANG') { |w| wiki_lang = w }
  opts.on('-h', '--help') { puts opts; exit 1 }
end.parse!(ARGV)

unless ARGV.size == 2
  abort "USAGE: #{$PROGRAM_NAME} <bigquery.csv> <ranges.json>"
end

data                 = File.read(ARGV.first)
ranges               = JSON.parse(File.read(ARGV.last)).fetch('ranges')
rows                 = CSV.parse(data, headers: true).map(&:to_hash)
actors               = ranges.keys.sort
years                = Set.new
actor_counts_by_year = Hash.new { |h, k| h[k] = Hash.new(0) }

range_to_actor = {}
ranges.each do |name, ranges_|
  ranges_.each do |left, right|

    if right.nil?
      range = IPAddr.new(left) # netmask
    else
      range = IPAddr.new(left).to_i..IPAddr.new(right).to_i
    end

    range_to_actor[range] = name
  end
end

rows.each do |row|
  ip_int = IPAddr.new(row['contributor_ip']).to_i
  actors = range_to_actor.select { |range, actor| range.include?(ip_int) }.map { |_, actor| actor }.compact

  if actors.empty?
    raise "no actor found for #{row.inspect}"
  end

  if actors.uniq.size > 1
    raise "multiple actors (#{actors.inspect}) for #{row.inspect}"
  end

  actor = actors.first
  time  = Time.at(row['timestamp'].to_i)

  row['time']       = time
  row['human_date'] = time.strftime("%F %H:%M:%S")
  row['source']     = actor

  years << time.year
  actor_counts_by_year[actor][time.year] += 1
end

actors = actor_counts_by_year.keys.compact.sort
chart_data = [["Year", *actors]]

years = years.sort
years.pop

years.each do |year|
  actor_values = actors.map { |a| actor_counts_by_year[a][year] }
  chart_data << [year.to_s, *actor_values]
end

rows = rows.sort_by { |e| -e['timestamp'].to_i }
year_range = "#{rows.last['time'].year}-#{rows.first['time'].year}"

template = File.read(template_path)
puts ERB.new(template, 0, "%-<>").result(binding)


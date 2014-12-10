#!/usr/bin/env ruby

require 'json'
require 'open-uri'
require 'ipaddr'
require 'optparse'

lang = 'en'
old = false
where = false

OptionParser.new { |o|
  o.on('-l', '--lang LANG', 'The wiki langauge to use') { |l| lang = l }
  o.on('-o', '--old', 'Use the old sample dataset (2002-2010).') { old = true }
  o.on('-w', '--where', 'Use a WHERE clause instead of HAVING') { where = true }
}.parse!(ARGV)

if ARGV.size != 1
  abort "USAGE: #{$PROGRAM_NAME} ranges.json"
end

if old && lang != 'en'
  abort "sample dataset is only for english wikipedia"
end

if old
  table_name = "publicdata:samples.wikipedia"
else
  table_name = "wikis.#{lang}"
end

template = <<SQL
SELECT
  #{old ? 'id' : 'page_id'},
  title,
  CONCAT("http://#{lang}.wikipedia.org/w/index.php?diff=", STRING(revision_id)) AS diff_url,
  revision_id,
  timestamp,
  contributor_ip,
  PARSE_IP(contributor_ip) as contributor_ip_int
FROM #{table_name}
#{where ? 'WHERE' : 'HAVING'} (
  %s
)
ORDER BY timestamp DESC
SQL

conditions = []

def find_range(netmask)
  range = IPAddr.new(netmask).to_range
  [range.first.to_s, range.last.to_s]
rescue IPAddr::InvalidAddressError => ex
  raise "invalid range: #{netmask.inspect} (#{ex.message} - #{ex.class})"
end

ranges = JSON.parse(open(ARGV.first).read).fetch('ranges')
ranges.each do |name, ranges|
  ranges.each do |start, stop, opts|
    STDERR.puts [start, stop, opts].inspect
    if stop.nil?
      start, stop = find_range(start)
    end

    STDERR.puts [start, stop].inspect

    if opts && opts['from'] && opts['to']
      date_condition = " AND (timestamp >= #{Time.parse(opts['from']).to_i} AND timestamp <= #{Time.parse(opts['to']).to_i})"
    else
      date_condition = ''
    end


    if where
      conditions << "(PARSE_IP(contributor_ip) >= PARSE_IP(#{start.inspect}) AND PARSE_IP(contributor_ip) <= PARSE_IP(#{stop.inspect})#{date_condition}) # #{name}"
    else
      conditions << "(contributor_ip_int >= PARSE_IP(#{start.inspect}) AND contributor_ip_int <= PARSE_IP(#{stop.inspect})#{date_condition}) # #{name}"
    end

  end
end

puts template % conditions.join("\n OR ")



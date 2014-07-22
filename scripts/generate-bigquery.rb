#!/usr/bin/env ruby

require 'json'
require 'open-uri'
require 'ipaddr'
require 'optparse'

lang = 'en'
old = false

OptionParser.new { |o|
  o.on('-w', '--wiki LANG', 'The wiki langauge to use') { |l| lang = l }
  o.on('-o', '--old', 'Use the old sample dataset (2002-2010).') { old = true }
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
HAVING (
  %s
)
ORDER BY timestamp DESC
SQL

conditions = []

def find_range(netmask)
  range = IPAddr.new().to_range
  [range.first.to_s, range.last.to_s]
rescue IPAddr::InvalidAddressError => ex
  raise "invalid range: #{netmask.inspect} (#{ex.message} - #{ex.class})"
end

ranges = JSON.parse(open(ARGV.first).read).fetch('ranges')
ranges.each do |name, ranges|
  ranges.each do |start, stop|
    if stop.nil?
      start, stop = find_range(start)
    end

    conditions << "(contributor_ip_int >= PARSE_IP(#{start.inspect}) AND contributor_ip_int <= PARSE_IP(#{stop.inspect})) # #{name}"
  end
end

puts template % conditions.join("\n OR ")



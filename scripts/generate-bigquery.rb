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
  SEC_TO_TIMESTAMP(timestamp) AS ts,
  timestamp,
  contributor_ip,
FROM #{table_name}
WHERE (
 %s
)
ORDER BY ts DESC
SQL

conditions = []

ranges = JSON.parse(open(ARGV.first).read).fetch('ranges')
ranges.each do |name, ranges|
  ranges.each do |start, stop|
    if stop.nil?
      range = IPAddr.new(start).to_range
      start = range.first.to_s
      stop = range.last.to_s
    end

    conditions << "(PARSE_IP(contributor_ip) >= PARSE_IP(#{start.inspect}) AND PARSE_IP(contributor_ip) <= PARSE_IP(#{stop.inspect})) # #{name}"
  end
end

puts template % conditions.join("\n OR ")



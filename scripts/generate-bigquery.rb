#!/usr/bin/env ruby

require 'json'
require 'open-uri'
require 'ipaddr'

if ARGV.size != 1
  abort "USAGE: #{$PROGRAM_NAME} ranges.json"
end

template = <<SQL
SELECT
  id as article_id,
  title,
  CONCAT("http://en.wikipedia.org/w/index.php?diff=", STRING(revision_id)) AS diff_url,
  revision_id,
  SEC_TO_TIMESTAMP(timestamp) AS ts,
  timestamp,
  contributor_ip,
FROM publicdata:samples.wikipedia
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



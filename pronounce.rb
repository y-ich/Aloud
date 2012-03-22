require 'rubygems'
require 'nokogiri'
require 'open-uri'
require 'lingua/stemmer' #for stem
require 'json'

DIC_SERVICE = 'http://www.thefreedictionary.com/'
PRONOUNCE_SERVICE = 'http://img2.tfd.com/pp/wav.ashx/'

words = {}
passes = []
File.open('words.txt') do |f|
  until f.eof?
    line = f.gets
    line.split(/[^a-zA-Z0-9'+]/).each do |e|
      words[e.downcase] = {:alt => nil, :us => nil, :uk => nil} if e != ''
    end
  end
end

p words.length

words.each_pair  do |key, value|
  print "searching "
  p key
  begin
    content = Nokogiri::HTML open(DIC_SERVICE + key)
  rescue Exception => e
    print "Error"
    passes.push key
    next
  end

  if content.text =~ /Word not found/
    value[:alt] = Lingua.stemmer(key)
    p value[:alt]
    begin
      content = Nokogiri::HTML open(DIC_SERVICE + value[:alt])
    rescue Exception => e
      print "Error"
      passes.push key
      next
    end
    if content.text =~ /Word not found/
      print "not found: #{value[:alt]}"
      value[:alt] = nil
      next
    end
  end

  if content.css('#MainTitle h1').text =~ /\(redirected from/
    w = content.css('#MainTitle h1').children[0].text.strip
    begin
      content = Nokogiri::HTML open(DIC_SERVICE + w)
    rescue Exception => e
      print "Error"
      passes.push key
      next
    end      
  end

  value[:alt] = content.css('#MainTitle h1').children[0].text.strip
  p value[:alt]
  pronounces = []
  content.css('#MainTitle script').text.split(';').each do |e|
    e =~ (/playV2\(['"](.*)['"]\)/)
    p $1
    pronounces.push $1
  end

  unless pronounces.empty?
    p pronounces
    pronounces.each do |e|
      value[:us] = PRONOUNCE_SERVICE + e + '.wav' if e =~ /^en\/US/
      value[:uk] = PRONOUNCE_SERVICE + e + '.wav' if e =~ /^en\/UK/
    end
  end
end

File.open('urls.txt', "w") do |f|
  f.puts words.to_json
  f.puts passes
end

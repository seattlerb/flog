require 'bot_parser_format'

class BotParser
  @formats = []
  
  class << self
    attr_reader :formats
    
    def register_format(*args, &block)
      formats << BotParserFormat.new(*args, &block)
    end
    
    def clear_formats
      @formats = []
    end
  end
  
  def formats()  self.class.formats;  end
  
  register_format :image, /^\s*(?:(.*?)\s+)?(http:\S+\.(?:jpe?g|png|gif))(?:\s+(\S.*))?$/i,
  %q['http://www.citizenx.cx/img/best_picture_ever.jpg'],
  %q['http://www.citizenx.cx/img/best_picture_never.jpg this poster hangs over my bed'],
  %q['Best. Picture. Ever. http://www.citizenx.cx/img/best_picture_ever.jpg'] do |md, _|
    { :title => md[1], :source => md[2], :caption => md[3] }
  end
  
  register_format :video, %r{^\s*(?:(.*?)\s+)?(http://(?:www\.)?youtube\.com/\S+\?\S+)(?:\s+(.*))?$}i,
  %q['http://www.youtube.com/watch?v=E2Fjilze0eI'],
  %q['http://www.youtube.com/watch?v=E2Fjilze0eI the bunny gets it'],
  %q['A waste of chocolate http://www.youtube.com/watch?v=E2Fjilze0eI'] do |md, _|
    { :title => md[1], :embed => md[2], :caption => md[3] }
  end
  
  register_format :quote, /^\s*"([^"]+)"\s+--\s*(.*?)(?:\s+\((https?:.*)\))?$/i,
  %q['"adios, turd nuggets" --J.P.'],
  %q['"adios, turd nuggets" --J.P. (http://imdb.com/title/tt0456554/)'] do |md, _|
    { :quote => md[1], :source => md[2], :url => md[3] }
  end
  
  register_format :link, %r{^\s*(?:(.*?)\s+)?(https?://\S+)\s*(?:\s+(\S.*))?$}i,
  %q['http://news.yahoo.com/s/ap/20071203/ap_on_sc/dinosaur_mummy'],
  %q['http://news.yahoo.com/s/ap/20071203/ap_on_sc/dinosaur_mummy shows just how fast a mummified dinosaur can be'],
  %q['Fossilized Hadrosaur http://news.yahoo.com/s/ap/20071203/ap_on_sc/dinosaur_mummy'] do |md, _|
      { :name => md[1], :url => md[2], :description => md[3] }
  end
  
  register_format :fact, %r{^\s*fact:\s+(.*)}i,
  %q['FACT: Zed Shaw doesn't do pushups, he pushes the earth down'] do |md, _|
    { :title => "FACT: #{md[1]}" }
  end
  
  register_format :true_or_false, %r{^\s*(?:(?:true\s+or\s+false)|(?:t\s+or\s+f))\s*[:\?]\s+(.*)}i,
  %q['T or F: the human body has more than one sphincter'],
  %q['true or false: the human body has more than one sphincter'],
  %q['true or false? the human body has more than one sphincter'] do |md, _|
    { :title => "True or False?  #{md[1]}" }
  end
  
  register_format :definition, %r{^\s*defin(?:e|ition):?\s+(.*?)\s*(?:[:=]|as)\s*(.*)}i,
  %q['Definition: tardulism: the ideology of the tard culture'],
  %q['Definition: tardulism = the ideology of the tard culture'],
  %q["define tardulism as the ideology of the tard culture"] do |md, _|
    { :title => "DEFINITION: #{md[1]}: #{md[2]}" }
  end
  
  def parse(sender, channel, mesg)
    return nil if mesg.empty?
    
    common = { :poster => sender, :channel => channel }
    
    result = nil
    formats.detect { |f|  result = f.process(mesg) }
        
    return nil unless result
    
    result = common.merge(result)
    result
  end
end

class BotParserFormat
  attr_reader :name, :format, :block
  
  def initialize(name, format, *description, &block)
    raise ArgumentError, 'Block needed' if block.nil?
    
    @name   = name
    @format = format
    @block  = block
    @description = description
  end
  
  def description
    @description.empty? ? nil : @description.join("\n")
  end
  
  def process(text)
    md = format.match(text)
    return nil unless md
    
    block.call(md, text).merge(:type => name)
  end
end

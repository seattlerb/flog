class BotSender
  attr_reader :kind
  
  @@kinds = {  }
  
  def self.kinds
    @@kinds.keys.sort_by {|k| k.to_s }
  end
  
  def self.register(args = {})
    args.each_pair {|k,v| @@kinds[k] = v }
  end

  def self.new(args = {})
    raise ArgumentError unless self.kinds.include?(args[:destination])
    obj = @@kinds[args[:destination]].allocate
    obj.send :initialize, args  
    obj
  end

  def initialize(args = {})
    validate(args)
    @kind = args[:destination]
  end

  def deliver(message)
    return nil unless message and message[:type]
    meth = "do_#{message[:type]}".to_sym
    raise ArgumentError, "unknown message type [#{message[:type]}]" unless self.respond_to?(meth)
    begin
      self.send(meth, message)
    rescue Exception => e
      return e.to_s
    end
  end
  
  # validate arguments when creating a specific BotSender type instance
  def validate(args = {})
  end
end

require 'senders/tumblr'

class BotSender
  @@kinds[:tumblr] = BotSender::Tumblr
end

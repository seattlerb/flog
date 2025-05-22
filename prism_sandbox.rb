require "prism"
require "pp"

# Define a simple Ruby code string
code = "a = 1 + 2; def foo; puts 'hello'; end"

# Use PRISM to parse this string
result = Prism.parse(code)

# Print the resulting AST to the console
puts "AST:"
pp result.value

# Demonstrate how to access node types and source locations
puts "\nNode details:"
program_node = result.value
puts "Program node type: #{program_node.type}" # ProgramNode
puts "Program node location: #{program_node.location.inspect}"

statements_node = program_node.child_nodes.first
puts "Statements node type: #{statements_node.type}" # StatementsNode

# Assuming the first statement is 'a = 1 + 2' which is an AssignNode or similar
assign_node = statements_node.child_nodes.first
if assign_node
  puts "Assign node type: #{assign_node.type}" # LocalVariableWriteNode or CallNode depending on Prism version/AST structure
  puts "Assign node location: #{assign_node.location.inspect}"

  # Further inspect children of assign_node if necessary
  # For example, if it's a LocalVariableWriteNode, the name and value are children
  # If it's a CallNode for '=', the receiver, message, and arguments are children

  # Let's try to get to the '1 + 2' part, which should be a CallNode
  # This path might vary based on exact AST structure
  value_node = assign_node.child_nodes.find { |n| n && n.type == :call_node } # or other relevant child
  if value_node && value_node.type == :call_node
    puts "Value node (1+2) type: #{value_node.type}"
    puts "Value node (1+2) location: #{value_node.location.inspect}"

    integer_literal_node = value_node.child_nodes.find { |n| n && n.type == :integer_node }
    if integer_literal_node
      puts "Integer literal '1' node type: #{integer_literal_node.type}"
      puts "Integer literal '1' node location: #{integer_literal_node.location.inspect}"
    end
  elsif assign_node.child_nodes.size > 1 && assign_node.child_nodes[1]&.type == :call_node # Common for LocalVariableWriteNode
     call_node = assign_node.child_nodes[1]
     puts "Call node (1+2) type: #{call_node.type}"
     puts "Call node (1+2) location: #{call_node.location.inspect}"
     integer_literal_node = call_node.receiver # The '1' in '1+2'
     if integer_literal_node && integer_literal_node.type == :integer_node
        puts "Integer literal '1' node type: #{integer_literal_node.type}"
        puts "Integer literal '1' node location: #{integer_literal_node.location.inspect}"
     end
  end
end

# Demonstrate error handling
puts "\nError handling:"
error_code = "a = 1 + "
error_result = Prism.parse(error_code)

if error_result.success?
  puts "Parsed successfully (unexpected for error code)"
else
  puts "Parse errors:"
  error_result.errors.each do |error|
    puts "- #{error.message} at #{error.location.inspect}"
  end
end

puts "\nLexing tokens:"
lex_result = Prism.lex(code)
if lex_result.success?
  puts "Tokens:"
  lex_result.value.each_with_index do |token, i|
    pp token # Or token.inspect for more compact output
    break if i > 5 # Limit output for brevity
  end
else
  puts "Lexing errors."
end

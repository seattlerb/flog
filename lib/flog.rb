require "sexp_processor"
require "prism"
require "timeout"

##
# Flog calculates a complexity metric for Ruby code.
# Originally based on SexpProcessor, it's being refactored to use Prism.
#
# In essence, this calculates the most tortured code. The higher the
# score, the more pain the code is in and the harder it is to
# thoroughly test.

class Flog # < MethodBasedSexpProcessor # Refactor: Remove SexpProcessor inheritance
  VERSION = "4.8.0" # :nodoc:

  ##
  # Cut off point where the report should stop unless --all given.

  DEFAULT_THRESHOLD = 0.60

  THRESHOLD = DEFAULT_THRESHOLD # :nodoc:

  ##
  # The scoring system hash. Maps node type to score.

  SCORES = Hash.new 1

  ##
  # Names of nodes that branch.

  BRANCHING = [ :and, :case, :else, :if, :or, :rescue, :until, :when, :while ]

  ##
  # Various non-call constructs

  OTHER_SCORES = {
    :alias          => 2,
    :assignment     => 1,
    :block          => 1,
    :block_pass     => 1,
    :block_call     => 1,
    :branch         => 1,
    :magic_number   => 0.25,
    :sclass         => 5,
    :super          => 1,
    :to_proc_icky!  => 10,
    :to_proc_lasgn  => 15,
    :yield          => 1,
  }

  ##
  # Eval forms

  SCORES.merge!(:define_method => 5,
                :eval          => 5,
                :module_eval   => 5,
                :class_eval    => 5,
                :instance_eval => 5)

  ##
  # Various "magic" usually used for "clever code"

  SCORES.merge!(:alias_method               => 2,
                :extend                     => 2,
                :include                    => 2,
                :instance_method            => 2,
                :instance_methods           => 2,
                :method_added               => 2,
                :method_defined?            => 2,
                :method_removed             => 2,
                :method_undefined           => 2,
                :private_class_method       => 2,
                :private_instance_methods   => 2,
                :private_method_defined?    => 2,
                :protected_instance_methods => 2,
                :protected_method_defined?  => 2,
                :public_class_method        => 2,
                :public_instance_methods    => 2,
                :public_method_defined?     => 2,
                :remove_method              => 2,
                :send                       => 3,
                :undef_method               => 2)

  ##
  # Calls that are ALMOST ALWAYS ABUSED!

  SCORES.merge!(:inject => 2)

  # :stopdoc:
  attr_accessor :multiplier
  attr_reader :calls, :option, :mass
  attr_reader :method_scores, :scores
  attr_reader :total_score, :totals
  attr_writer :threshold

  # :startdoc:

  ##
  # Add a score to the tally. Score can be predetermined or looked up
  # automatically. Uses multiplier for additional spankings.
  # Spankings!

  def add_to_score name, score = OTHER_SCORES[name]
    # If :methods option is true, only score if we are inside a method.
    return if option[:methods] && @method_stack.empty?

    # Use the last method pushed to the stack for the signature,
    # or a default if not in a method (e.g. top-level script code).
    current_signature = @method_stack.last || build_signature("main")
    @calls[current_signature][name] += score * @multiplier
  end

  ##
  # really?

  def average
    return 0 if calls.size == 0
    total_score / calls.size
  end

  ##
  # Calculates classes and methods scores.

  def calculate
    each_by_score threshold do |class_method, score, call_list|
      klass = class_method.scan(/.+(?=#|::)/).first

      method_scores[klass] << [class_method, score]
      scores[klass] += score
    end
  end

  ##
  # Returns true if the form looks like a "DSL" construct.
  #
  #   task :blah do ... end
  #   => s(:iter, s(:call, nil, :task, s(:lit, :blah)), ...)

  def dsl_name? args
    return false unless args and not args.empty?

    first_arg, = args
    first_arg = first_arg[1] if first_arg.sexp_type == :hash

    type, value, * = first_arg

    value if [:lit, :str].include? type
  end

  ##
  # Iterate over the calls sorted (descending) by score.

  def each_by_score max = nil
    current = 0

    calls.sort_by { |k,v| -totals[k] }.each do |class_method, call_list|
      score = totals[class_method]

      yield class_method, score, call_list

      current += score
      break if max and current >= max
    end
  end

  ##
  # Flog the given files. Deals with "-", and syntax errors.
  #
  # Not as smart as FlogCLI's #flog method as it doesn't traverse
  # dirs. Use PathExpander to expand dirs into files.

  def flog(*files)
    files.each do |file|
      next unless file == "-" or File.readable? file

      ruby = file == "-" ? $stdin.read : File.binread(file)

      flog_ruby ruby, file
    end

    calculate_total_scores
  end

  ##
  # Flog the given ruby source, optionally using file to provide paths
  # for methods. Smart. Handles syntax errors and timeouts so you
  # don't have to.

  def flog_ruby ruby, file="-", timeout = 10
    begin
      Timeout.timeout timeout do
        flog_ruby! ruby, file
      end
    rescue Timeout::Error
      warn "TIMEOUT parsing #{file}. Skipping."
    # No specific Prism syntax errors caught here, handled by result object
    end
  end

  ##
  # Flog the given ruby source, optionally using file to provide paths for
  # methods. Does not handle timeouts or syntax errors. See #flog_ruby.

  def flog_ruby! ruby, file="-", timeout = 10 # Timeout param kept for compatibility but not used directly by Prism.parse
    @parser = Prism # Using Prism module directly

    warn "** flogging #{file}" if option[:verbose]

    parse_result = @parser.parse(ruby, filepath: file)
    ast = nil

    if parse_result.success?
      ast = parse_result.value
    else
      q = option[:quiet]
      warn "ERROR: parsing ruby file #{file}" unless q
      parse_result.errors.each do |error|
        # Guard against cases where location might be nil or not fully formed, though unlikely with Prism
        location_info = error.location ? "#{error.location.start_line}" : "unknown location"
        warn "Prism Error: #{error.message} at #{file}:#{location_info}" unless q
      end
      unless option[:continue] then
        warn "ERROR! Aborting. You may want to run with --continue."
        # Optionally, re-raise a generic error or a custom Flog parsing error
        # For now, just returning to stop processing this file.
        # raise "Prism parsing error in #{file}" # Example if re-raising is desired
      end
      return # Stop processing this file due to errors
    end

    return unless ast

    # mass[file] = ast.mass # Prism AST nodes do not have a direct .mass attribute.
    process ast
  end

  ##
  # Creates a new Flog instance with +options+.

  def initialize option = {}
    # super() # Refactor: Removed SexpProcessor super call
    @option              = option
    @mass                = {} # TODO: Re-evaluate mass calculation with Prism
    @parser              = nil # Will be set to Prism module
    @threshold           = option[:threshold] || DEFAULT_THRESHOLD
    # self.auto_shift_type = true # Refactor: SexpProcessor feature
    self.reset
  end

  ##
  # Returns the method/score pair of the maximum score.

  def max_method
    totals.max_by { |_, score| score }
  end

  ##
  # Returns the maximum score for a single method. Used for FlogTask.

  def max_score
    max_method.last
  end

  ##
  # For the duration of the block the complexity factor is increased
  # by #bonus This allows the complexity of sub-expressions to be
  # influenced by the expressions in which they are found.  Yields 42
  # to the supplied block.

  def penalize_by bonus
    @multiplier += bonus
    yield
    @multiplier -= bonus
  end

  ##
  # Reset score data

  def reset
    @totals                 = @total_score = nil
    @multiplier             = 1.0
    @calls                  = Hash.new { |h,k| h[k] = Hash.new 0 }
    @method_scores          = Hash.new { |h,k| h[k] = [] }
    @scores                 = Hash.new 0
    # method_locations.clear # Refactor: method_locations was part of MethodBasedSexpProcessor
    @method_locations       = {} # Re-initialize if we decide to keep it

    # New context tracking variables
    @method_stack           = [] # Stack to keep track of current method context (signatures)
    @current_class_name_parts = [] # Stack for class/module names
  end

  ##
  # Compute the distance formula for a given tally

  def score_method(tally)
    a, b, c = 0, 0, 0
    tally.each do |cat, score|
      case cat
      when :assignment then a += score
      when :branch, :block_call then b += score
      else                  c += score
      end
    end
    Math.sqrt(a*a + b*b + c*c)
  end

  ##
  # Final threshold that is used for report

  def threshold
    option[:all] ? nil : total_score * @threshold
  end

  ##
  # Calculates the total score and populates @totals.

  def calculate_total_scores
    return if @totals

    @total_score = 0
    @totals = Hash.new(0)

    calls.each do |meth, tally|
      score = score_method(tally)

      @totals[meth] = score
      @total_score += score
    end
  end

  def no_method # :nodoc:
    # @@no_method # Refactor: This was related to MethodBasedSexpProcessor
    # This method was used to return a default "no method" signature.
    # We can achieve this by calling build_signature with a placeholder if needed,
    # or ensure @method_stack.last is always sensible.
    build_signature("unknown_context_main") # Fallback signature
  end

  # TODO: Re-evaluate if method_locations is still needed and how to populate it.
  # It was part of MethodBasedSexpProcessor.
  def method_locations
    @method_locations ||= {}
  end

  # TODO: Re-evaluate if method_stack is still needed.
  # It was part of MethodBasedSexpProcessor.
  # REPLACED by @method_stack for signatures and @current_class_name_parts for class/module names
  # def method_stack
  #   @method_stack ||= []
  # end

  # TODO: Re-evaluate if signature is still needed.
  # It was part of MethodBasedSexpProcessor.
  # REPLACED by direct usage of @method_stack.last or build_signature
  # def signature
  #   method_stack.join_with_separator
  # end

  def build_signature(method_name, type = '#')
    class_part = @current_class_name_parts.empty? ? "Object" : @current_class_name_parts.join("::")
    "#{class_part}#{type}#{method_name}"
  end


  ############################################################
  # AST Traversal and Processing Methods (New)
  ############################################################

  def process(node, parent_node = nil) # Added parent_node
    return unless node # Nodes can be nil in Prism AST (e.g., optional parts of syntax)

    # Basic dispatch based on node type
    case node.type
    when :program_node
      process_program_node(node, parent_node)
    when :statements_node
      process_statements_node(node, parent_node)
    when :integer_node
      process_integer_node(node, parent_node)
    when :float_node
      process_float_node(node, parent_node)
    when :symbol_node
      process_symbol_node(node)
    when :regular_expression_node
      process_regular_expression_node(node)
    when :range_node
      process_range_node(node)
    when :call_node
      process_call_node(node, parent_node)
    when :if_node
      process_if_node(node, parent_node)
    when :local_variable_write_node
      process_local_variable_write_node(node, parent_node)
    when :def_node
      process_def_node(node, parent_node)
    when :class_node
      process_class_node(node, parent_node)
    when :module_node
      process_module_node(node, parent_node)
    when :singleton_class_node
      process_sclass_node(node, parent_node)
    when :while_node
      process_while_node(node, parent_node)
    when :until_node
      process_until_node(node, parent_node)
    when :case_node
      process_case_node(node, parent_node)
    when :when_node # Typically handled by process_case_node, but direct processing might be needed if used elsewhere
      process_when_node(node, parent_node)
    when :block_node
      process_block_node(node, parent_node)
    when :block_argument_node
      process_block_argument_node(node, parent_node)
    when :instance_variable_write_node
      process_instance_variable_write_node(node, parent_node)
    when :class_variable_write_node
      process_class_variable_write_node(node, parent_node)
    when :global_variable_write_node
      process_global_variable_write_node(node, parent_node)
    when :constant_write_node
      process_constant_write_node(node, parent_node)
    when :constant_path_write_node
      process_constant_path_write_node(node, parent_node)
    when :call_operator_write_node
      process_call_operator_write_node(node, parent_node)
    when :index_operator_write_node
      process_index_operator_write_node(node, parent_node)
    when :multi_write_node
      process_multi_write_node(node, parent_node)
    when :and_node
      process_and_node(node, parent_node)
    when :or_node
      process_or_node(node, parent_node)
    when :super_node
      process_super_node(node, parent_node)
    when :yield_node
      process_yield_node(node, parent_node)
    when :alias_method_node
      process_alias_method_node(node, parent_node)
    when :alias_global_variable_node
      process_alias_global_variable_node(node, parent_node)
    when :undef_node
      process_undef_node(node, parent_node)
    when :rescue_node
      process_rescue_node(node, parent_node)
    when :ensure_node
      process_ensure_node(node, parent_node)
    # Add more specific handlers here as they are developed
    else
      # Default: process child nodes if no specific handler
      # warn "No specific handler for #{node.type} (#{node.class}, parent: #{parent_node&.type}), processing children." # For debugging
      process_children(node, parent_node)
    end
  end

  def process_children(node, parent_node = nil) # Added parent_node
    node.child_nodes.each do |child_node|
      process(child_node, node) if child_node # Ensure child_node is not nil, pass current node as parent
    end
  end

  def process_program_node(node, parent_node = nil)
    process(node.statements, node)
  end

  def process_statements_node(node, parent_node = nil)
    node.body.each do |statement_node|
      process(statement_node, node)
    end
  end

  def process_integer_node(node, parent_node = nil)
    value = node.value
    case value
    when 0, -1
      # ignore: often used as array indices instead of first/last
    else
      # Check if this integer is the value part of a constant assignment
      is_const_assignment_value = false
      if parent_node
        if (parent_node.type == :constant_write_node || parent_node.type == :constant_path_write_node) &&
           parent_node.value == node
          is_const_assignment_value = true
        end
      end
      add_to_score :magic_number unless is_const_assignment_value
    end
  end

  def process_float_node(node, parent_node = nil)
    is_const_assignment_value = false
    if parent_node
      if (parent_node.type == :constant_write_node || parent_node.type == :constant_path_write_node) &&
         parent_node.value == node
        is_const_assignment_value = true
      end
    end
    add_to_score :magic_number unless is_const_assignment_value
  end

  def process_symbol_node(node, parent_node = nil)
    # Do nothing for symbols
  end

  def process_regular_expression_node(node, parent_node = nil)
    # Do nothing for regexps
  end

  def process_range_node(node, parent_node = nil)
    process(node.left, node)
    process(node.right, node)
  end

  def process_call_node(node, parent_node = nil)
    penalty = node.call_operator == :"&." ? 0.3 : 0.2
    penalize_by penalty do
      process(node.receiver, node)
    end
    method_name = node.name
    if node.arguments
      penalize_by 0.2 do
        process(node.arguments, node) # ArgumentsNode will call process on its children
      end
    end

    # --- DSL and Block Handling ---
    block_processed_in_dsl_context = false
    if node.block
      add_to_score :block_call # Score for the block being called/passed, regardless of DSL

      # Attempt to identify DSL-like structure for special context
      # Criteria: receiver is nil/self, and first arg is symbol/string
      dsl_sub_context_name = nil
      if (node.receiver.nil? || node.receiver.type == :self_node) &&
         node.arguments && node.arguments.arguments && !node.arguments.arguments.empty?
        
        first_arg_node = node.arguments.arguments.first
        if first_arg_node.type == :symbol_node
          dsl_sub_context_name = first_arg_node.value.to_s # SymbolNode's value is already a string/symbol
        elsif first_arg_node.type == :string_node
          dsl_sub_context_name = first_arg_node.content # StringNode's content or unescaped value
        end
      end

      if dsl_sub_context_name
        # DSL-like structure identified, create a special context for the block
        original_class_parts_top = @current_class_name_parts.pop if @current_class_name_parts.any?
        original_method_stack_top = @method_stack.pop if @method_stack.any?

        # The "class" for this DSL scope is the name of the method call itself (e.g., "task")
        dsl_pseudo_class_name = node.name.to_s
        @current_class_name_parts.push(dsl_pseudo_class_name)
        
        # The "method" for this DSL scope is the symbol/string argument (e.g., "my_task_name")
        dsl_method_signature = build_signature(dsl_sub_context_name) # type will default to '#'
        @method_stack.push(dsl_method_signature)

        process(node.block, node) # Process the block within this new context

        # Restore original context
        @method_stack.pop
        @current_class_name_parts.pop 
        @current_class_name_parts.push(original_class_parts_top) if original_class_parts_top
        @method_stack.push(original_method_stack_top) if original_method_stack_top
        
        block_processed_in_dsl_context = true
      end

      # If not processed in a DSL context, process the block normally
      unless block_processed_in_dsl_context
        process(node.block, node)
      end
    end
    # --- End DSL and Block Handling ---

    add_to_score method_name, SCORES[method_name]
  end

  def process_if_node(node, parent_node = nil)
    add_to_score :branch
    process(node.predicate, node)
    penalize_by 0.1 do
      process(node.statements, node)
      process(node.consequent, node) # ElseNode or another IfNode
    end
  end

  def process_local_variable_write_node(node, parent_node = nil)
    add_to_score :assignment
    process(node.value, node)
  end

  def process_def_node(node, parent_node = nil)
    method_name = node.name
    is_singleton = !node.receiver.nil? # True if it's like `def self.foo` or `def obj.foo`

    # Determine signature type based on whether it's a singleton method
    signature_type = is_singleton ? "::" : "#"
    
    # If it's a singleton on a specific object (not self in a class/module body),
    # we might want to represent that differently, but for now, this is a start.
    # E.g. `def my_obj.do_something`
    # If node.receiver is a LocalVariableReadNode, etc.
    if is_singleton && node.receiver.type != :self_node
        # This is a method defined on an object instance, e.g. `def var.meth`.
        # The old Flog didn't really have a good way to represent this distinctly from class methods.
        # For now, use "Object" as class part, or try to get name from receiver if simple const.
        # This part might need refinement based on how such methods should be scored/grouped.
        receiver_name = "Object" # Fallback
        if node.receiver.type == :constant_read_node || node.receiver.type == :constant_path_node
          # Attempt to get a name if it's a constant
          # This is a simplification; full constant path resolution is complex.
          receiver_name = node.receiver.full_name if node.receiver.respond_to?(:full_name)
          receiver_name ||= node.receiver.slice
        end
        current_sig = "#{receiver_name}::#{method_name}"
    else
        current_sig = build_signature(method_name, signature_type)
    end

    @method_stack.push(current_sig)
    # TODO: Populate @method_locations if needed:
    # @method_locations[current_sig] = [node.location.source_file, node.location.start_line, node.location.end_line]

    # The old SexpProcessor based one had `penalize_by` for the method body itself.
    # This is not explicitly done here, but individual constructs will be penalized.
    process(node.body, node)
    # process(node.parameters, node) # TODO: if parameters with complex defaults should be scored.

    @method_stack.pop
  end

  def get_path_name(node) # Unchanged, parent_node not needed here
    # Helper to extract name from ConstantReadNode, ConstantPathNode, etc.
    case node&.type # node might be nil (e.g. class without explicit namespace)
    when :constant_read_node, :module_name_node # ModuleNameNode might not exist, check Prism docs
      node.name.to_s
    when :constant_path_node
      # Recurse for nested paths like A::B::C - Prism specific
      # ConstantPathNode has `parent` and `child`
      # child is a ConstantReadNode or another ConstantPathNode.
      # parent is the left part.
      # Example: A::B, parent is A (ConstantReadNode), child is B (ConstantReadNode)
      # Example: A::B::C, parent is A::B (ConstantPathNode), child is C (ConstantReadNode)
      # We want the full string like "A::B::C"
      # Prism's ConstantPathNode has `slice` to get the source text.
      node.slice
    else
      "" # Or some default for anonymous/unresolved names
    end
  end

  def process_class_node(node, parent_node = nil)
    class_name_part = get_path_name(node.constant_path)
    @current_class_name_parts.push(class_name_part)

    # Penalize for superclass, if any
    if node.superclass
      penalize_by 1.0 do
        process(node.superclass, node)
      end
    end

    process(node.body, node)

    @current_class_name_parts.pop
  end

  def process_module_node(node, parent_node = nil)
    module_name_part = get_path_name(node.constant_path)
    @current_class_name_parts.push(module_name_part)
    process(node.body, node)
    @current_class_name_parts.pop
  end

  def process_sclass_node(node, parent_node = nil) # Singleton Class like `class << self`
    # The expression for sclass (e.g., `self` or a constant)
    # We need to determine what `self` refers to in this context if it's `class << self`
    # This is complex. For now, let's assume it's related to the current class context.
    # A simple approach for `class << self` is to consider methods defined as class methods
    # on the current class in @current_class_name_parts.
    
    # Original SexpProcessor `process_sclass` did:
    # super do ... penalize_by 0.5 { process recv; process body } ... add_to_score :sclass (5)
    # The `super` call in MethodBasedSexpProcessor would handle pushing/popping class context.
    # Here, we need to manage it manually.

    # For `class << some_object`, node.expression would be `some_object`.
    # If node.expression is :self_node, it refers to current class/module context.
    # If it's another node (e.g. ConstantReadNode), it's a singleton class of that constant.

    sclass_context_name = ""
    if node.expression.type == :self_node
      sclass_context_name = @current_class_name_parts.join("::") # Or some marker for self
    else
      sclass_context_name = get_path_name(node.expression)
    end
    
    # Push a representation of this singleton context.
    # The methods defined inside will use this for their signature's class part.
    # This is a simplification; the old Flog's `signature` for sclass methods was `ExistingClass::s_method`.
    # We might need a flag or adjust build_signature for methods defined in sclass.
    # For now, let's use the sclass_context_name as if it's a class name.
    @current_class_name_parts.push(sclass_context_name)

    add_to_score :sclass, OTHER_SCORES[:sclass] # Score for the sclass construct itself
    penalize_by 0.5 do # Penalty for the content of sclass
      process(node.expression, node) # process the receiver of sclass
      process(node.body, node)
    end

    @current_class_name_parts.pop
  end

  def process_while_node(node, parent_node = nil)
    add_to_score :branch
    penalize_by 0.1 do
      process(node.predicate, node)
      process(node.statements, node)
    end
  end

  def process_until_node(node, parent_node = nil)
    add_to_score :branch
    penalize_by 0.1 do
      process(node.predicate, node)
      process(node.statements, node)
    end
  end

  def process_case_node(node, parent_node = nil)
    add_to_score :branch # For the case statement itself
    process(node.predicate, node) if node.predicate # The value being switched on

    penalize_by 0.1 do # Penalty for the overall case structure
      node.conditions.each do |when_node| # Array of WhenNode
        process(when_node, node)
      end
      process(node.consequent, node) if node.consequent # ElseNode
    end
  end

  def process_when_node(node, parent_node = nil)
    # WhenNode fields: conditions (array), statements
    # The old Sexp-based process_when was an alias to process_else, which scored :branch and penalized.
    # The CaseNode already scores :branch for the whole construct and applies a penalty.
    # So, WhenNode itself might not need to add another :branch score,
    # but it should process its parts.
    # Let's stick to the original behavior of `process_when` alias if it implied scoring.
    add_to_score :branch # Each when clause is a branch
    # No separate penalty here, covered by CaseNode's penalty.
    node.conditions.each { |condition| process(condition, node) }
    process(node.statements, node)
  end

  def process_block_node(node, parent_node = nil)
    # BlockNode fields: parameters, body, (optionally locals, closing_loc, opening_loc)
    # Original Sexp process_block only penalized. Score for :block_call was from process_iter.
    # This process_block_node is for any generic block { } or do..end.
    # If this block is part of a CallNode (e.g. `foo { ... }`), the CallNode's process_call_node
    # will handle the :block_call score if we decide to add it there, or we check parent_node.
    # For now, just penalize the content.

    # Check if parent is a CallNode, if so, the :block_call score is usually associated with the call.
    # The old `process_iter` added `:block_call`. If this BlockNode is the `block` child of a CallNode,
    # then `process_call_node` should ideally handle the `:block_call` score.
    # Let's assume process_call_node will add :block_call when it processes node.block.
    # So, here we just penalize the contents.

    if parent_node && parent_node.type == :call_node && parent_node.block == node
        # This block is directly attached to a method call.
        # The original `process_iter` would score `:block_call`.
        # We can either do it here or ensure `process_call_node` does it.
        # Let's add it in `process_call_node` when `node.block` is present.
        # For now, add it here for consistency with old `process_iter` scoring.
        # add_to_score :block_call # This might double score if process_call_node also does it.
                                 # Let's assume process_call_node will handle it for now.
                                 # The old system was: iter -> block_call, then block -> penalty.
                                 # So if a CallNode has a BlockNode, process_call_node should score block_call.
                                 # Then process_block_node (here) should only penalize.
    end


    penalize_by 0.1 do
      process(node.parameters, node) if node.parameters # ParametersNode
      process(node.body, node)
    end
  end

  def process_block_argument_node(node, parent_node = nil)
    # Represents `&block_arg` in a method call or definition parameters
    # Original `process_block_pass` logic:
    #   add_to_score :block_pass
    #   complex scoring for :to_proc_icky!, :to_proc_lasgn based on expression type.
    #   process expression
    add_to_score :block_pass

    if node.expression
      # TODO: Attempt to replicate :to_proc_icky! / :to_proc_lasgn if possible.
      # This requires checking node.expression.type.
      # E.g., if node.expression is a LocalVariableWriteNode (:lasgn in Sexp) -> :to_proc_lasgn
      # E.g., if node.expression is a BlockNode (:iter in Sexp) -> :to_proc_icky!
      # For now, just process the expression.
      process(node.expression, node)
    end
  end

  ############################################################
  # Old SexpProcessor Process Methods (To be refactored or removed):
  # Commenting out for now to avoid conflicts and indicate they need rework.
  ############################################################

  # :stopdoc:
  # def process_alias(exp)
  #   process exp.shift
  #   process exp.shift
  #   add_to_score :alias
  #   s()
  # end

  def process_instance_variable_write_node(node, parent_node = nil)
    add_to_score :assignment
    process(node.value, node)
  end

  def process_class_variable_write_node(node, parent_node = nil)
    add_to_score :assignment
    process(node.value, node)
  end

  def process_global_variable_write_node(node, parent_node = nil)
    add_to_score :assignment
    process(node.value, node)
  end

  def process_constant_write_node(node, parent_node = nil)
    # Note: magic_number context already handles not scoring the value if it's a literal.
    # Here, we just score the act of assignment itself.
    add_to_score :assignment
    process(node.value, node)
  end

  def process_constant_path_write_node(node, parent_node = nil)
    # node.target is the ConstantPathNode, node.value is the value.
    add_to_score :assignment
    process(node.target, node) # Process the path itself (might be complex)
    process(node.value, node)
  end

  def process_call_operator_write_node(node, parent_node = nil)
    # e.g., a.b += c  (receiver a, name b, operator :+=, value c)
    # Prism: CallNode for `a.b`, then this node wraps it.
    # Or LocalVariableReadNode for `a` if `a += 1`.
    # This node has `receiver`, `operator`, `value`.
    # The "call" part (method being called for assignment) is implicit.
    # The old `process_attrasgn` handled `a.b = val`. This is more like `a.b += val`.
    # `a.b = val` would be a CallNode with name `b=`
    # This is for operators like `+=`, `||=`, `&&=`.
    add_to_score :assignment
    process(node.receiver, node) # The target of the assignment
    process(node.value, node)    # The value being assigned/operated with
  end

  def process_index_operator_write_node(node, parent_node = nil)
    # e.g., a[b] += c
    # receiver `a`, arguments `[b]`, operator `+=`, value `c`
    add_to_score :assignment
    process(node.receiver, node)
    process(node.arguments, node) if node.arguments
    process(node.value, node)
    # The block is also a possible child for `a[b]block += c`
    process(node.block, node) if node.block
  end

  def process_multi_write_node(node, parent_node = nil)
    # e.g., a, b = 1, 2  or  obj.a, obj.b = x, y
    # Has `lefts` (array of targets), `operator=` `value` (source)
    # Each target in `lefts` can be various write nodes (LocalVariableWriteNode, CallNode for attr=, etc.)
    add_to_score :assignment # Score once for the multi-assignment operation.
                             # Individual assignments within might also score if not careful,
                             # but Prism structures this as one operation.
                             # The old `process_masgn` scored once.
    node.lefts.each { |target_node| process(target_node, node) } # Process targets (might be simple vars or calls)
    process(node.value, node) # Process the right-hand side
  end

  def process_and_node(node, parent_node = nil)
    add_to_score :branch
    penalize_by 0.1 do
      process(node.left, node)
      process(node.right, node)
    end
  end

  def process_or_node(node, parent_node = nil)
    add_to_score :branch
    penalize_by 0.1 do
      process(node.left, node)
      process(node.right, node)
    end
  end

  def process_super_node(node, parent_node = nil)
    # SuperNode can have arguments and a block.
    add_to_score :super, OTHER_SCORES[:super]
    process(node.arguments, node) if node.arguments
    process(node.block, node) if node.block
  end

  def process_yield_node(node, parent_node = nil)
    # YieldNode can have arguments.
    add_to_score :yield, OTHER_SCORES[:yield]
    process(node.arguments, node) if node.arguments
  end

  def process_alias_method_node(node, parent_node = nil)
    # node.new_name and node.old_name are SymbolNode or similar.
    add_to_score :alias, OTHER_SCORES[:alias]
    process(node.new_name, node)
    process(node.old_name, node)
  end

  def process_alias_global_variable_node(node, parent_node = nil)
    # node.new_name and node.old_name are GlobalVariableReadNode or similar
    add_to_score :alias, OTHER_SCORES[:alias] # Same score as method alias
    process(node.new_name, node)
    process(node.old_name, node)
  end

  def process_undef_node(node, parent_node = nil)
    # node.names is an array of SymbolNode or similar representing methods to undef.
    # Each undef is scored.
    node.names.each do |name_node|
      add_to_score :undef_method, SCORES[:undef_method] # SCORES has :undef_method
      process(name_node, node) # Process the name node itself (though usually simple)
    end
  end

  def process_rescue_node(node, parent_node = nil)
    # RescueNode: exceptions (array of nodes), reference (LocalVariableWriteNode for `e`), statements (body), consequent (else rescue)
    # The old `process_rescue` was an alias for `process_else` which scored :branch and penalized.
    add_to_score :branch
    penalize_by 0.1 do
      node.exceptions.each { |exc_node| process(exc_node, node) } if node.exceptions
      process(node.reference, node) if node.reference # process the `e` in `rescue => e`
      process(node.statements, node) # process the body of the rescue
      process(node.consequent, node) if node.consequent # process further rescue/else clauses
    end
  end

  def process_ensure_node(node, parent_node = nil)
    # EnsureNode: statements (body)
    # The old SexpProcessor didn't have a direct `process_ensure`.
    # Ensure blocks don't typically add to branching complexity in the same way as if/else/rescue.
    # However, their contents should be processed and scored.
    # We can apply a small penalty for the structure itself, or just process contents.
    # Let's apply a small penalty similar to other blocks.
    penalize_by 0.1 do
      process(node.statements, node)
    end
  end


  # def process_and(exp) # Replaced by process_and_node
  #   add_to_score :branch
  #   penalize_by 0.1 do
  #     process exp.shift # lhs
  #     process exp.shift # rhs
  #   end
  #   s()
  # end
  # alias :process_or :process_and # Replaced by process_or_node

  # def process_attrasgn(exp) # Partially covered by various WriteNodes and CallNode for setters
  #   add_to_score :assignment
  #   process exp.shift # lhs
  #   exp.shift # name
  #   process_until_empty exp # rhs
  #   s()
  # end

  # def process_block(exp)
  #   penalize_by 0.1 do
  #     process_until_empty exp
  #   end
  #   s()
  # end

  # def process_block_pass(exp)
  #   arg = exp.shift
  #
  #   add_to_score :block_pass
  #
  #   return s() unless arg
  #
  #   case arg.sexp_type
  #   when :lvar, :dvar, :ivar, :cvar, :self, :const, :colon2, :nil then # f(&b)
  #     # do nothing
  #   when :lit then                                                     # f(&:b)
  #     # do nothing -- this now costs about the same as a block
  #   when :call then                                                    # f(&x.b)
  #     # do nothing -- I don't like the indirection, but that's already scored
  #   when :lasgn then                                                   # f(&l=b)
  #     add_to_score :to_proc_lasgn
  #   when :iter, :dsym, :dstr, :hash, *BRANCHING then                   # below
  #     # f(&proc { ... })
  #     # f(&"#{...}")
  #     # f(&:"#{...}")
  #     # f(&if ... then ... end") and all other branching forms
  #     # f(&{ a: 42 })  WHY?!?
  #     add_to_score :to_proc_icky!
  #   else
  #     raise({:block_pass_even_ickier! => arg}.inspect)
  #   end
  #
  #   process arg
  #
  #   s()
  # end

  # def process_call(exp) # Replaced by process_call_node
  #   penalize_by 0.2 do
  #     process exp.shift # recv
  #   end
  #
  #   name = exp.shift
  #
  #   penalize_by 0.2 do
  #     process_until_empty exp
  #   end
  #
  #   add_to_score name, SCORES[name]
  #
  #   s()
  # end

  # def process_safe_call(exp) # Combined into process_call_node
  #   penalize_by 0.3 do
  #     process exp.shift # recv
  #   end
  #
  #   name = exp.shift
  #
  #   penalize_by 0.2 do
  #     process_until_empty exp
  #   end
  #
  #   add_to_score name, SCORES[name]
  #
  #   s()
  # end

  # def process_case(exp)
  #   add_to_score :branch
  #   process exp.shift # recv
  #   penalize_by 0.1 do
  #     process_until_empty exp
  #   end
  #   s()
  # end

  # def process_class(exp) # Replaced by process_class_node
  #   super do # This super referred to MethodBasedSexpProcessor's process_class
  #     penalize_by 1.0 do
  #       process exp.shift # superclass expression
  #     end
  #     process_until_empty exp
  #   end
  # end

  # def process_dasgn_curr(exp) # Covered by specific VariableWriteNodes
  #   add_to_score :assignment
  #   exp.shift # name
  #   process exp.shift # assigment, if any
  #   s()
  # end
  # alias :process_iasgn :process_dasgn_curr # Covered by InstanceVariableWriteNode
  # alias :process_lasgn :process_dasgn_curr # Covered by LocalVariableWriteNode

  # def process_else(exp) # Handled by IfNode's `consequent` or CaseNode's `consequent`
  #   add_to_score :branch
  #   penalize_by 0.1 do
  #     process_until_empty exp
  #   end
  #   s()
  # end
  # alias :process_rescue :process_else # Replaced by process_rescue_node
  # alias :process_when   :process_else # Replaced by process_when_node (called from process_case_node)

  # def process_if(exp) # Replaced by process_if_node
  #   add_to_score :branch
  #   process exp.shift # cond
  #   penalize_by 0.1 do
  #     process exp.shift # true
  #     process exp.shift # false
  #   end
  #   s()
  # end

  # def process_iter(exp) # Needs careful refactoring for Prism's BlockNode, LambdaNode, etc.
  #   context = (self.context - [:class, :module, :scope]) # self.context was SexpProcessor
  #   context = context.uniq.sort_by { |s| s.to_s }
  #
  #   exp.delete 0 # { || ... } has 0 in arg slot - Sexp specific
  #
  #   if context == [:block, :iter] or context == [:iter] then
  #     recv, = exp
  #
  #     # DSL w/ names. eg task :name do ... end
  #     # Sexp specific structure matching below
  #     t, r, m, *a = recv
  #
  #     if t == :call and r == nil and submsg = dsl_name?(a) then
  #       m = "#{m}(#{submsg})" if m and [String, Symbol].include?(submsg.class)
  #       # in_klass and in_method were from MethodBasedSexpProcessor
  #       # in_klass m do
  #       #   in_method submsg, exp.file, exp.line, exp.line_max do
  #       #     process_until_empty exp
  #       #   end
  #       # end
  #       return # s()
  #     end
  #   end
  #
  #   add_to_score :block_call
  #
  #   process exp.shift # no penalty for LHS
  #
  #   penalize_by 0.1 do
  #     process_until_empty exp
  #   end
  #
  #   # s()
  # end

  Rational = Integer unless defined? Rational # 1.8 / 1.9 # Keep this for now.

  # def process_lit(exp) # Replaced by process_integer_node, process_float_node etc.
  #   value = exp.shift
  #   case value
  #   when 0, -1 then
  #     # ignore those because they're used as array indicies instead of
  #     # first/last
  #   when Integer, Float, Rational, Complex then
  #     add_to_score :magic_number # unless context[1] == :cdecl # Context issue
  #   when Symbol, Regexp, Range then
  #     # do nothing
  #   else
  #     raise "Unhandled lit: #{value.inspect}:#{value.class}"
  #   end
  #   # s()
  # end

  # def process_masgn(exp) # Replaced by process_multi_write_node
  #   add_to_score :assignment
  #
  #   exp.map! { |s| Sexp === s ? s : s(:lasgn, s) } # Sexp specific
  #
  #   process_until_empty exp
  #   # s()
  # end

  # def process_sclass(exp) # Replaced by process_sclass_node
  #   super do # This super referred to MethodBasedSexpProcessor
  #     penalize_by 0.5 do
  #       process exp.shift # recv
  #       process_until_empty exp
  #     end
  #   end
  #
  #   add_to_score :sclass
  #   # s()
  # end

  # def process_super(exp) # SuperNode in Prism
  #   add_to_score :super
  #   process_until_empty exp
  #   # s()
  # end

  # def process_while(exp) # WhileNode in Prism
  #   add_to_score :branch
  #   penalize_by 0.1 do
  #     process exp.shift # cond
  #     process exp.shift # body
  #   end
  #   exp.shift # pre/post
  #   # s()
  # end
  # alias :process_until :process_while # UntilNode in Prism

  # def process_yield(exp) # YieldNode in Prism
  #   add_to_score :yield
  #   process_until_empty exp
  #   # s()
  # end
  # :startdoc:
end

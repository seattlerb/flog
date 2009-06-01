require 'test/test_helper'
require 'flog'
require 'sexp_processor'

# describe "Flog Command Line" do
#   before :each do
#     @flog = Flog.new({})
#   end
# 
#   describe 'flog_files' do
# 
#     describe 'when given empty input' do
#       before :each do
#         @files = ['/empty/empty.rb']
#       end
# 
# #       it 'should not fail when flogging the given input' do
# #         lambda { @flog.flog_files(fixture_files(@files)) }.wont_raise_error
# #       end
# 
# #       it 'should report an overall flog score of 0' do
# #         @flog.flog_files(fixture_files(@files))
# #         @flog.total.must_be_close_to 0.0
# #       end
#     end
# 
#     describe 'when given a simple file' do
#       before :each do
#         @files = ['/simple/simple.rb']
#         @calls = YAML.load(<<-YAML)
#         ---
#         RailsClassMethods#generate:
#           :save: 1.4
#           :assignment: 2.80000000000001
#           :spawn: 1.4
#         RailsClassMethods#exemplar_path:
#           :join: 1.4
#         ClassMethods#generator_for:
#           :is_a?: 2.8
#           :arity: 2.0
#           :assignment: 16.5
#           :respond_to?: 1.7
#           :first: 1.6
#           :branch: 19.0
#           :name: 2.0
#           :lit_fixnum: 0.45
#           :length: 1.8
#           :raise: 8.60000000000001
#           :include?: 1.8
#           :lambda: 1.8
#           :to_sym: 3.1
#           :[]: 16.1
#           :==: 1.6
#           :keys: 3.8
#           :record_generator_for: 5.00000000000001
#         ObjectDaddy#included:
#           :extend: 5.6
#           :branch: 2.6
#           :sclass: 7.5
#           :alias_method: 8.4
#           :<: 1.4
#         ClassMethods#underscore:
#           :gsub: 1.6
#           :downcase: 1.4
#         ClassMethods#gather_exemplars:
#           :load: 1.5
#           :underscore: 1.6
#           :assignment: 4.40000000000001
#           :respond_to?: 1.4
#           :superclass: 5.50000000000001
#           :branch: 6.00000000000001
#           :name: 1.8
#           :gather_exemplars: 1.6
#           :exemplars_generated: 1.4
#           :exists?: 1.4
#           :join: 1.4
#           :dup: 1.6
#           :exemplar_path: 1.6
#           :generators: 1.9
#         ClassMethods#none:
#           :protected: 2.6
#           :attr_accessor: 1.3
#           :attr_reader: 1.3
#         Foo#initialize:
#           :super: 1.2
#         main#none:
#           :assignment: 1.1
#           :attr_writer: 1.1
#           :branch: 5.60000000000001
#           :lit_fixnum: 0.275000000000001
#           :puts: 1.1
#           :alias: 2.20000000000001
#         ClassMethods#record_generator_for:
#           :assignment: 1.4
#           :branch: 3.20000000000001
#           :raise: 1.5
#           :==: 1.4
#           :[]: 3.50000000000001
#           :generators: 3.50000000000001
#         RailsClassMethods#validates_presence_of_with_object_daddy:
#           :is_a?: 1.4
#           :assignment: 5.80000000000001
#           :branch: 2.80000000000001
#           :last: 1.6
#           :dup: 1.4
#           :pop: 1.5
#           :each: 1.4
#           :validates_presence_of_without_object_daddy: 1.4
#         ClassMethods#presence_validated_attributes:
#           :merge: 1.5
#           :presence_validated_attributes: 1.7
#           :assignment: 4.30000000000001
#           :respond_to?: 1.4
#           :superclass: 3.50000000000001
#           :branch: 1.4
#         ClassMethods#spawn:
#           :presence_validated_attributes: 5.4
#           :each_pair: 1.4
#           :assignment: 35.3
#           :generate: 1.7
#           :class_name: 2.1
#           :call: 1.8
#           :reflect_on_all_associations: 1.8
#           :branch: 24.0
#           :constantize: 1.9
#           :name: 3.9
#           :gather_exemplars: 1.4
#           :select: 1.6
#           :-: 1.8
#           :send: 5.4
#           :to_a: 1.6
#           :empty?: 1.5
#           :new: 1.4
#           :reject!: 1.7
#           :next: 1.9
#           :delete: 1.9
#           :include?: 1.8
#           :primary_key_name: 4.2
#           :to_s: 5.7
#           :each: 3.2
#           :keys: 4.0
#           :[]: 23.6
#           :generators: 1.7
#           :scope: 1.6
#         RailsClassMethods#generate!:
#           :save!: 1.4
#           :assignment: 2.80000000000001
#           :spawn: 1.4
#         YAML
# 
#         @totals = YAML.load(<<-YAML)
#         ---
#         RailsClassMethods#generate: 3.95979797464467
#         ObjectDaddy#included: 23.0471256342304
#         ClassMethods#generator_for: 59.7115776043475
#         RailsClassMethods#exemplar_path: 1.4
#         ClassMethods#underscore: 3.00000000000001
#         ClassMethods#none: 5.2
#         ClassMethods#gather_exemplars: 23.8882816460289
#         ClassMethods#record_generator_for: 10.4980950652964
#         main#none: 7.37737249974544
#         Foo#initialize: 1.2
#         ClassMethods#spawn: 96.0108847995893
#         ClassMethods#presence_validated_attributes: 9.27685291464731
#         RailsClassMethods#validates_presence_of_with_object_daddy: 10.8245092267502
#         RailsClassMethods#generate!: 3.95979797464467
#         YAML
#       end
# 
#       it 'should not fail when flogging the given input' do
#         lambda { @flog.flog_files(fixture_files(@files)) }.wont_raise_error
#       end
# 
#       currently 'should report an overall flog score of 259.354295339925' do
#         @flog.flog_files(fixture_files(@files))
#         @flog.total.must_be_close_to 259.354295339925
#       end
# 
#       currently 'should compute the same call data as flog-1.1.0' do
#         @flog.flog_files(fixture_files(@files))
#         @flog.calls.each_pair do |k,v|
#           v.each_pair do |x, y|
#             @calls[k][x].must_be_close_to y
#           end
#         end
#       end
# 
#       currently 'should compute the same totals data as flog-1.1.0' do
#         @flog.flog_files(fixture_files(@files))
#         @flog.totals.each_pair do |k,v|
#           v.must_be_close_to @totals[k]
#         end
#       end
#     end
# 
#     # FIX: this is totally unmaintainable
# #     describe 'when given a directory of files' do
# #       before :each do
# #         @files = ['/directory/']
# #         @calls = YAML.load(<<-YAML)
# #         ---
# #         BotSender#validate:
# #           :assignment: 1.3
# #         BotParserFormat#description:
# #           :join: 1.3
# #           :branch: 1.2
# #           :empty?: 1.2
# #         BotParserFormat#initialize:
# #           :assignment: 4.8
# #           :branch: 1.2
# #           :raise: 1.3
# #           :nil?: 1.2
# #         BotParser#parse:
# #           :merge: 1.3
# #           :detect: 1.3
# #           :assignment: 6.7
# #           :branch: 3.9
# #           :empty?: 1.3
# #           :process: 1.4
# #           :formats: 1.5
# #         register_format#video:
# #           :register_format: 1.2
# #           :assignment: 3.6
# #           :lit_fixnum: 1.05
# #           :[]: 3.6
# #         register_format#image:
# #           :register_format: 1.2
# #           :assignment: 3.6
# #           :lit_fixnum: 1.05
# #           :[]: 3.6
# #         BotFilter#process:
# #           :class: 1.6
# #           :options: 1.8
# #           :kinds: 1.4
# #           :assignment: 5.4
# #           :branch: 2.5
# #           :get: 1.8
# #           :process: 1.4
# #           :new: 1.6
# #           :each: 1.2
# #         BotFilter#register:
# #           :<<: 1.8
# #         BotSender#deliver:
# #           :respond_to?: 1.3
# #           :assignment: 2.7
# #           :send: 4.2
# #           :branch: 5.2
# #           :raise: 1.4
# #           :to_s: 1.5
# #           :to_sym: 1.3
# #           :[]: 4.5
# #         register_format#true_or_false:
# #           :register_format: 1.2
# #           :assignment: 3.6
# #           :lit_fixnum: 0.35
# #           :[]: 1.2
# #         BotSender#none:
# #           :assignment: 1.1
# #           :attr_reader: 1.2
# #         BotParser#clear_formats:
# #           :assignment: 1.9
# #         BotSender#register:
# #           :each_pair: 1.3
# #           :assignment: 6.90000000000001
# #           :branch: 1.3
# #         register_format#definition:
# #           :register_format: 1.2
# #           :assignment: 3.6
# #           :lit_fixnum: 0.7
# #           :[]: 2.4
# #         register_format#link:
# #           :register_format: 1.2
# #           :assignment: 3.6
# #           :lit_fixnum: 1.05
# #           :[]: 3.6
# #         BotParser#none:
# #           :assignment: 1.2
# #           :sclass: 6.0
# #           :attr_reader: 1.8
# #         BotParser#register_format:
# #           :<<: 1.9
# #           :new: 2.1
# #           :formats: 2.1
# #           :block_pass: 2.1
# #         BotSender#initialize:
# #           :validate: 1.3
# #           :assignment: 2.6
# #           :[]: 1.3
# #         register_format#quote:
# #           :register_format: 1.2
# #           :assignment: 3.6
# #           :lit_fixnum: 1.05
# #           :[]: 3.6
# #         BotFilter#register_filter:
# #           :register: 1.8
# #           :load: 1.8
# #           :filter_path: 1.8
# #           :assignment: 1.8
# #           :exists?: 1.8
# #           :branch: 1.8
# #           :raise: 1.9
# #         BotSender#kinds:
# #           :assignment: 1.4
# #           :sort_by: 1.3
# #           :branch: 1.3
# #           :to_s: 1.4
# #           :keys: 1.5
# #         main#none:
# #           :require: 2.2
# #         BotFilter#new:
# #           :locate_filters: 1.9
# #           :assignment: 3.6
# #           :send: 5.4
# #           :branch: 1.8
# #           :allocate: 1.8
# #         BotSender#new:
# #           :kinds: 1.5
# #           :assignment: 2.6
# #           :send: 3.9
# #           :branch: 1.3
# #           :allocate: 1.3
# #           :raise: 1.4
# #           :include?: 1.3
# #           :[]: 4.7
# #         BotFilter#locate_filters:
# #           :register_filter: 2.0
# #           :assignment: 2.0
# #           :branch: 5.5
# #           :each: 1.9
# #           :[]: 4.0
# #         BotFilter#get:
# #           :gsub: 2.0
# #           :upcase: 2.1
# #           :assignment: 1.8
# #           :const_get: 1.8
# #           :branch: 2.0
# #           :to_sym: 1.8
# #           :to_s: 2.2
# #         BotParserFormat#none:
# #           :attr_reader: 1.1
# #         BotFilter#filter_path:
# #           :+: 2.0
# #           :dirname: 2.2
# #           :expand_path: 1.8
# #         BotParserFormat#process:
# #           :merge: 1.2
# #           :call: 1.4
# #           :match: 1.2
# #           :format: 1.4
# #           :name: 1.4
# #           :assignment: 1.2
# #           :branch: 1.2
# #           :block: 1.6
# #         BotParser#formats:
# #           :class: 1.5
# #           :formats: 1.3
# #         BotFilter#initialize:
# #           :assignment: 2.4
# #         register_format#fact:
# #           :register_format: 1.2
# #           :assignment: 3.6
# #           :lit_fixnum: 0.35
# #           :[]: 1.2
# #         BotFilter#none:
# #           :sclass: 5.5
# #           :attr_reader: 1.1
# #         YAML
# 
# #         @totals = YAML.load(<<-YAML)
# #         ---
# #         BotFilter#register: 1.8
# #         BotFilter#process: 12.3308556069723
# #         register_format#image: 6.86895188511319
# #         register_format#video: 6.86895188511319
# #         BotParser#parse: 10.3121287811974
# #         BotParserFormat#initialize: 5.54346462061408
# #         BotParserFormat#description: 2.77308492477241
# #         BotSender#validate: 1.3
# #         register_format#true_or_false: 4.53017659699929
# #         BotSender#deliver: 15.3613150478727
# #         BotParser#clear_formats: 1.9
# #         BotSender#none: 1.62788205960997
# #         BotParser#none: 7.89176786277955
# #         register_format#link: 6.86895188511319
# #         register_format#definition: 5.60802995712398
# #         BotSender#register: 7.14072825417689
# #         BotParser#register_format: 8.2
# #         BotFilter#register_filter: 9.44933860119321
# #         register_format#quote: 6.86895188511319
# #         BotSender#initialize: 3.67695526217005
# #         BotFilter#new: 9.9503768772846
# #         main#none: 2.2
# #         BotSender#kinds: 4.61410879802373
# #         BotFilter#get: 10.2591422643416
# #         BotFilter#locate_filters: 9.83158176490437
# #         BotSender#new: 14.3965273590543
# #         BotFilter#filter_path: 6.0
# #         BotParserFormat#none: 1.1
# #         BotFilter#initialize: 2.4
# #         BotParser#formats: 2.8
# #         BotParserFormat#process: 8.37376856618333
# #         BotFilter#none: 6.6
# #         register_format#fact: 4.53017659699929
# #         YAML
# #       end
# 
# #       it 'should not fail when flogging the given input' do
# #         lambda { @flog.flog_files(fixture_files(@files)) }.should_not raise_error
# #       end
# 
# #       currently 'should report an overall flog score of 209.977217342726' do
# #         @flog.flog_files(fixture_files(@files))
# #         @flog.total.must_be_close_to 209.977217342726
# #       end
# 
# #       currently 'should compute the same call data as flog-1.1.0' do
# #         @flog.flog_files(fixture_files(@files))
# #         @flog.calls.each_pair do |k,v|
# #           v.each_pair do |x, y|
# #             @calls[k][x].must_be_close_to y
# #           end
# #         end
# #       end
# 
# #       currently 'should compute the same totals data as flog-1.1.0' do
# #         @flog.flog_files(fixture_files(@files))
# #         @flog.totals.each_pair {|k,v| v.must_be_close_to @totals[k]
# #       end
# #     end
# 
#     # FIX: this is totally unmaintainable
# #     describe 'when given a collection of files' do
# #       before :each do
# #         @files = ['/collection/']
# #         @calls = YAML.load(<<-YAML)
# #         ---
# #         InstanceMethods#initialize_with_has_many_range_extension:
# #           :returning: 1.3
# #           :initialize_without_has_many_range_extension: 1.5
# #           :macro: 1.90000000000001
# #           :add_has_many_range_extension: 1.70000000000001
# #           :branch: 2.80000000000001
# #           :puts: 6.00000000000002
# #           :==: 1.50000000000001
# #           :to_s: 1.70000000000001
# #         ClassMethods#calculate_with_range_restrictions:
# #           :with_current_time_scope: 1.5
# #           :calculate_without_range_restrictions: 3.10000000000001
# #           :branch: 2.90000000000001
# #           :[]: 1.4
# #           :acts_as_range_configuration: 1.6
# #         InstanceMethods#contained_by?:
# #           :to_range: 3.70000000000001
# #           :exclude_end?: 3.60000000000001
# #           :respond_to?: 1.3
# #           :last: 1.8
# #           :contained_by?: 1.5
# #           :branch: 18.5
# #           :>=: 1.9
# #           :acts_as_range_begin: 12.5
# #           :==: 3.20000000000001
# #           :include?: 2.90000000000001
# #           :acts_as_range_end: 14.4
# #           :<=: 1.9
# #         ClassMethods#sequentialized?:
# #           :branch: 1.3
# #           :sequentialized_on: 1.3
# #         InstanceMethods#expired?:
# #           :assignment: 1.3
# #           :branch: 1.3
# #           :now: 1.3
# #           :acts_as_range_end: 2.8
# #           :<=: 1.3
# #         ClassMethods#with_overlapping_scope:
# #           :|: 3.00000000000001
# #           :with_containing_scope: 4.00000000000001
# #           :with_contained_scope: 1.8
# #           :flatten: 5.20000000000001
# #           :block_pass: 5.80000000000001
# #         ClassMethods#with_containing_scope:
# #           :acts_as_range_begin_attr: 5.30000000000001
# #           :with_scope: 1.4
# #           :<<: 11.0
# #           :assignment: 4.20000000000001
# #           :join: 1.8
# #           :table_name: 10.6
# #           :branch: 2.80000000000001
# #           :acts_as_range_end_attr: 5.30000000000001
# #           :block_pass: 1.4
# #           :flatten: 1.4
# #           :nil?: 2.80000000000001
# #         ClassMethods#with_after_scope:
# #           :acts_as_range_begin_attr: 3.20000000000001
# #           :with_scope: 1.4
# #           :table_name: 3.20000000000001
# #           :block_pass: 1.4
# #         InstanceMethods#overlapping?:
# #           :is_a?: 1.4
# #           :first: 1.8
# #           :respond_to?: 1.3
# #           :last: 1.8
# #           :assignment: 3.20000000000001
# #           :contained_by?: 1.4
# #           :containing?: 7.80000000000002
# #           :branch: 11.3
# #           :acts_as_range_begin: 3.30000000000001
# #           :acts_as_range_end: 3.30000000000001
# #         ClassMethods#acts_as_date_range_sequentialize_class:
# #           :acts_as_date_range_param_sequentialize_class: 1.4
# #           :acts_as_date_range_singleton_sequentialize_class: 1.4
# #           :branch: 1.3
# #           :flatten!: 1.3
# #           :==: 1.3
# #         ClassMethods#acts_as_date_range_param_sequentialize_class:
# #           :validate_on_create: 1.3
# #           :add: 1.6
# #           :count: 1.7
# #           :>: 1.5
# #           :acts_as_range_begin_attr: 3.9
# #           :class: 3.8
# #           :extend: 2.6
# #           :errors: 1.8
# #           :assignment: 5.80000000000001
# #           :before_validation_on_create: 1.3
# #           :branch: 6.90000000000001
# #           :before_create: 1.3
# #           :now: 1.5
# #           :acts_as_range_begin: 6.00000000000001
# #           :to_sql: 4.2
# #           :acts_as_range_end_attr: 4.2
# #           :each: 1.5
# #           :expire: 1.6
# #           :find: 1.7
# #           :flatten: 3.8
# #           :to_attributes_for: 4.2
# #         InstanceMethods#destroy_without_callbacks:
# #           :class: 3.8
# #           :default_timezone: 1.8
# #           :freeze: 1.3
# #           :new_record?: 1.3
# #           :update_all: 1.6
# #           :assignment: 1.6
# #           :send: 5.4
# #           :branch: 4.3
# #           :now: 3.6
# #           :acts_as_range_end_attr: 2.0
# #           :id: 2.0
# #           :utc: 1.7
# #           :==: 1.6
# #           :[]: 1.4
# #           :acts_as_range_configuration: 1.6
# #           :quote_value: 1.8
# #         ClassMethods#with_contained_scope:
# #           :acts_as_range_begin_attr: 7.60000000000002
# #           :with_scope: 1.4
# #           :<<: 16.8
# #           :assignment: 4.20000000000001
# #           :join: 1.8
# #           :table_name: 15.2
# #           :branch: 4.40000000000001
# #           :acts_as_range_end_attr: 7.60000000000002
# #           :block_pass: 1.4
# #           :flatten: 1.4
# #           :nil?: 4.40000000000001
# #         ClassMethods#count_with_range_restrictions:
# #           :count_without_range_restrictions: 3.10000000000001
# #           :with_current_time_scope: 1.5
# #           :branch: 2.90000000000001
# #           :[]: 1.4
# #           :acts_as_range_configuration: 1.6
# #         InstanceMethods#to_range:
# #           :assignment: 2.60000000000001
# #           :acts_as_range_begin: 1.3
# #           :acts_as_range_end: 1.3
# #         ParamExtension#to_attributes_for:
# #           :attributes: 1.7
# #           :assignment: 1.5
# #           :branch: 1.4
# #           :[]: 1.5
# #           :to_s: 1.7
# #           :collect: 1.4
# #         ClassMethods#with_current_time_scope:
# #           :first: 3.3
# #           :respond_to?: 2.7
# #           :call: 2.7
# #           :with_overlapping_scope: 2.9
# #           :end_dated_association_date: 3.1
# #           :last: 3.3
# #           :assignment: 2.7
# #           :with_containing_scope: 2.9
# #           :branch: 2.7
# #           :block_pass: 5.80000000000001
# #         InstanceMethods#included:
# #           :extend: 5.20000000000001
# #         DateRanged#current:
# #           :containing: 1.1
# #           :now: 1.3
# #         ClassMethods#with_before_scope:
# #           :with_scope: 1.4
# #           :table_name: 3.20000000000001
# #           :acts_as_range_end_attr: 3.20000000000001
# #           :block_pass: 1.4
# #         ClassMethods#remove_args:
# #           :first: 1.5
# #           :>: 1.4
# #           :last: 2.0
# #           :<<: 1.4
# #           :extract_options_from_args!: 1.4
# #           :assignment: 2.90000000000001
# #           :branch: 2.80000000000001
# #           :length: 1.6
# #           :delete: 1.5
# #           :keys: 1.8
# #           :each: 1.4
# #         ClassMethods#add_args:
# #           :merge: 1.6
# #           :<<: 1.4
# #           :extract_options_from_args!: 1.8
# #         InstanceMethods#before?:
# #           :respond_to?: 1.3
# #           :branch: 3.90000000000001
# #           :<: 1.3
# #           :before?: 1.4
# #           :acts_as_range_begin: 1.6
# #           :acts_as_range_end: 2.80000000000001
# #         InstanceMethods#containing?:
# #           :to_range: 8.50000000000001
# #           :is_a?: 1.4
# #           :exclude_end?: 6.30000000000001
# #           :>: 2.0
# #           :first: 4.00000000000001
# #           :respond_to?: 1.3
# #           :assignment: 3.20000000000001
# #           :last: 10.7
# #           :contained_by?: 1.4
# #           :branch: 28.0
# #           :acts_as_range_begin: 8.90000000000002
# #           :==: 5.90000000000001
# #           :include?: 5.20000000000001
# #           :acts_as_range_end: 13.1
# #           :<=: 3.70000000000001
# #         ClassMethods#acts_as_date_range:
# #           :acts_as_range: 1.3
# #           :is_a?: 1.3
# #           :assignment: 1.3
# #           :acts_as_date_range?: 1.3
# #           :acts_as_date_range_configure_class: 1.3
# #           :branch: 2.6
# #           :update: 1.5
# #           :raise: 1.4
# #         InstanceMethods#limit_date_range:
# #           :end_dated_association_date: 1.4
# #           :assignment: 6.9
# #           :branch: 1.4
# #           :yield: 1.4
# #           :new: 1.4
# #           :acts_as_range_begin: 1.4
# #           :acts_as_range_end: 1.4
# #         InstanceMethods#lifetime:
# #           :>: 1.4
# #           :assignment: 1.3
# #           :branch: 5.4
# #           :now: 1.3
# #           :acts_as_range_begin: 4.6
# #           :acts_as_range_end: 3.2
# #           :distance_of_time_in_words: 1.3
# #           :nil?: 2.7
# #         ClassMethods#validates_interval:
# #           :validation_method: 1.6
# #           :add: 1.80000000000001
# #           :errors: 2.00000000000001
# #           :evaluate_condition: 1.6
# #           :assignment: 9.30000000000003
# #           :send: 4.20000000000001
# #           :branch: 10.9
# #           :acts_as_range_begin: 1.70000000000001
# #           :acts_as_range_end: 1.70000000000001
# #           :each: 1.3
# #           :humanize: 2.60000000000001
# #           :to_s: 3.00000000000001
# #           :[]: 12.3
# #           :acts_as_range_configuration: 6.00000000000001
# #           :<=: 1.90000000000001
# #           :nil?: 3.70000000000001
# #         ClassMethods#acts_as_range:
# #           :is_a?: 1.3
# #           :class_inheritable_reader: 1.3
# #           :assignment: 1.3
# #           :acts_as_range_configure_class: 1.3
# #           :branch: 2.60000000000001
# #           :update: 1.5
# #           :raise: 1.4
# #           :acts_as_range?: 1.3
# #         ParamExtension#to_sql:
# #           :assignment: 1.7
# #           :join: 1.4
# #           :branch: 1.6
# #           :collect: 1.6
# #         ClassMethods#none:
# #           :protected: 3.70000000000001
# #           :assignment: 1.4
# #           :branch: 2.70000000000001
# #           :[]: 1.5
# #           :to_sym: 1.7
# #           :acts_as_range_configuration: 1.7
# #           :define_method: 7.00000000000002
# #           :each: 1.3
# #         DateRange#included:
# #           :respond_to?: 1.2
# #           :extend: 2.4
# #           :assignment: 1.4
# #           :branch: 2.6
# #           :now: 1.5
# #           :new: 1.4
# #           :attr: 1.9
# #           :sclass: 7.0
# #         DateRange#none:
# #           :include: 2.2
# #         InstanceMethods#add_has_many_range_extension:
# #           :options: 1.50000000000001
# #           :assignment: 6.00000000000002
# #           :push: 1.60000000000001
# #           :branch: 2.80000000000001
# #           :puts: 5.40000000000002
# #           :acts_as_range?: 1.3
# #           :include?: 1.50000000000001
# #           :[]: 5.20000000000002
# #           :klass: 3.00000000000001
# #           :flatten: 1.50000000000001
# #         Ranged#included:
# #           :alias_method_chain: 1.3
# #           :branch: 1.2
# #           :send: 3.60000000000001
# #           :puts: 1.2
# #           :instance_eval: 6.00000000000002
# #         Range#included:
# #           :respond_to?: 1.2
# #           :extend: 2.4
# #           :assignment: 1.4
# #           :branch: 2.6
# #           :now: 1.5
# #           :new: 1.4
# #           :attr: 1.9
# #           :sclass: 7.00000000000001
# #         InstanceMethods#include?:
# #           :class: 3.2
# #           :branch: 5.40000000000001
# #           :id: 3.2
# #           :find: 2.8
# #         ClassMethods#acts_as_range?:
# #           :included_modules: 1.5
# #           :include?: 1.3
# #         ClassMethods#acts_as_date_range_configure_class:
# #           :acts_as_date_range_sequentialize_class: 1.4
# #           :assignment: 1.3
# #           :write_inheritable_attribute: 1.3
# #           :branch: 1.3
# #           :[]: 2.9
# #           :include: 2.6
# #         InstanceMethods#none:
# #           :+: 3.8
# #           :class: 9.20000000000001
# #           :assignment: 5.60000000000001
# #           :private: 1.2
# #           :send: 43.2
# #           :branch: 8.00000000000001
# #           :alias_method: 4.80000000000001
# #           :to_s: 4.2
# #           :to_sym: 6.80000000000001
# #           :define_method: 28.0
# #           :each: 2.4
# #         Ranged#none:
# #           :+: 1.7
# #           :assignment: 3.60000000000001
# #           :select: 1.2
# #           :send: 3.90000000000001
# #           :branch: 3.30000000000001
# #           :to_sym: 1.5
# #           :define_method: 5.50000000000002
# #           :each: 1.0
# #         ClassMethods#acts_as_range_configure_class:
# #           :assignment: 3.20000000000001
# #           :write_inheritable_attribute: 1.3
# #           :alias_method_chain: 1.90000000000001
# #           :branch: 1.8
# #           :validates_interval: 1.3
# #           :to_sym: 2.1
# #           :each: 1.8
# #           :sclass: 6.50000000000002
# #           :include: 2.60000000000001
# #         ClassMethods#ranged_lookup:
# #           :first: 1.5
# #           :respond_to?: 1.4
# #           :last: 1.5
# #           :assignment: 7.00000000000002
# #           :-: 1.7
# #           :branch: 2.80000000000001
# #           :to_a: 1.5
# #           :yield: 1.4
# #           :new: 3.80000000000001
# #           :acts_as_range_begin: 1.5
# #           :acts_as_range_end: 1.5
# #         ClassMethods#find_with_range_restrictions:
# #           :find_without_range_restrictions: 9.80000000000002
# #           :with_current_time_scope: 1.5
# #           :remove_args: 7.50000000000002
# #           :with_before_scope: 1.5
# #           :extract_options_from_args!: 1.4
# #           :assignment: 12.8
# #           :with_containing_scope: 1.5
# #           :send: 5.40000000000001
# #           :with_after_scope: 1.5
# #           :branch: 19.7
# #           :dup: 1.4
# #           :ranged_lookup: 1.7
# #           :acts_as_range_configuration: 1.6
# #           :==: 1.7
# #           :each: 1.4
# #           :keys: 9.90000000000002
# #           :[]: 12.1
# #           :has_key?: 5.70000000000001
# #         InstanceMethods#after?:
# #           :>: 1.3
# #           :respond_to?: 1.3
# #           :branch: 3.90000000000001
# #           :acts_as_range_begin: 2.80000000000001
# #           :after?: 1.4
# #           :acts_as_range_end: 1.6
# #         ClassMethods#acts_as_date_range_singleton_sequentialize_class:
# #           :validate_on_create: 1.3
# #           :add: 1.6
# #           :count: 1.7
# #           :>: 1.5
# #           :acts_as_range_begin_attr: 3.7
# #           :class: 3.8
# #           :errors: 1.8
# #           :assignment: 5.8
# #           :before_validation_on_create: 1.3
# #           :branch: 6.90000000000001
# #           :before_create: 1.3
# #           :now: 1.5
# #           :acts_as_range_begin: 5.6
# #           :acts_as_range_end_attr: 3.8
# #           :each: 1.5
# #           :expire: 1.6
# #           :find: 1.7
# #         ClassMethods#acts_as_date_range?:
# #           :included_modules: 1.5
# #           :include?: 1.3
# #         InstanceMethods#expire:
# #           :second: 1.6
# #           :is_a?: 2.7
# #           :save!: 1.3
# #           :ago: 1.4
# #           :assignment: 4.2
# #           :-: 1.5
# #           :branch: 4.0
# #           :now: 1.3
# #           :lit_fixnum: 0.875
# #           :acts_as_range_end: 1.3
# #         ClassMethods#sequentialized_on:
# #           :[]: 1.3
# #           :acts_as_range_configuration: 1.5
# #         YAML
# 
# #         @totals = YAML.load(<<-YAML)
# #         ---
# #         InstanceMethods#expired?: 5.70438427878067
# #         ClassMethods#sequentialized?: 1.83847763108502
# #         InstanceMethods#contained_by?: 52.0954892481106
# #         ClassMethods#calculate_with_range_restrictions: 8.13449445263812
# #         InstanceMethods#initialize_with_has_many_range_extension: 15.8492902049272
# #         InstanceMethods#destroy_without_callbacks: 31.238757977871
# #         ClassMethods#acts_as_date_range_param_sequentialize_class: 50.3140139523772
# #         ClassMethods#acts_as_date_range_sequentialize_class: 5.55427763079954
# #         InstanceMethods#overlapping?: 25.0267856505785
# #         ClassMethods#with_after_scope: 9.20000000000002
# #         ClassMethods#with_containing_scope: 41.3095630574811
# #         ClassMethods#with_overlapping_scope: 19.8
# #         InstanceMethods#included: 5.20000000000001
# #         ClassMethods#with_current_time_scope: 26.9716517847907
# #         ParamExtension#to_attributes_for: 6.62570750939099
# #         InstanceMethods#to_range: 3.67695526217005
# #         ClassMethods#count_with_range_restrictions: 8.13449445263812
# #         ClassMethods#with_contained_scope: 57.9202900545225
# #         InstanceMethods#lifetime: 15.5273951453552
# #         InstanceMethods#limit_date_range: 9.92824254337091
# #         ClassMethods#acts_as_date_range: 8.60581198958007
# #         InstanceMethods#containing?: 77.6916983982203
# #         InstanceMethods#before?: 9.2612094242599
# #         ClassMethods#add_args: 4.80000000000001
# #         ClassMethods#remove_args: 14.5688022843335
# #         ClassMethods#with_before_scope: 9.20000000000002
# #         DateRanged#current: 2.40000000000001
# #         DateRange#none: 2.2
# #         DateRange#included: 15.6805612144464
# #         ClassMethods#none: 17.171487996094
# #         ParamExtension#to_sql: 3.80131556174965
# #         ClassMethods#acts_as_range: 8.6058119895801
# #         ClassMethods#validates_interval: 47.6073523733468
# #         Range#included: 15.6805612144464
# #         Ranged#included: 12.1593585357124
# #         InstanceMethods#add_has_many_range_extension: 22.0190826330255
# #         InstanceMethods#include?: 10.6677082824757
# #         InstanceMethods#none: 104.05921391208
# #         ClassMethods#acts_as_date_range_configure_class: 8.40357066966181
# #         ClassMethods#acts_as_range?: 2.80000000000001
# #         InstanceMethods#expire: 13.3056613890479
# #         ClassMethods#acts_as_date_range?: 2.8
# #         ClassMethods#acts_as_date_range_singleton_sequentialize_class: 34.8846671189507
# #         InstanceMethods#after?: 9.2612094242599
# #         ClassMethods#find_with_range_restrictions: 69.6799110217573
# #         ClassMethods#ranged_lookup: 17.5065701952153
# #         ClassMethods#acts_as_range_configure_class: 17.8809954980141
# #         Ranged#none: 15.5849286170968
# #         ClassMethods#sequentialized_on: 2.8
# #         YAML
# #       end
# 
# #       it 'should not fail when flogging the given input' do
# #         lambda { @flog.flog_files(fixture_files(@files)) }.should_not raise_error
# #       end
# 
# #       currently 'should report an overall flog score of 981.137760580242' do
# #         @flog.flog_files(fixture_files(@files))
# #         @flog.total.must_be_close_to 981.137760580242
# #       end
# 
# #       currently 'should compute the same call data as flog-1.1.0' do
# #         @flog.flog_files(fixture_files(@files))
# #         @flog.calls.each_pair do |k,v|
# #           v.each_pair do |x, y|
# #             @calls[k][x].must_be_close_to y
# #           end
# #         end
# #       end
# 
# #       currently 'should compute the same totals data as flog-1.1.0' do
# #         @flog.flog_files(fixture_files(@files))
# #         @flog.totals.each_pair do |k,v|
# #           v.must_be_close_to @totals[k]
# #         end
# #       end
# #     end
#   end
# end

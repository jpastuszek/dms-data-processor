# Copyright (c) 2012 Jakub Pastuszek
#
# This file is part of Distributed Monitoring System.
#
# Distributed Monitoring System is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Distributed Monitoring System is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Distributed Monitoring System.  If not, see <http://www.gnu.org/licenses/>.

require 'dms-data-processor/data_type'
require 'set'

class DataProcessor
	def initialize(id, raw_data_key_set, tag_set, &block)
		@id = id
		@raw_data_key_set = raw_data_key_set
		@tag_set = tag_set
		@processor = block
	end

	attr_reader :id
	attr_reader :tag_set

	def data_set(time_from, time_to, storage)
		@processor.call(time_from, time_to, @raw_data_key_set.map do |raw_data_key|
			storage.fetch(raw_data_key)
		end)
	end

	def hash
		@id
	end

	def to_s
		"DataProcessor[#{@id}]<#{@tag_set.to_a.sort.map{|t| t.to_s}.join(', ')}>{#{@raw_data_key_set.to_a.map{|k| k.to_s}.sort.join(', ')}}"
	end
end

class DataProcessorGroup
	class KeyDSL
		include DSL
		def initialize(&block)
			@key_set = Set.new
			dsl_method :key do |key|
				@key_set << RawDataKeyPattern.new(key)
			end
			dsl &block
		end
		attr_reader :key_set
	end

	class GroupDSL
		include DSL
		def initialize(raw_data_key, &block)
			@group = []
			dsl_method :by do |value|
				@group << value.to_s
			end
			dsl raw_data_key, &block
		end
		attr_reader :group
	end

	class TagDSL
		include DSL
		def initialize(group, raw_data_key, &block)
			@tag_set = Set[]
			dsl_method :tag do |tag|
				@tag_set << Tag.new(tag)
			end
			dsl group, raw_data_key, &block
		end
		attr_reader :tag_set
	end

	include DSL

	def initialize(builder_name, name, builder_tag_set)
		@builder_name = builder_name
		@name = name
		p @builder_tag_set = builder_tag_set

		@select_key_pattern_set = Set[]
		@grouppers = []
		@needed_keys_pattern_set = Set[]
		@group_taggers = []

		@processor = nil

		@groups = {}
	end

	def select(&block)
		@select_key_pattern_set.merge(KeyDSL.new(&block).key_set)
		self
	end

	def group(&block)
		@grouppers << lambda { |raw_data_key|
			GroupDSL.new(raw_data_key, &block).group
		}
		self
	end

	def need(&block)
		@needed_keys_pattern_set.merge(KeyDSL.new(&block).key_set)
		self
	end

	def each_group(&block)
		@group_taggers << lambda { |group, raw_data_key|
			TagDSL.new(group, raw_data_key, &block).tag_set
		}
		self
	end

	def process_with(processor_name = nil, &block)
		if block
			@processor = block
		else
			# to be replaced by DataProcessorBuilder
			@processor = processor_name
		end
		self
	end

	attr_reader :builder_name
	attr_reader :name
	attr_accessor :processor

	class Group
		def initialize
			@raw_data_key_set = Set[]
			@tag_set = Set[]
		end

		attr_reader :raw_data_key_set
		attr_reader :tag_set
	end

	def key(raw_data_key)
		@select_key_pattern_set.any? do |raw_data_key_pattern|
			raw_data_key.match? raw_data_key_pattern
		end or return

		log.info "#{@builder_name}/#{@name}: processing new raw data key: #{raw_data_key}"

		@grouppers.each do |groupper|
			group = groupper.call(raw_data_key)
			next if group.empty?
			(@groups[group] ||= Group.new).raw_data_key_set << raw_data_key
		end

		@groups.each_pair do |group_id, group|
			@needed_keys_pattern_set.all? do |raw_data_key_pattern|
				group.raw_data_key_set.any? do |raw_data_key|
					raw_data_key.match? raw_data_key_pattern
				end
			end or next

			log.info "#{@builder_name}/#{@name}: has a complete group: #{group_id}"

			new_tags = Set[]
			@group_taggers.each do |group_tagger|
				new_tags.merge(group_tagger.call(group_id, group.raw_data_key_set))
			end

			new_tags.merge(@builder_tag_set)
			new_tags -= group.tag_set 

			unless new_tags.empty?
				log.info "#{@builder_name}/#{@name}: group #{group_id} has new tags: #{new_tags.map{|t| t.to_s}}"
				group.tag_set.merge(new_tags)

				updated_group(group_id, group)
			end
		end
	end

	def each(&block)
		@data_processor_collector = block
	end

	private

	def updated_group(group_id, group)
		dp_id = [builder_name, name, group_id].flatten.join(':')
		dp = DataProcessor.new(dp_id, group.raw_data_key_set, group.tag_set, &@processor)
		log.info "#{@builder_name}/#{@name}: created new data processor: #{dp}"
		@data_processor_collector.call(dp) if @data_processor_collector
	end
end

class DataProcessorBuilder
	include DSL

	def initialize(name, data_type, &block)
		@name = name
		@data_type = data_type

		@builder_tag_set = Set.new
		dsl_method :tag do |tag|
			@builder_tag_set << Tag.new(tag)
		end

		@processors = {}
		dsl_method :processor do |name, &block|
			@processors[name] = block
		end

		@data_processor_groups = []
		dsl_method :data_processor do |name|
			dpg = DataProcessorGroup.new(@name, name, @builder_tag_set)
			@data_processor_groups << dpg
			dpg
		end

		dsl &block

		# link named processors
		@data_processor_groups.each do |data_processor_group|
			processor = data_processor_group.processor
			data_processor_group.processor = @processors.fetch(processor) if not processor.is_a? Proc
		end
	end

	attr_reader :name
	attr_reader :data_type

	def each(&block)
		@data_processor_groups.each do |data_processor_group|
			data_processor_group.each(&block)
		end
	end

	def key(raw_data_key)
		@data_processor_groups.each do |data_processor_group|
			data_processor_group.key(raw_data_key)
		end
	end
end


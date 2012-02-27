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
	def initialize(data_type, id, raw_data_key_set, tag_set, &block)
		@data_type = data_type
		@id = id
		@raw_data_key_set = raw_data_key_set
		@tag_set = tag_set
		@processor = block
	end

	attr_reader :data_type
	attr_reader :id
	attr_reader :tag_set
	attr_reader :raw_data_key_set

	def data_set(time_from, time_to, storage)
		@processor.call(time_from, time_to, @raw_data_key_set.map do |raw_data_key|
			storage.fetch(raw_data_key)
		end)
	end

	def hash
		@id
	end

	def to_s
		"DataProcessor[#{@data_type}][#{@id}]<#{@tag_set.to_a.sort.map{|t| t.to_s}.join(', ')}>{#{@raw_data_key_set.to_a.map{|k| k.to_s}.sort.join(', ')}}"
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
			@group_id = []
			dsl_method :by do |value|
				@group_id << value.to_s
			end
			dsl raw_data_key, &block
		end
		attr_reader :group_id
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

	class Filter
		def initialize
			@raw_data_key_pattern_set = Set[]
		end

		def merge(raw_data_key_pattern_set)
			@raw_data_key_pattern_set.merge(raw_data_key_pattern_set)
		end

		def pass?(raw_data_key)
			@raw_data_key_pattern_set.any? do |raw_data_key_pattern|
				raw_data_key.match? raw_data_key_pattern
			end or return
		end
	end

	class Aggregator
		class Group
			def initialize(id)
				@id = id
				@raw_data_key_set = RawDataKeySet[]
				@tag_set = TagSet[]
			end

			attr_reader :id
			attr_reader :raw_data_key_set
			attr_reader :tag_set

			def to_s
				"<#{id.map{|e| e.to_s}.join(':')}>"
			end
		end

		def initialize
			@aggregators = []
			@groups = {}
		end

		def <<(aggregator)
			@aggregators << aggregator
		end

		def aggregate(raw_data_key)
			@aggregators.each do |aggregator|
				group_id = aggregator.call(raw_data_key)
				next if group_id.empty?
				(@groups[group_id] ||= Group.new(group_id)).raw_data_key_set << raw_data_key
			end
		end

		def each_group(&block)
			@groups.each_value(&block)
		end
	end

	class Gate
		def initialize
			@needed_keys_pattern_set = Set[]
		end

		def merge(raw_data_key_pattern)
			@needed_keys_pattern_set.merge raw_data_key_pattern
		end

		def pass?(group)
			@needed_keys_pattern_set.all? do |raw_data_key_pattern|
				group.raw_data_key_set.any? do |raw_data_key|
					raw_data_key.match? raw_data_key_pattern
				end
			end
		end
	end

	class Tagger
		def initialize
			@group_taggers = []
		end

		def <<(tagger)
			@group_taggers << tagger
		end

		def tags(group)
			@group_taggers.reduce(TagSet[]) do |tags, group_tagger|
				tags.merge(group_tagger.call(group.id, group.raw_data_key_set))
			end
		end
	end

	def initialize(data_type, builder_name, name, builder_tag_set)
		@data_type = data_type
		@builder_name = builder_name
		@name = name
		@builder_tag_set = builder_tag_set

		@filter = Filter.new
		@aggregator = Aggregator.new
		@gate = Gate.new
		@tagger = Tagger.new

		@processor = nil

		@groups = {}
	end

	attr_reader :builder_name
	attr_reader :name
	attr_accessor :processor

	def select(&block)
		@filter.merge(KeyDSL.new(&block).key_set)
		self
	end

	def group(&block)
		@aggregator << lambda { |raw_data_key|
			GroupDSL.new(raw_data_key, &block).group_id
		}
		self
	end

	def need(&block)
		@gate.merge(KeyDSL.new(&block).key_set)
		self
	end

	def each_group(&block)
		@tagger << lambda { |group, raw_data_key|
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

	def data_processors(raw_data_key)
		@filter.pass?(raw_data_key) or return []

		log.debug "#{@builder_name}/#{@name}: processing new raw data key: #{raw_data_key}"

		data_processors = []
		@aggregator.aggregate(raw_data_key)
		@aggregator.each_group do |group|
			@gate.pass?(group) or next

			log.debug "#{@builder_name}/#{@name}: has a complete group: #{group}"

			new_tags = @tagger.tags(group)
			new_tags.merge(@builder_tag_set)
			new_tags -= group.tag_set 

			unless new_tags.empty?
				log.info "#{@builder_name}/#{@name}: group #{group} has new tags: #{new_tags}"
				group.tag_set.merge(new_tags)

				data_processors << make_data_processor(group)
			end
		end

		data_processors
	end

	private

	def make_data_processor(group)
		dp_id = [builder_name, name, group.id].flatten.join(':')
		dp = DataProcessor.new(@data_type, dp_id, group.raw_data_key_set, group.tag_set, &@processor)
		log.info "#{@builder_name}/#{@name}: created new data processor: #{dp}"
		dp
	end
end

class DataProcessorBuilder
	include DSL

	def initialize(name, data_type, &block)
		@name = name
		@data_type = data_type

		@builder_tag_set = TagSet[]
		dsl_method :tag do |tag|
			@builder_tag_set << Tag.new(tag)
		end

		@processors = {}
		dsl_method :processor do |name, &block|
			@processors[name] = block
		end

		@data_processor_groups = []
		dsl_method :data_processor do |name|
			dpg = DataProcessorGroup.new(@data_type, @name, name, @builder_tag_set)
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

	def data_processors(raw_data_key)
		@data_processor_groups.inject([]) do |data_processors, data_processor_group|
			data_processors.concat(data_processor_group.data_processors(raw_data_key))
		end
	end
end


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

require 'set'

class RawDataKey
	module Path
		def method_missing(name, *args, &block)
			super unless respond_to? :split
			self.split('/').send(name, *args, &block)
		end
	end

	def self.[](location, path, component)
		self.new(location, path, component)
	end

	def initialize(location, path, component)
		@location = location
		@path = path.dup
		@path.extend Path
		@component = component
	end

	attr_reader :location
	attr_reader :path
	attr_reader :component

	def eql?(rdk)
		@location.eql?(rdk.location) and @path.eql?(rdk.path) and @component.eql?(rdk.component)
	end

	def ==(rdk)
		@location == rdk.location and @path == rdk.path and @component == rdk.component
	end
	
	def hash
		#TODO: is this good enough?
		@location.hash / 3 + @path.hash  / 3 + @component.hash / 3
	end

  def match?(value)
    pattern = if value.is_a?(RawDataKeyPattern)
      value
    else
      RawDataKeyPattern.new(value)
    end

		if pattern.location
			if pattern.location.is_a? Regexp
				return false unless @location =~ pattern.location
			else
				return false unless @location == pattern.location
			end
		end

		if pattern.prefix
			@path.to_a.zip(pattern.prefix.to_a).each do |path_element, prefix_element|
				break unless prefix_element
				return false if path_element != prefix_element
			end
		end

		unless pattern.components.empty?
			return false unless pattern.components.include?(@component)
		end

		true
	end

	def to_s
		"RawDataKey[#{@location}:#{@path}/#{@component}]"
	end
end

class RawDataKeySet < Set
end

class RawDataKeyPattern
	def initialize(string)
		@location, @prefix_components = string.match(/(.*(?=:))?:?(.*)/).captures

		if @location
			if @location.empty?
				@location = nil
			elsif @location[0] == '/' and @location[-1] == '/' 
				@location = Regexp.new(@location.slice(1...-1), Regexp::EXTENDED | Regexp::IGNORECASE)
			end
		end

		@prefix, @components = @prefix_components.match(/([^\[]*)\[?([^\]]*)\]?$/).captures
		@prefix = nil if @prefix.empty?
		@components = Set.new(@components.split(/, */))

		@prefix.extend(RawDataKey::Path)
	end

	attr_reader :location
	attr_reader :prefix
	attr_reader :components

	def to_s
		a = []

		if @location
			if @location.is_a? Regexp
				a << @location.inspect.scan(/\/.*\//)
			else
				a << @location
			end
		end

		b = []
		b << @prefix if @prefix
		b << '[' + @components.to_a.join(', ') + ']' unless @components.empty?

		a << b.join
		a.join(':')
	end

	def inspect
		"#<RawDataKeyPattern @location=#{@location.inspect}, @prefix=#{@prefix.inspect}, @components=#{@components.inspect}>"
	end
end

class RawDatum
	def self.[](time_stamp, value)
		self.new(time_stamp, value)
	end

	def initialize(time_stamp, value)
		@time_stamp = DataType.to_time(time_stamp)
		@value = value
	end

	attr_reader :time_stamp
	attr_reader :value

	def <=>(a)
		-(@time_stamp <=> a.time_stamp)
	end

	def ==(b)
		time_stamp == time_stamp and value == value
	end

	def to_s
		"RawDatum[#{@time_stamp}: #{@value}]"
	end
end

class DataSource
	def initialize(data_processor, storage)
		@data_processor = data_processor
		@storage = storage
	end

	def data_set(time_from, time_span)
		@data_processor.data_set(time_from, time_span, @storage)
	end

	def data_type_name
		@data_processor.data_type_name
	end

	def tag_set
		@data_processor.tag_set
	end

	def hash
		@data_processor.hash
	end

	def eql?(ds)
		hash == ds.hash
	end

	def ==(rdk)
		hash == ds.hash
	end
	
	def hash
		#TODO: is this good enough?
		@data_processor.hash / 2 + @storage.hash / 2
	end

	def to_s
		"DataSource[#{@data_processor.data_type_name}]:<#{@data_processor.tag_set.to_s}>"
	end

	def inspect
		"#<DataSource:#{hash}>"
	end
end

class StorageController
	def initialize(storage)
		@storage = storage
		@tag_space = TagSpace.new
		@data_processor_builders = Set[]
	end

	def store(raw_data_key, raw_datum)
		if @storage.store(raw_data_key, raw_datum)
			@data_processor_builders.each do |data_processor_builder|
				data_processor_builder.classify(raw_data_key).each do |data_processor|
					data_processor.tag_set.each do |tag|
						@tag_space[tag] = DataSource.new(data_processor, @storage)
					end
				end
			end
		end
	end

	def [](tag_expression)
		@tag_space[tag_expression]
	end

	def <<(data_processor_builder)
		@data_processor_builders << data_processor_builder
	end
end


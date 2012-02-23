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

	def ==(rdk)
		@location == rdk.location and @path == rdk.path and @component == rdk.component
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
end

class RawDataKeyPattern
	def initialize(string)
		@location, @prefix = string.split(':', 2)
		if not @prefix
			@prefix = @location 
			@location = nil
		end

		@location = nil if @location and @location.empty?

		if @location and @location[0] == '/' and @location[-1] == '/' 
			@location = Regexp.new(@location.slice(1...-1), Regexp::EXTENDED | Regexp::IGNORECASE)
		end

		@prefix, @components = *@prefix.scan(/([^\[]+)\[?([^\]]*)\]?$/).first
		@components = @components.split(/, */)

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
		b << '[' + @components.join(', ') + ']' unless @components.empty?

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
end

class StorageController
	class Node < Hash
		def initialize
			super
			@callbacks = Set.new
		end

		def <<(callback)
			@callbacks << callback
		end

		attr_reader :callbacks
	end

	def initialize(storage)
		@storage = storage
		@notify_value_tree = {}
		@notify_raw_data_key = {}
	end

	def store(raw_data_key, raw_datum)
		new_component = ! @storage.fetch(raw_data_key.path, {}).fetch(raw_data_key.location, {}).has_key?(raw_data_key.component)

		@storage.store(raw_data_key, raw_datum)

		find_callbacks(raw_data_key.path.to_a, @notify_value_tree).each do |callback|
			callback[raw_data_key, raw_datum]
		end

		if new_component
			find_callbacks(raw_data_key.path.to_a, @notify_raw_data_key).each do |callback|
				callback[raw_data_key]
			end
		end
	end

	def [](prefix)
		@storage[prefix]
	end

	def fetch(path, default = :magick, &block)
		@storage.fetch(path, default, &block)
	end

	def notify_value(prefix, &callback)
		prefix = prefix.dup
		prefix.extend(RawDataKey::Path)
		make_nodes(prefix.to_a, @notify_value_tree) << callback
	end

	def notify_raw_data_key(prefix, &callback)
		prefix = prefix.dup
		prefix.extend(RawDataKey::Path)
		make_nodes(prefix.to_a, @notify_raw_data_key) << callback
	end

	private

	# TODO: move to own class
	def find_callbacks(path_elements, root)
		callbacks = Set.new
		return callbacks if path_elements.empty?

		node = root[path_elements.shift]
		return callbacks unless node

		callbacks.merge(node.callbacks)
		callbacks.merge(find_callbacks(path_elements, node))

		callbacks
	end

	def make_nodes(path_elements, root)
		return root if path_elements.empty?
		make_nodes(path_elements, root[path_elements.shift] ||= Node.new)
	end
end


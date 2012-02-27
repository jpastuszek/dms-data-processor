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

class MemoryStorage
	class Node < Hash
	end

	class Leaf < Node
	end

	class RingBuffer
		include Enumerable

		def initialize(size)
			@buffer = []
			@size = size
			@next_pos = 0
			@length = 0
		end

		def <<(o)
			@buffer[@next_pos] = o
			@next_pos += 1
			@next_pos %= @size
			@length += 1 if @length < @size
		end

		def each
			@length.times do |time|
				yield @buffer[(@next_pos - 1 - time) % @size]
			end
		end

		def range(time_from, time_to)
			select do |raw_datum|
				raw_datum.time_stamp <= time_from and raw_datum.time_stamp >= time_to
			end
		end
	end

	def initialize(size = 10000)
		@store = {}
		@size = size
	end

	def store(raw_data_key, raw_datum)
		node = make_nodes(raw_data_key.path.to_a)
		components = (node[raw_data_key.location] ||= {})

		if component = components[raw_data_key.component]
			component << raw_datum
			return false
		else
			(components[raw_data_key.component] = RingBuffer.new(@size)) << raw_datum
			return true
		end
	end

	def fetch(raw_data_key, default = :magick, &block)
		path = raw_data_key.path.to_a
		root = @store

		until path.empty?
			root = root[path.shift]
			break unless root
		end

		if root.is_a? Leaf
			if location = root[raw_data_key.location]
				if component = location[raw_data_key.component]
					return component
				end
			end
		end

		return default unless default == :magick
		return block.call(path) if block
		raise KeyError, 'key not found'
	end

	private

	def find_node(path_elements, root = @store, path = [])
		if path_elements.empty?
			return resolve_branch(root, path)
		end

		path_element = path_elements.shift
		path << path_element 
		root = root[path_element] or return nil

		find_node(path_elements, root, path)
	end

	def resolve_branch(node, path)
		branch = {}
		node.each_pair do |path_element, sub_node|
			if sub_node.is_a? Node
				branch.merge!(resolve_branch(sub_node, path + [path_element]))
			else
				(branch[path.join('/')] ||= {})[path_element] = sub_node
			end
		end
		branch
	end

	def make_nodes(path_elements, root = @store)
		return root if path_elements.empty?

		node = path_elements.length > 1 ? Node.new : Leaf.new
		make_nodes(path_elements, root[path_elements.shift] ||= node)
	end
end


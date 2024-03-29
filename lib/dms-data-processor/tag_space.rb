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

class TagSpace
	class Component < String
		def initialize(value)
			super value.downcase
		end
	end

	class Node
		def initialize
			@branches = {}
			@values = Set.new
		end

		attr_reader :branches
		attr_reader :values
	end

	def initialize
		@tags = Node.new
	end

	def []=(tag, value)
		tag = tag.is_a?(Tag) ? tag.dup : Tag.new(tag)

		begin
			make_branch(tag, value, @tags)
			tag.shift
		end until tag.empty?

		self
	end

	def [](value)
		sets = value.to_tag_expression.reduce([]) do |collection, pattern|
			collection << fetch(pattern, @tags)
		end

		return [] if sets.empty?
		sets.reduce(sets.shift) do |out, set|
			out &= set
		end.to_a
	end

	private

	def fetch(pattern, root)
		pattern = pattern.is_a?(TagPattern) ? pattern.dup : TagPattern.new(pattern)
		return Set.new if pattern.empty?

		pattern_component = pattern.shift

		nodes = []
		if pattern_component.is_a? Regexp
			root.branches.keys.select{|key| key =~ pattern_component}.each do |key|
				nodes << root.branches[key]
			end
		else
			node = root.branches[Component.new(pattern_component)]
			nodes << node if node
		end
		return Set.new if nodes.empty?

		values = Set.new

		nodes.each do |node|
			if pattern.empty?
				values.merge(node.values)
				values.merge(collect_tree(node))
			else
				values.merge(fetch(pattern, node))
			end
		end

		values
	end

	def make_branch(tag, value, root)
		return root if tag.empty?

		tag = tag.dup
		key = Component.new(tag.shift)
		node = (root.branches[key] ||= Node.new)

		if tag.empty?
			node.values << value
		else
			make_branch(tag, value, node)
		end

		root
	end

	def collect_tree(root)
		values = Set.new

		root.branches.each_value do |node|
			values.merge(node.values)
			values.merge(collect_tree(node))
		end

		values
	end
end


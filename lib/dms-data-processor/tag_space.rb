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

	def [](pattern)
		fetch(pattern, @tags).to_a
	end

	private

	def fetch(pattern, root)
		pattern = pattern.is_a?(TagPattern) ? pattern.dup : TagPattern.new(pattern)
		return [] if pattern.empty?

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
		return [] if nodes.empty?

		values = Set.new

		nodes.each do |node|
			if pattern.empty?
				values += node.values.to_a
				values += collect_tree(node)
			else
				values += fetch(pattern, node)
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
			values += node.values.to_a
			values += collect_tree(node)
		end

		values
	end
end


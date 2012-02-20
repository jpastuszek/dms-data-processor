class MemoryStorage
	class Node < Hash
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
	end

	def initialize(size = 10000)
		@store = {}
		@size = size
	end

	def store(location, path, component, value)
		node = make_nodes(path.split('/'))
		((node[location] ||= {})[component] ||= RingBuffer.new(@size)) << value
		self
	end

	def [](prefix)
		find_node(prefix.split('/'))
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
		make_nodes(path_elements, root[path_elements.shift] ||= Node.new)
	end
end

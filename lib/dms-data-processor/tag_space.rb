require 'set'

class TagSpace
	class Component < String
		def initialize(value)
			super value.downcase
		end
	end

	class ValueSet
		def initialize
			@components = Set.new
			@values = Set.new
		end

		attr_reader :components
		attr_reader :values
	end

	def initialize
		@tags = {}
	end

	def []=(tag, value)
		tag = tag.is_a?(Tag) ? tag.dup : Tag.new(tag)

		begin
			tag1, tag2 = *tag.take(2)

			key = Component.new(tag1)

			value_set = (@tags[key] ||= ValueSet.new)

			if tag2
				value_set.components << Component.new(tag2)
			else
				value_set.values << value
			end

			tag.shift
		end until tag.empty? 

		self
	end

	def [](pattern)
		pattern = pattern.is_a?(TagPattern) ? pattern.dup : TagPattern.new(pattern)
		out = Set.new
		return out if pattern.empty?

		pattern_component = pattern.shift

		value_set = if pattern_component.is_a? Regexp
			@tags[@tags.keys.find{|key| key =~ pattern_component}]
		else
			@tags[Component.new(pattern_component)]
		end
		return out unless value_set

		out += value_set.values
		
		if pattern.empty?
			# no more patterns to match get whole sub tree
			value_set.components.each do |tag_component|
				out += self[TagPattern.new(tag_component)]
			end
		else
			# match next pattern
			out += self[pattern]
		end

		out.to_a
	end
end


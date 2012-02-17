require 'set'

class TagSpace
	class TagComponent < String
		def initialize(value)
			super value.downcase
		end
	end

	class TagSubValue
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

			key = TagComponent.new(tag1)

			sub_value = (@tags[key] ||= TagSubValue.new)

			if tag2
				sub_value.components << TagComponent.new(tag2)
			else
				sub_value.values << value
			end

			tag.shift
		end until tag.empty? 
		self
	end

	def [](pattern)
		p fetch(pattern.is_a?(TagPattern) ? pattern.dup : TagPattern.new(pattern))
	end

	private

	def fetch(pattern)
		set = Set.new
		p @tags
		puts "pattern: #{pattern}"

		pattern_component = pattern.shift
		return set unless pattern_component

		sub_value = if pattern_component.is_a? Regexp
			@tags[@tags.keys.find{|key| key =~ pattern_component}]
		else
			@tags[TagComponent.new(pattern_component)]
		end
		p sub_value
		return set unless sub_value

		set += sub_value.values
		
		if pattern.empty?
			sub_value.components.each do |pattern|
				set += fetch([pattern])
			end
		else
			set += fetch(pattern)
		end

		set.to_a
	end
end


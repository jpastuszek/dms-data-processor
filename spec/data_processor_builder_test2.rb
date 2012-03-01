DataProcessorBuilder.new('system CPU count', 'count') do
	tag 'hello'
	tag 'world'

	classifier('count').select do
		key 'system/CPU usage/CPU[user]'
	end.group do |raw_data_key|
		by raw_data_key.location
	end.need do
		key 'system/CPU usage/CPU[user]'
	end.each_group do |group, raw_data_keys|
		tag "location:#{group.first}"
		tag "system:CPU count"
	end.process_with do |time_from, time_span, data_sources|
		collect 'count', time_from, data_sources.length
	end
end


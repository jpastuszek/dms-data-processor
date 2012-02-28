DataProcessorBuilder.new('system CPU usage', 'CPU usage') do
	tag 'hello'
	tag 'world'

	data_processor('cpu').select do
		key 'system/CPU usage/CPU[user, system, stolen]'
	end.group do |raw_data_key|
		by raw_data_key.location
		by raw_data_key.path.last
	end.need do
		key 'system/CPU usage/CPU[user]'
		key 'system/CPU usage/CPU[system]'
	end.each_group do |group, raw_data_keys|
		tag "location:#{group.first}"
		tag "system:CPU usage:CPU:#{group.last}"

		tag "virtual" if raw_data_keys.any? do |raw_data_key|
			raw_data_key.component == 'stolen'
		end
	end.process_with(:cpu_time_delta)

	data_processor('total').select do
		key 'system/CPU usage/total[user, system, stolen]'
	end.group do |raw_data_key|
		by raw_data_key.location
	end.need do
		key 'system/CPU usage/total[user]'
		key 'system/CPU usage/total[system]'
	end.each_group do |group, raw_data_keys|
		tag "location:#{group.first}"
		tag "system:CPU usage:total"

		tag "virtual" if raw_data_keys.any? do |raw_data_key|
			raw_data_key.component == 'stolen'
		end
	end.process_with :cpu_time_delta

	data_processor('count').select do
		key 'system/CPU usage/CPU'
	end.group do |raw_data_key|
		by raw_data_key.location
	end.need do
		key 'system/CPU usage/CPU'
	end.each_group do |group, raw_data_keys|
		tag "location:#{group.first}"
		tag "system:CPU count"
	end.process_with do |time_from, time_to, data_sources|
		collect 'count', time_from, data_sources.keys.length
	end

	processor(:cpu_time_delta) do |time_from, time_to, data_sources|
		data_sources.each do |raw_data_key, raw_data|
			rd = raw_data.range(time_from, time_to)

			old = nil
			rd.each do |new|
				if old
					time_delta = (new.time_stamp - old.time_stamp).to_f
					value_delta = (new.value - old.value).to_f / 1000

					collect raw_data_key.component, new.time_stamp - (time_delta / 2),  value_delta / time_delta
				end
				old = new
			end
		end
	end
end

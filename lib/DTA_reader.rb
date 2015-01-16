#!/usr/bin/env ruby

require 'colorize'

class DTA_ReaderErr < Exception; end

class DTA_Reader
	
	attr_reader :output_ary, :fileinfo
	
	def initialize(filename, out_filename = nil)
		if File.exist?(filename) then
			@input_file = filename.to_s
			@input_ary = Array.new
			@output_ary = Array.new
			@fileinfo = Hash.new
			File.foreach(@input_file) { |line| @input_ary << line.chomp  }
			parse
			export(out_filename) if out_filename
		else
			raise DTA_ReaderErr, "File #{filename} do not exists!".red 
		end
	end

	# Export data to TSV file
	def export(filename)
		out = File.open(filename, 'w+')
		
		# Write file eader information
		out.puts '# ' + "#{@input_file} :: #{@fileinfo}"
		outstr = ""
		@output_ary.each { |e| 
			outstr += "#{e[:name]}_#{e[:unit]}\t"
		}
		out.puts outstr.rstrip

		(0..@output_ary[0][:values].size - 1).each { |i|
			outstr = ""
			@output_ary.each { |e|  
				outstr += "#{'%.8e' % e[:values][i]}\t"
			}
			out.puts outstr.rstrip
		}

		out.close
	end

	private

	# Actual data parsing
	def parse
		sampling
		count 
		trigger
		@output_ary << {:id => 0, :name => "time", :unit => "(s)", :values => generate_time, :factor => 1.0, :offset => 0}

		(1..6).each { |i|  
			e = {:id => i, :name => "", :unit => "", :values => Array.new, :factor => 0.0, :offset => channel_offset(i)}
			if e[:offset] > 0 then
				e[:name] = channel_name(i)
				e[:unit] = channel_unit(i)
				e[:factor] = channel_factor(i)
				e[:values] = channel_values(i)
				@output_ary << e
			end
		}
	end

	# Channel specific methods: num is always input channel number
	
	# Returns the channel data starting point
	def channel_offset(num)
		regexp = /^\[CHANNEL\s*#{num}\]/
		@input_ary.each_with_index { |e,i| 
		#puts "Found channel #{num}".green
			return i+1 if e =~ regexp
		}
		puts "WARNING: Channel #{num} not found!".yellow
		return -1
	end

	# Searches for channel name. Raise an error if it cannot find it.
	def channel_name(num)
		regexp = /^CHANNEL#{num}="(.*)"\s*/
		@input_ary.each { |e| 
			return $1.to_s.gsub(/\s+/,"_").strip if e =~ regexp
		}
		raise DTA_ReaderErr, "Cannot find channel #{num} name"
	end

	# Searches for channel measurement unit, set to default (unknown) if it cannot find it
	def channel_unit(num)
		regexp = /^DIM#{num}="(.*)"\s*/
		@input_ary.each { |e| 
			return "(" + $1.to_s.gsub(/\s+/,"_").strip + ")" if e =~ regexp
		}
		puts "WARNING: Cannot find channel #{num} name. Assigning a default value"
		return "(unknown)"
	end

	# Searches for the channel factor. Returns 1.0 if it cannot find it.
	def channel_factor(num)
		regexp = /^FACTOR#{num}=(.*)\s*/
		@input_ary.each { |e| 
			return $1.to_f if e =~ regexp
		}
		puts "WARNING: Cannot find channel #{num} factor. Assigning a default value"
		return 1.0
	end

	# Read actual channel data starting from the trigger point.
	def channel_values(num)
		ret = Array.new
		
		count unless @fileinfo[:count]
		trigger unless @fileinfo[:trigger]

		offset = channel_offset(num)
		factor = channel_factor(num)
		@input_ary[(offset + @fileinfo[:trigger])..(offset + @fileinfo[:count] - 1)].each_with_index { |line,i|
			split = line.split
			raise DTA_ReaderErr, "Error parsing file at line #{i+1}" if split.size != 3
			ret << (split[0].to_f * factor)
		}
		return ret
	end

	# Global file methods
	# Searches for sampling time
	def sampling
		@input_ary.each_with_index { |line,i|
			if line =~ /^SAMPLING=([0-9]*)\s*/
				@fileinfo[:sampling] = $1.to_i 
				at = i+1
			end
		}
		raise DTA_ReaderErr, "Cannot find sampling time!" unless @fileinfo[:sampling]
		raise DTA_ReaderErr, "Error parsing sampling time :: #{@input_file}:#{at} :: SAMPLING=" + $1.inspect if @fileinfo[:count] == 0
	end

	# Searches for number of elements
	def count
		@input_ary.each_with_index { |line,i|
			if line =~ /^COUNT=([0-9]*)\s*/
				@fileinfo[:count] = $1.to_i 
				at = i+1
			end
		}
		raise DTA_ReaderErr, "Cannot define number of elements!" unless @fileinfo[:count]
		raise DTA_ReaderErr, "Error parsing elements count :: #{@input_file}:#{at} :: COUNT=" + $1.inspect if @fileinfo[:count] == 0
	end

	# Serches for trigger offset
	def trigger
		count unless @fileinfo[:count]
		@input_ary.each_with_index { |line,i|
			if line =~ /^TRIGGER=([0-9]*)\s*/
				@fileinfo[:trigger] = $1.to_i 
				at = i
			end
		}
		raise DTA_ReaderErr, "Cannot define trigger offset!" unless @fileinfo[:count]
	end

	# Return an array of time, starting from the trigger point
	def generate_time
		ret = Array.new
		count unless @fileinfo[:count]
		trigger unless @fileinfo[:trigger]
		sampling unless @fileinfo[:sampling]

		(0..@fileinfo[:count] - @fileinfo[:trigger] - 1).each {|i| 
			ret << (i * @fileinfo[:sampling] * 1e-6)
		}
		return ret
	end
end
#EOF
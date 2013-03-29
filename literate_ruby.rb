code = ARGF.readlines.select { |line| 

		line[/^(\t)/] }.each_with_index {|l, i| p "#{i} #{l}" }.map { |line| line[1..-1] }.join
		

eval code


# to deploy in production: grep -E "^	" my_file.md > app.rb 

	require 'rubygems'
	require 'bundler/setup'
	require 'sinatra'
	require 'data_mapper'
	require 'dm-postgres-adapter'
	require 'pg'
	require 'thin'
	require 'haml'
	require 'barista'
	require 'aws-sdk' 
	AUTH_PAIR = [ENV['AIDDATA_FS_USERNAME'], ENV['AIDDATA_FS_PASSWORD']]
	BUCKET_NAME = 'aiddata-fs'
	AWS_ACCESS_KEY_ID =  ENV['AWS_ACCESS_KEY_ID']
	AWS_ACCESS_SECRET_KEY =  ENV['AWS_SECRET_KEY']
	DataMapper.setup(:default, ENV['DATABASE_URL'] || 'postgres://postgres:postgres@localhost/postgres')
	NOT_SAVED = "{ \"error\" : \" not saved \" }"
	NOT_FOUND = "{ \"error\" : \" not found \" }"
	NOT_IMPLEMENTED = "{ \"error\" : \" not implemented\" }"
	NOT_RECEIVED = "{ \"error\" : \" no file received\" }"
	NOT_DELETED = "{ \"error\" : \" not deleted\" }"
	FILE_TOO_BIG =  "{ \"error\" : \"this file is too large!\" }"
	SUCCESS = "{ \"success\" : \"success\" }"
	FILESYSTEM_ROOT = "files"
	MAX_FILE_SIZE = 10485760 # in bytes
	class Namespace
		include DataMapper::Resource
		property :name, String, key: true
		has n, :projects
		def to_json
			json = "{ 
					\"type\": \"namespace\", 
					\"key\" :  \"#{name}\",
					\"name\" :  \"#{name}\", 
					\"project_count\" : #{projects.count} 
				}"
		end
	end
	def protected!
		unless authorized?
			p "Unauthorized request."
			response['WWW-Authenticate'] = %(Basic realm="AidDataFS")
			throw(:halt, [401, "Not authorized\n"])
		end
	end
	def authorized?
		@auth ||=  Rack::Auth::Basic::Request.new(request.env)
		@auth.provided? && @auth.basic? && @auth.credentials && @auth.credentials == AUTH_PAIR
	end
	class Project
		include DataMapper::Resource
		property :id, String, key: true
		property :namespace_name, String, key: true
		belongs_to :namespace
		has n, :links
		has n, :documents, through: :links
		def to_json
			json = "{
					\"type\": \"project\",
					\"key\" :  \"#{id}\",
					\"name\" : \"#{id}\",
					\"id\" :  \"#{id}\", 
					\"document_count\" : #{documents.count} }"
		end
	end
	class Link
		include DataMapper::Resource
		property :id, Serial
		belongs_to :project
		belongs_to :document
		def link_json
			json = "{\"type\": \"link\", 
					\"project_id\" :  \"#{project.id}\", 
					\"document_id\" : #{document.pk}, 
					\"document\" : \"#{document.to_json}\" }"
		end
		def to_json
			# vv This is what matters! vv
			document.to_json
		end
	end
	class Document
		include DataMapper::Resource
		
		require 'digest/md5'
		property :pk, Serial 
		# property :id, Integer #not really a pk, because doc can change versions.
		property :md5, String
		property :url, Text
		property :size_in_kb, Integer
		property :type, Text, default: lambda { |r, p| File.extname(r.name).gsub(/\./, '')  }
		property :name, Text
		def to_json
			json = "{ 
					\"type\" : \"document\",
					\"name\" : \"#{name}\", 
					\"key\" : \"#{pk}\", 
					\"size_in_kb\" : #{size_in_kb},
					\"filetype\" : \"#{type}\",
					\"md5\" : \"#{ md5}\",	
					\"path\" : \"/documents/#{pk}\" 
				}"
		end
	end
	DataMapper.finalize.auto_upgrade!
	get "/" do
		haml :browse
	end
	get "/#{FILESYSTEM_ROOT}" do
		locate "root", Namespace.all
	end
	def locate(location, contents=nil)
		# location: string OR obj that responds to to_json
		# contents: array with objs that respond to :to_json
		if location.respond_to? :to_json
			location = location.to_json
		else
			location = "\"#{location}\""
		end
		vals = ["\"location\" : #{location}"]
		
		if contents
			vals.push "\"contents\" : [#{contents.map{|c| c.to_json}.join ", "}]"
		end
		"{ #{ vals.join ", "}}"
	end
	post "/#{FILESYSTEM_ROOT}" do
		
		protected!
		
		n = Namespace.new(name: params[:name])
		if n.save
			n.to_json
		else
			p n.errors
			NOT_SAVED
		end
	end	
	get "/#{FILESYSTEM_ROOT}/:namespace" do
		if n = Namespace.get(params[:namespace])
			locate n.name, n.projects
		else
			NOT_FOUND
		end
	end
	post "/#{FILESYSTEM_ROOT}/:namespace" do
		protected! 
		
		
		if n = Namespace.get(params[:namespace])
			if p = Project.new(id: params[:project_id])
				if (n.projects << p) && n.save
					p.to_json
				else
					NOT_SAVED
				end
			else
				NOT_SAVED
			end
		else
			NOT_FOUND
		end
	end
	delete "/#{FILESYSTEM_ROOT}/:namespace" do
		
		protected!
		
		n = Namespace.get(params[:namespace])
		
		if n.destroy
			SUCCESS
		else
			NOT_DELETED
		end
	end
	get "/#{FILESYSTEM_ROOT}/:namespace/:project" do
		
		if n = Namespace.get(params[:namespace]) && p = Project.get(params[:project], params[:namespace])
			locate p.id, p.documents
		else
			NOT_FOUND
		end
	end
	delete "/#{FILESYSTEM_ROOT}/:namespace/:project" do
		protected!
		if (n = Namespace.get(params[:namespace])) && (p = Project.get(params[:project], params[:namespace]))
		
			if  p.destroy
				SUCCESS
			else
				NOT_DELETED
			end	
		else
			NOT_FOUND
		end
	end
	post "/#{FILESYSTEM_ROOT}/:namespace/:project" do
		
		protected!
		if n = Namespace.get(params[:namespace]) && p = Project.get(params[:project], params[:namespace])
			if params[:file]
				p "Receiving file #{params[:file]}"
				
				
				unless params[:file] && (tempfile = params[:file][:tempfile]) && (name = params[:file][:filename])
					NOT_SAVED
				end
				
				if tempfile.size <= MAX_FILE_SIZE
					if d = find_or_store(tempfile, name)
						p "Making Link object"
						l = Link.new(document: d, project: p)
						l.save
						locate l
					else
						NOT_SAVED
					end
				else
					FILE_TOO_BIG
				end
			else
				NOT_RECEIVED
			end
		else
			NOT_FOUND
		end
	end
	get "/#{FILESYSTEM_ROOT}/:namespace/:project/:document" do
		if d = Document.get(params[:document])
			require 'open-uri'
			p "Getting file from #{d.url}"
			data = open(d.url) {|io| io.read}
			
			p "Sending file"
			
			content_type 'application/octet-stream'
			attachment d.name
			data
		else
			NOT_FOUND
		end
	end
	post "/#{FILESYSTEM_ROOT}/:namespace/:project/:document" do
		
		protected!
		NOT_IMPLEMENTED
	end
	delete "/#{FILESYSTEM_ROOT}/:namespace/:project/:document" do
		
		p "Delete request /#{FILESYSTEM_ROOT}/#{params[:namespace]}/#{params[:project]}/#{params[:document]}"
		protected!
		if (n = Namespace.get(params[:namespace])) && 
			(p = Project.get(params[:project], params[:namespace])) && 
			(d = Document.get(params[:document]) )
			puts [n.to_json, p.to_json, d.to_json]
			l = Link.first(project: p, document: d)
			puts l
			if l.destroy
				SUCCESS
			else
				NOT_DELETED
			end
		else
			NOT_FOUND
		end
	end
	def find_or_store(tempfile, filename)
		# tempfile is a Tempfile
		# filename is its human-readable filename
		# p "Find or Store?"
		
		require 'digest/md5'
		# just in case
		tempfile.rewind
		
		this_md5 = Digest::MD5.hexdigest(tempfile.read)
		
		if d = Document.first(md5: this_md5)
			p "File already found"
		
		else
			path = "https://s3.amazonaws.com/#{BUCKET_NAME}/#{this_md5}"
			
			p "Creating the file #{this_md5}"
			# For my purposes, MD5 is the AWS filename.
			upload(tempfile, this_md5)
			p "Making Document object"
			d = Document.new(
				url: path, 
				name: filename, 
				md5: this_md5,
				size_in_kb: ((tempfile.size)/1024).round
				)
			if !d.save
				p d.errors
			end
		end
		d
	end
		
	def upload(tempfile, filename)
		# tempfile is a Tempfile
		# filename is the name it should be stored as (in my case, MD5)
		s3 = AWS::S3.new(
			:access_key_id => AWS_ACCESS_KEY_ID, 
			:secret_access_key => AWS_ACCESS_SECRET_KEY 
		)
		p "Uploading file to S3 #{BUCKET_NAME}"
		# just in case 
		tempfile.rewind
		obj = s3.buckets[BUCKET_NAME].objects[filename].write(tempfile.read)
		# Oh heck, make sure people can download this stuff.
		obj.acl = :public_read
		filename
	end
	get "/links" do
		protected!
		"[ #{Link.all.map{ |l| l.link_json}.join(", ") } ]"
	end
	get "/documents" do
		
		protected!
		"[
			#{Document.all.map{|d| d.to_json}.join ", "} 
		]"
	end
	get "/documents/:pk" do
		require 'open-uri'
		d = Document.get(params[:pk])
		p "Getting file from #{d.url}"
		data = open(d.url) {|io| io.read}
		
		p "Sending file"
		
		content_type 'application/octet-stream'
		attachment d.name
		data
	end
	delete "/documents/:pk" do
		NOT_IMPLEMENTED
		# This is on purpose -- delete links, not documents!
	end

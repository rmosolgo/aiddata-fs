# AidDataFS

Document storage accessible by simple, RESTful url. Documents are stored along with their projects, 
and may be retrieved with three parameters: _namespace_, _project id_, and _document id_. For example, fs.aiddata.org/mbdc/1703/2843

## Setup

### Runs on...

- Sinatra framework:

```Ruby
	require 'rubygems'
	require 'bundler/setup'
	require 'sinatra'
```

- Postgres, via DataMapper gem:
```Ruby
	require 'data_mapper'
	require 'dm-postgres-adapter'
	require 'pg'
```

- Ruby utilities: Thin server, HAML templates, Barista for Coffeescript
```Ruby
	require 'thin'
	require 'haml'
	require 'barista'

```

- Amazon S3 for storage:

```Ruby

	require 'aws-sdk' 


```

### Connection info

Set authentication and connection info in the Environment. They are not written down -- you have to know them.

```Ruby
	AUTH_PAIR = [ENV['AIDDATA_FS_USERNAME'], ENV['AIDDATA_FS_PASSWORD']]

	BUCKET_NAME = 'aiddata-fs'

	AWS_ACCESS_KEY_ID =  ENV['AWS_ACCESS_KEY_ID']
	AWS_ACCESS_SECRET_KEY =  ENV['AWS_SECRET_KEY']
```

DataMapper is configured for Heroku's DATABASE_URL or the local machine.

```Ruby

	DataMapper.setup(:default, ENV['DATABASE_URL'] || 'postgres://postgres:postgres@localhost/postgres')

```

### Constants

Config constants for later:

```Ruby

	NOT_SAVED = "{ \"error\" : \" not saved \" }"
	NOT_FOUND = "{ \"error\" : \" not found \" }"
	NOT_IMPLEMENTED = "{ \"error\" : \" not implemented\" }"
	NOT_RECEIVED = "{ \"error\" : \" no file received\" }"
	NOT_DELETED = "{ \"error\" : \" not deleted\" }"
	FILE_TOO_BIG =  "{ \"error\" : \"this file is too large!\" }"
	SUCCESS = "{ \"success\" : \"success\" }"

	FILESYSTEM_ROOT = "files"
	MAX_FILE_SIZE = 10485760 # in bytes

```

### Icons

We serve icons with links for use on client side. They're generated from GMail attachment icons (is that illegal?):

```Ruby

	ICONS = {

		"doc" => "data:image/gif;base64,R0lGODlhEAAQANUgANvh8gZCm0RrvGCAylhwppOr5rnI7XmT1oCe5jJVmT1otmeK1TVesgg4ia672IOc2ipit4uk3Vd90E52y3eKnGd+syg+bfDy+oml6U1qpwlLsgU2goSEhMbGxgAAAP///////wAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACH5BAEAACAALAAAAAAQABAAAAaIQJCQQywahUgQ58NsMjkeYaGAQRwWkokA8oSCCk6nhukpexCGxwCwJkQ0nfincwaoAQJAhjKezz0HHwcCDgkRCQYBHX50Cx8VAgQbDBYfioweEh8EiBsbDh8NcYt0Ex+TFxsKTBtOdKthrKN/EBq2AbgNnq5RQ2GjpL1KsbxIHMDIccJQZs3NQQA7",

		"xls" => "data:image/gif;base64,R0lGODlhEAAQAMQfADRMGDhsIDRiFGuuZVWWRUiLOJXDkEaELDt3HI+8ij19I2SnXTNZFV6OVs3bzP79+trl2nOkb6CynpuvmoaohG+abOTr5FygVTJsDQoKCoSEhP7+/sbGxgAAAP///////yH5BAEAAB8ALAAAAAAQABAAAAWL4CdqZGmK6Kd57MOyWicOw3IRRHEoCPzIg41wKMSwMh3kwLAgbByNywTDqXo4mYXFMDhELgWI8XrtXJ6GiyLA2QiqnGvGmbikAxWIgBXndAoJCAECCQUBEgxwcgdEFIMNAC9lCkREkWR+CBibAgwMAKB9cigrcH1WfqSSq2Wkpq9VMiMdSbS0GUhIIQA7",

		"ppt" => "data:image/gif;base64,R0lGODlhEAAQANUgAO+TaZQ4LY8zJpE6M/CXXdd/XsdzV8VoTYcsJ9uDYvCkb//8+X0iGvCabPDJmfC6hlYMD9F3WMtULfbWxvJ/S/z07rA5L51dSP7n27BdQ6pJN7xdRYSEhMbGxgAAAP///////wAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACH5BAEAACAALAAAAAAQABAAAAaTQJCQQywahUgQ58NsMonCRKJQiBgOh83m+eGAEh9MZjC4TD7bj2ftKWA0lQVkgJhsOvhPp52JyyUNGRpOexECFBQAgAoBGngdeh4GAw4ODwAACgIBhB4HGQSWDQAEGQKPkQdvBAqkFhgInVsYBgEBBhgfDKh7WoIaAQIIDAydSEt6eo+Qe8dOz5HHy9N4Hsds2NlBADs=",

		"graphic" => "data:image/gif;base64,R0lGODlhEAAQALMPAPHv3hZpyg8wX6+sovzSSdKsOc/FnZp4PPOlqNm1SrUhKMbGxoSEhAAAAP///////yH5BAEAAA8ALAAAAAAQABAAAARa8ElGq5X4Mcc7Z02meR4VYhvJNew5qt3ipg5yGJ6MOkug/IBEwaCbBI4+BWE5nCEFgsSSUDg4j4JBYVqdAQJQhlZ4sO48gHIZdM4ZBvAZLDZb2O/4oqbF70cAADs=",

		"txt" => "data:image/gif;base64,R0lGODlhEAAQAKIAAIWFhYSEhAAAAMbGxv///////wAAAAAAACH5BAEAAAUALAAAAAAQABAAAAM8WBrcrrAEQisNIkoyuicBkEGTVQnouHnswKmlWQ0w13YvKVu0fuO9xW5W+7mCm2FOaFwmh8iA0QNLWa8JADs=",

		"zip" => "data:image/gif;base64,R0lGODlhEAAQALMIAOHhF66srE9PTy0tLcbGxoSEhAAAAP///////wAAAAAAAAAAAAAAAAAAAAAAAAAAACH5BAEAAAgALAAAAAAQABAAAARVEMlCq5UYlcM7L0ameR4VYhsXDOwAGucYCEJgF8NBxJsACJbcDnXwAY5AIa94ROJ0S5o0CSUeBras0npt5aoTErAzDB9eaPCI5ClrCPC43P2C2e+GCAA7",

		"sound" => "data:image/gif;base64,R0lGODlhEAAQALMPAG2Q10RipPHy8ipXpzBAeWN0qK2xvnqEmUpei5qhtIGjxsbGxoSEhAAAAP///////yH5BAEAAA8ALAAAAAAQABAAAARY8ElGq5X4Mcc7Z02meR4VYpu3FEXjniPHFgDBLXDqIEFQILdcBygQAB041NBRPCYnS4HBhhQ6po4DYCCoKrXcxEDRfY7ECpIXylSvY+43Y0Gv282gl14fAQA7",

		"pdf" => "data:image/gif;base64,R0lGODlhEAAQALMPAPsICf+0tP+KiqcBAtygof/q6vxhYf/Y2IsBA+5UVfYSFcbGxoSEhAAAAP///////yH5BAEAAA8ALAAAAAAQABAAAARm8ElGq5X4Mcc7Z41EJCSpJIrygY+ZvgDCNXSDvikADN7SKIigcEDshSaeRMCI2XAKBkGh42t2BIGDIXuoIjlbgcCgMBiOGk5gO3UUAgT0Zn3wcLwag9J+l5vbdngMC4SFhoI1iYoRADs=",

		"html" => "data:image/gif;base64,R0lGODlhEAAQAMQfAFOrFdz4lUWOs1JTsCNzHK/Xmerp+oSkyE1w8y9ZkdLU60NS9DA44xpZP46O03V50jSKV4HPOK7lYRc0aTuHHzQ9yRgkkbHxUE5b1qGn4k+pZ4SEhMbGxgAAAP///////yH5BAEAAB8ALAAAAAAQABAAAAWO4CduZGmK6Ld5bMtuXap6XG17ZIwqDvJkhlZnGDMcOIFLJIGxcWgdY2B6ATQWGEWL08loChIlIbFgPGrQB4RAiVCu5cG2gxFAGhQKJMFgWNBcDwiDBBESAHxyLFwZGIMNAIcNFg6AUQ4VCwmQFBMDQYs6mBUTDZ5OUCIGDgMWCQ9aLlwoG062NToqRLu8IQA7",

	}

```

## Models

### Namespace

Namespace denotes the collection to which a given project belongs. 
For example, namespaces might be "aiddata" for aiddata.org, "malawi" for Malawi-AMP 
projects, or "mbdc" for media-based data collection projects. 

```Ruby
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
```
#### Permissions

 Any user me `GET` a resource, but any idempotent request must pass authentication (also known to AidData FS).

```Ruby


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
```



### Project

Project denotes the actual activity in the given namespace. It likely has an instance in a particular database or dataset, such as AidData.org or the Malawi geocoded dataset. 

```Ruby
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
```



### Document

Link is what actually appears inside a project's folder. It's a reference to the underlying document:

```Ruby
	class Link
		include DataMapper::Resource
		property :id, Serial
		property :document_pk, Integer

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
```

Document is the reference to the file. It serves up a data uri in the `Document#icon` method.

```Ruby
	class Document
		include DataMapper::Resource
		
		require 'digest/md5'

		property :pk, Serial 
		# property :id, Integer #not really a pk, because doc can change versions.
		property :md5, String
		property :url, Text
		property :size_in_kb, Integer
		property :type, Text, default: lambda { |r, p| File.extname(r.name).gsub(/\./, '').downcase  }
		property :name, Text

		def icon

			if %w{doc docx xml odt }.include? type 
				ICONS["doc"]
			elsif %w{png jpg jpeg gif bmp tiff svg}.include? type
				ICONS["graphic"]
			elsif %w{mp3 wav aac}.include? type
				ICONS["sound"]
			elsif %w{xls xlsx csv tsv tab ods}.include? type
				ICONS["xls"]
			elsif %w{ppt pptx odp}.include? type
				ICONS["ppt"]
			elsif %w{zip gz 7z}.include? type
				ICONS["zip"]
			elsif %w{pdf}.include? type
				ICONS["pdf"]
			elsif %{html}.include? type
				ICONS["html"]
			else 
				ICONS["txt"]
			end
		end

		def to_json
			json = "{ 
					\"type\" : \"document\",
					\"name\" : \"#{name}\", 
					\"key\" : \"#{pk}\", 
					\"size_in_kb\" : #{size_in_kb},
					\"filetype\" : \"#{type}\",
					\"md5\" : \"#{ md5}\",	
					\"path\" : \"/documents/#{pk}\",
					\"icon\" : \"#{icon}\" 
				}"
		end
	end



```



```Ruby
	DataMapper.finalize.auto_upgrade!


	get "/" do
		haml :browse
	end

	get "/#{FILESYSTEM_ROOT}" do
		locate "root", Namespace.all
	end
```

## API

JSON API is powered by the models' `:to_json` method, which allows really simple navigation.

```Ruby


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

```

### Namespace

__URL:__ `/:namespace`

- `POST` a new `name` to `/` to create a new namespace.
- `GET`ting the namespace path (eg `/mbdc`) responds with a project manifest.

```Ruby
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
```

### Projects

Create it by posting its `project_id` to its namespace:

```Ruby
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


```

It has a RESTful URL such as `/malawi/8071234` which responds to requests:

- `POST`ing a file adds that file to the project.
- `DELETE`ing a file destroys that link
- `GET` returns a document manifest.

```Ruby
	get "/#{FILESYSTEM_ROOT}/:namespace/:project" do
		
		if (n = Namespace.get(params[:namespace])) && (p = Project.get(params[:project], params[:namespace]))
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

		if (n = Namespace.get(params[:namespace])) && (p = Project.first_or_create(id: params[:project], namespace: n))

			# puts p.to_json

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


```

### Documents
Individual documents have RESTful URLs, eg `/malawi/8071234/9983`.

- GET returns the file
- POST/PUT replaces the file with the new file
- `DELETE` removes the file

```Ruby
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
		
		protected!

		p "Delete request /#{FILESYSTEM_ROOT}/#{params[:namespace]}/#{params[:project]}/#{params[:document]}"
		
		if (n = Namespace.get(params[:namespace])) && 
			(p = Project.get(params[:project], params[:namespace])) && 
			(d_id = params[:document] )

			l = Link.first(project: p, document_pk: d_id)

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


```

## Documents

### Documents aren't stored redundantly

When a file is loaded, its md5 is generated and tested against existing md5s.

```Ruby

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
		
```


#### If false

Then the file is stored on the server and a link is created.

```Ruby

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
```


#### If true

Then a link is created, registering that document with the requested project.

### Links
```Ruby
	get "/links" do

		protected!

		"[ #{Link.all.map{ |l| l.link_json}.join(", ") } ]"
	end
```

A given document may be present in multiple links:

```json
{ "namespace" : "malawi", "project_id" : 8071234, "document_id" : 9983 },
{ "namespace" : "mbdc", "project_id" : 1703, "document_id" : 9983 }
```

And a project will have many links:

```json
{ "namespace" : "malawi", "project_id" : 8071234, "document_id" : 9983 }
...
{ "namespace" : "malawi", "project_id" : 8071234, "document_id" : 3214 }
```

### The documents themselves are served purely by ID

But the `/:namespace/:project/:document` API provides a logical, stable, implementation-independent interface to the files.

Documents can also be downloaded directly via `/document/:id`.
```Ruby

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


```
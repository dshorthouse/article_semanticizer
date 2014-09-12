class Article < ActiveRecord::Base
  has_many :name_strings_content, :through => :article_name_strings, :foreign_key => :name_string_id, :class_name => "NameString", :source => :name_string
  has_many :article_name_strings

  has_many :name_strings_abstract, :through => :abstract_name_strings, :foreign_key => :name_string_id, :class_name => "NameString", :source => :name_string
  has_many :abstract_name_strings

  has_many :name_strings_title, :through => :title_name_strings, :foreign_key => :name_string_id, :class_name => "NameString", :source => :name_string
  has_many :title_name_strings
  
  has_many :entities, :through => :article_entities
  has_many :article_entities

  NAMES_HASH = {}
  STATUS = { init: 0, enqueued: 1, sent: 2, completed: 3, failed: 4 }
  ENTITY_STATUS = { init: 0, sent: 1, completed: 3}
  
  def self.populate
    root_path = ArticleSemanticizer::Config.root_file_path
    Dir.chdir(root_path)
    count = 0
    Find.find(".").each do |f|
      next if f.include? "DS_Store"
      if File.extname(f) == ".pdf"
        count += 1
        puts "Adding title %s" % count if count % 100 == 0
        pdf_path = File.path(f)
        text_path = pdf_path.sub("Article_pdf", "Article_text").sub(".pdf", ".txt")
        metadata_path = pdf_path.sub("Article_pdf", "Sgm").sub(".pdf", ".sgml")
        if File.exists?(File.join(root_path, text_path)) && File.exists?(File.join(root_path, metadata_path))
          Article.connection.execute("INSERT INTO articles (pdf_path, text_path, metadata_path, created_at, updated_at) VALUES (%s, %s, %s, now(), now())" % [Article.connection.quote(pdf_path), Article.connection.quote(text_path), Article.connection.quote(metadata_path)])
        else
          puts "File missing for %s" % pdf_path
        end
      end
    end
  end
  
  def self.delete_images
    root_path = ArticleSemanticizer::Config.root_file_path
    Dir.chdir(root_path)
    count = 0
    Find.find(".").each do |f|
      next if f.include? "DS_Store"
      if File.extname(f) == ".jpg"
        count += 1
        File.delete(f)
        puts "Deleted file %s" %count
      end
    end
  end
  
  def self.split_pdfs
    root_path = ArticleSemanticizer::Config.root_file_path
    count = 0
    Article.find_each(:batch_size => 50) do |a|
      count += 1
      pdf = File.join(root_path, a.pdf_path[1..-1])
      jpg = pdf.sub("Article_pdf", "Article_jpg")
      opts = { :output => File.dirname(jpg), :format => [:jpg], :pages => 1 }
      Docsplit.extract_images(pdf, opts)
      puts "Extracted image %s" %  count if count % 100 == 0
    end
  end
  
  def self.populate_citations
    root_path = ArticleSemanticizer::Config.root_file_path
    coder = HTMLEntities.new
    count = 0
    Article.find_each(:batch_size => 25) do |a|
      count += 1
      metadata = File.open(File.join(root_path, a.metadata_path)).read
      xml = Nokogiri::XML(metadata)
      year = xml.xpath("//pubdate").text[0,4] rescue nil
      title = Sanitize.clean(coder.decode(xml.xpath("//title").inner_html)) rescue nil
      abstract = Sanitize.clean(coder.decode(xml.xpath("//abstract").inner_html)) rescue nil
      doi = Article.connection.quote("10.4039/" + xml.xpath("//ftlink").text) rescue nil
      abstract = (abstract.nil? || abstract.length < 15) ? "NULL" : Article.connection.quote(abstract)
      title = (title.nil? || title.empty?) ? "NULL" : Article.connection.quote(title)
      year = (year.nil? || year.empty?) ? "NULL" : year
      Article.connection.execute("UPDATE articles set year = %s, title = %s, abstract = %s, doi = %s WHERE id = %s" % [year, title, abstract, doi, a.id])
      puts "Constructing citation %s" % count if count % 100 == 0
    end
  end
  
  def self.verify_dois
    count = 0
    Article.where("status = %s" % Article::STATUS[init]).find_each(:batch_size => 5) do |a|
      count += 1
      begin
        res = RestClient.get ArticleSemanticizer::Config.biblio_api_url, :params => { :q => a.doi, :style => 'asa' }
        data = JSON.parse(res, :symbolize_names => true)
        doi = Article.connection.quote(a.doi)
        if data[:records][0][:status] == "success"
          citation = Article.connection.quote(data[:records][0][:formatted])
        else
          citation = "NULL"
          doi = "NULL"
        end
        Article.connection.execute("UPDATE articles SET citation = %s, doi = %s WHERE id = %s" % [citation, doi, a.id])
      rescue
      end
      puts "Verified doi %s" % count if count % 10 == 0
      sleep 1
    end
  end
  
  def resolved_names_title
    n = []
    name_strings_title.each do |name|
      n << name.resolved_name_strings.map{ |n| n.resolved_canonical_form.name }
    end
    n.flatten.uniq
  end
  
  def resolved_names_abstract
    n = []
    name_strings_abstract.each do |name|
      n << name.resolved_name_strings.map{ |n| n.resolved_canonical_form.name }
    end
    n.flatten.uniq
  end

  def resolved_names_content
    n = []
    name_strings_content.each do |name|
      n << name.resolved_name_strings.map{ |n| n.resolved_canonical_form.name }
    end
    n.flatten.uniq
  end

  def vernaculars_title
    vernacular_hashes(name_strings_title)
  end
  
  def vernaculars_abstract
    vernacular_hashes(name_strings_abstract)
  end
  
  def vernaculars_content
    vernacular_hashes(name_strings_content)
  end
  
  def vernacular_hashes(content_type_names)
    n = []
    content_type_names.each do |name|
      name.resolved_name_strings.each do |resolved|
        resolved.resolved_canonical_form.vernaculars.each do |v|
          n << { :name => v.name, :language => v.language }
        end
      end
    end
    n.flatten.uniq
  end
  
  def places
    places = []
    entities.each do |entity|
      if ['Continent', 'Country', 'StateOrCounty', 'Region', 'GeographicFeature', 'City'].include? entity.entity_type
        location = entity.coords.nil? ? nil : entity.coords.gsub(" ", ",")
        places << { :name => entity.name, :location => location }
      end
    end
    places.flatten.uniq
  end
  
  def pdf_url
    "/files" + pdf_path[1..-1]
  end
  
  def text_url
    "/files" + text_path[1..-1]
  end
  
  def jpg_url
    "/files" + pdf_path[1..-1].sub("Article_pdf", "Article_jpg").sub(".pdf", "_1.jpg")
  end
  
  def send_content(content_type = 'text')
    @content_type = content_type
    case @content_type
      when 'text'
        post_data(full_text)
      when 'title'
        post_data(title)
      when 'abstract'
        post_data(abstract)
    end
  end
  
  def post_data(content)
    url = ArticleSemanticizer::Config.gnrd_api_url
    params = { :text => content, :engine => 0, :detect_language => "false", :unique => "false" }
    if url.include?("gnrd") || url.include?("128.128")
      addressable = Addressable::URI.new
      addressable.query_values = params
      gz_payload = ActiveSupport::Gzip.compress(addressable.query)

      uri = URI(url)
      req = Net::HTTP::Post.new(uri.path)
      req["Content-Encoding"] = "gzip"
      req["Content-Length"] = gz_payload.size
      req["X-Uncompressed-Length"] = addressable.query.size
      req.body = gz_payload

      res = Net::HTTP.start(uri.hostname, uri.port) do |http|
        http.request(req)
      end
      
      if[302, 303].include? res.response.code.to_i
        save_location(res.header.to_hash["location"][0])
      else
        save_failed
      end
    else
      res = RestClient.post(ArticleSemanticizer::Config.gnrd_api_url, params) do |response, request, result, &block|
        if [302, 303].include? response.code
          save_location(response.headers[:location])
        else
          save_failed
        end
      end
    end
  end
  
  def save_location(url)
    self.gnrd_url = url
    self.status = Article::STATUS[:sent]
    self.save!
  end
  
  def save_failed
    self.status = Article::STATUS[:failed]
    self.save!
  end

  def get_names
    return unless gnrd_url
    res = nil
    until res
      begin
        res = JSON.parse(RestClient.get(gnrd_url), :symbolize_names => true)
      rescue RestClient::BadGateway
        res = nil
      end
    end
    if res[:status] == 500
      self.status = Article::STATUS[:failed]
      self.save!
      reload
    end
    @names = res[:names]
  end

  def names_to_content
    if @names.blank?
      self.status = Article::STATUS[:completed]
      self.save!
      return
    end
    data = []
    Article.transaction do
      @names.each do |current_name|
        if !current_name[:scientificName].empty?
          name = NameString.normalize(current_name[:scientificName])
          if name
            name_string_id = Article::NAMES_HASH[name]
            unless name_string_id
              name_quoted = NameString.connection.quote(name)
              NameString.connection.execute("INSERT INTO name_strings (name, created_at, updated_at) VALUES (%s, now(), now())" % name_quoted)
              name_string_id = NameString.connection.select_values("select last_insert_id()")[0]
              Article::NAMES_HASH[name] = name_string_id
            end
            data << [self.id, name_string_id, current_name[:offsetStart], current_name[:offsetEnd], 'now()', 'now()']
          end
        end
      end
      add_content_data(data)
    end
    self.status = Article::STATUS[:completed]
    self.save!
  end

  def full_text
    root_path = ArticleSemanticizer::Config.root_file_path
    File.open(File.join(root_path, text_path)).read
  end
  
  def add_content_data(data)
    return if data.empty?
    data = data.map{|d| d.join(',')}.join('),(')
    case @content_type
      when 'text'
        ArticleNameString.connection.execute("INSERT INTO article_name_strings (article_id, name_string_id, name_offset_start, name_offset_end, updated_at, created_at) VALUES (%s)" % data)
      when 'title'
        TitleNameString.connection.execute("INSERT INTO title_name_strings (article_id, name_string_id, name_offset_start, name_offset_end, updated_at, created_at) VALUES (%s)" % data)
      when 'abstract'
        AbstractNameString.connection.execute("INSERT INTO abstract_name_strings (article_id, name_string_id, name_offset_start, name_offset_end, updated_at, created_at) VALUES (%s)" % data)
    end
  end

end
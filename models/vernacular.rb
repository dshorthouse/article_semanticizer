class Vernacular < ActiveRecord::Base
  belongs_to :resolved_canonical_vernacular
  
  NAMES_HASH = {}
  STATUS = { init: 0, enqueued: 1, sent: 2, completed: 3, failed: 4 }
  
  def self.rebuild_names_hash
    if Vernacular::NAMES_HASH.empty?
      Vernacular.all.each do |n|
        Vernacular::NAMES_HASH[n.name] = n.id
      end
    end
  end
  
  def self.populate
    counter = 0
    rebuild_names_hash
    ResolvedCanonicalForm.where("vernacular_status IS NULL").find_in_batches(:batch_size => 20) do |group|
      vernaculars = []
      group.each do |canonical|
        Vernacular.transaction do
          save_initialized(canonical)
          results = eol_search(canonical)
          results.each do |v|
            name = v[:vernacularName].strip
            vernacular_id = Vernacular::NAMES_HASH[name]
            unless vernacular_id
              name_quoted = Vernacular.connection.quote(name)
              language_quoted = Vernacular.connection.quote(v[:language])
              Vernacular.connection.execute("INSERT INTO vernaculars (name, language, created_at, updated_at) VALUES (%s, %s, now(), now())" % [name_quoted, language_quoted])
              vernacular_id = Vernacular.connection.select_values("select last_insert_id()")[0]
              Vernacular::NAMES_HASH[name] = vernacular_id
            end
            Vernacular.connection.execute("INSERT INTO resolved_canonical_vernaculars (resolved_canonical_form_id, vernacular_id, created_at, updated_at) VALUES (%s, %s, now(), now())" % [canonical.id, vernacular_id])
            vernaculars << v[:vernacularName]
          end
          save_completed(canonical)
        end
      end
      counter += vernaculars.size
      puts "Added #{counter} vernaculars"
    end
  end
  
  def self.eol_search(canonical)
    results = []
    res = RestClient.get ArticleSemanticizer::Config.eol_search_api_url, :params => { :q => canonical.name }
    canonical.vernacular_status = Vernacular::STATUS[:sent]
    canonical.save!
    data = JSON.parse(res, :symbolize_names => true)
    if data[:totalResults] > 0
      sleep 0.5
      results = eol_pages(data[:results][0][:id])
    end
    results
  end
  
  def self.eol_pages(id)
    res = RestClient.get ArticleSemanticizer::Config.eol_pages_api_url + "#{id}.json", :params => {
      :images => 0,
      :videos => 0,
      :sounds => 0,
      :maps => 0,
      :text => 0,
      :iucn => false,
      :subjects => "",
      :licenses => "all",
      :details => false,
      :common_names => true,
      :synonyms => false,
      :references => false,
      :vetted => 0 }
    data = JSON.parse(res, :symbolize_names => true)
    data[:vernacularNames]
  end
  
  def self.save_initialized(canonical)
    canonical.vernacular_status = Vernacular::STATUS[:init]
    canonical.save!
  end
  
  def self.save_completed(canonical)
    canonical.vernacular_status = Vernacular::STATUS[:completed]
    canonical.save!
  end
  
end
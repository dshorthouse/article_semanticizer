module ArticleSemanticizer
  class ResolverClient
    attr_accessor :batch_size

    def initialize
      @url = ArticleSemanticizer::Config.resolver_api_url
      @batch_size = 50
    end
    
    def process_batch(status_number = NameString::STATUS[:init])
      ids_names = get_ids_and_names(status_number)
      return 0 if ids_names == nil || ids_names.empty?
      ids, names = ids_names.transpose
      puts ids
      ids = ids.join(',')
      NameString.connection.execute("UPDATE name_strings SET status = %s WHERE id IN (%s)" % [NameString::STATUS[:enqueued], ids])
      names_batch = ids_names.map { |i| i.join("|") }.join("\n")
      resource = RestClient::Resource.new(@url, timeout: 9_000_000, open_timeout: 9_000_000, connection: "Keep-Alive")
      r = resource.post(:data => names_batch, :with_context => false, :resolve_once => false) rescue nil
      r = JSON.parse(r, :symbolize_names => true) rescue nil
      if r
        if !r[:data] && r[:url]
          res = nil
          until res
            sleep(2)
            res = JSON.parse(RestClient.get(r[:url]), :symbolize_names => true)[:data]
          end
          r[:data] = res
        end
        if r[:data]
          rr = ResolverResult.new(r)
          rr.process
        end
      end
      ids_names.size
    end
    
    def process_failed_batches(batch_size)
      @batch_size = batch_size
      process_batch(NameString::STATUS[:init])
    end

    private

    def get_ids_and_names(status_number)
      NameString.connection.select_rows("SELECT id, name FROM name_strings WHERE status IS NULL OR status = %s LIMIT %s" % [status_number, @batch_size])
    end

  end

  class ResolverResult
    
    CURATED_SOURCES = [1,2,3,4,5,6,7,8,9,105,132,151,155,158,163,165,167]
    NAME_BANK_ID = 169
    
    def initialize(resolver_result)
      @result = resolver_result
      @found_ids = []
      @not_found_ids = []
      @records = []
    end

    def process
      @result[:data].each do |d|
        name_string_id = d[:supplied_id]
        @found_ids << name_string_id
        d[:results] = d[:results].select {|i| i[:score] > 0.5} if d[:results]
        if d[:results] && !d[:results].empty?
          process_non_empty_results(d[:results], name_string_id)
        else
          @not_found_ids << name_string_id 
        end
      end
      submit_data
    end

    private
    
    def get_canonical_form_id(canonical_form)
      canonical_form_id = nil
      Article.transaction do
        canonical_quoted = ResolvedCanonicalForm.connection.quote(canonical_form)
        canonical_form_id = ResolvedCanonicalForm.connection.select_value("SELECT id FROM resolved_canonical_forms WHERE name = %s" % canonical_quoted)
        unless canonical_form_id
          ResolvedCanonicalForm.connection.execute("INSERT INTO resolved_canonical_forms (name, created_at, updated_at) VALUES (%s, now(), now())" % canonical_quoted)
          canonical_form_id = ResolvedCanonicalForm.connection.select_values("SELECT last_insert_id()")[0]
        end
      end
      canonical_form_id
    end

    def process_non_empty_results(results, name_string_id)
      results_size = results.size
      results = partition_curated_namebank_other(results)
      
      in_curated_source = !results[:curated].empty?
      record = nil
      if in_curated_source 
        record = results[:curated][0]
      else 
        record = results[:other][0]
      end
      
      match_type = record[:match_type]
      record = results[:namebank][0] unless results[:namebank].empty?
      canonical_form_id = get_canonical_form_id(record[:canonical_form])
      local_id = record[:local_id] ? record[:local_id].gsub("urn:lsid:ubio.org:namebank:", '') : nil
      classification_path = record[:classification_path] ? record[:classification_path] : nil
      classification_path_ranks = record[:classification_path_ranks] ? record[:classification_path_ranks] : nil
      classification_path_ids = record[:classification_path_ids] ? record[:classification_path_ids] : nil
      @records << [name_string_id.to_i, record[:data_source_id].to_i, local_id, record[:gni_uuid], canonical_form_id, record[:name_string], record[:score].to_f * 1000, match_type, classification_path, classification_path_ranks, classification_path_ids, in_curated_source, results_size, Time.now, Time.now].map { |i| Article.connection.quote(i) }.join(',')
    end

    def partition_curated_namebank_other(results)
      results = results.inject({:curated => [], :namebank => [], :other => []}) do |res, r|
        if CURATED_SOURCES.include? r[:data_source_id]
          res[:curated] << r
        else
          res[:other] << r
          res[:namebank] << r if r[:data_source_id] == NAME_BANK_ID
        end
        res
      end
      results.keys.each { |k| results[k].sort_by! { |r| r[:match_type] } }
      results
    end

    def submit_data
      Article.transaction do
        Article.connection.execute("INSERT IGNORE resolved_name_strings (name_string_id, data_source_id, local_id, gni_uuid, canonical_form_id, name, score, match_type, classification_path, classification_path_ranks, classification_path_ids, in_curated_sources, finds_num, created_at, updated_at) VALUES (#{@records.join('),(')})") unless @records.empty?
        Article.connection.execute("UPDATE name_strings SET status = #{NameString::STATUS[:found]} WHERE id IN (#{@found_ids.join(',')})") unless @found_ids.empty?
        Article.connection.execute("UPDATE name_strings SET status = #{NameString::STATUS[:not_found]} WHERE id IN (#{@not_found_ids.join(',')})") unless @not_found_ids.empty?
      end
    end
  end
end
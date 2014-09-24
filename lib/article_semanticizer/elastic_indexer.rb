module ArticleSemanticizer
  class ElasticIndexer
    
    def initialize
      @client = Elasticsearch::Client.new
    end
    
    def delete
      if @client.indices.exists index: ArticleSemanticizer::Config.elastic_index
        @client.indices.delete index: ArticleSemanticizer::Config.elastic_index
      end
    end

    def create
      config = {
        :settings => {
          :analysis => {
            :tokenizer => {
              :scientific_name_tokenizer => {
                :type      => "path_hierarchy",
                :delimiter => " ",
                :skip      => 1
              }
            },
            :filter => {
              :autocomplete => {
                :type     => "edgeNGram",
                :side     => "front",
                :min_gram => 4,
                :max_gram => 100
              },
              :genus_abbreviation => {
                :type     => "pattern_replace",
                :pattern  => "(^.)[^\\s]+",
                :replacement => "$1."
              },
              :vernacular_elision => {
                :type     => "elision",
                :articles => ["l", "m", "t"]
              },
              :vernacular_stemmer => {
                :type     => "stemmer",
                :name     => "english"
              }
            },
            :analyzer => {
              :scientific_name_index => {
                :type         => "custom",
                :tokenizer    => "keyword",
                :filter       => ["lowercase", "asciifolding", :autocomplete]
              },
              :scientific_name_search => {
                :type         => "custom",
                :tokenizer    => "keyword",
                :filter       => ["lowercase", "asciifolding"]
              },
              :scientific_epithet_index => {
                :type         => "custom",
                :tokenizer    => "scientific_name_tokenizer",
                :filter       => ["lowercase", "asciifolding"]
              },
              :vernacular_name_index => {
                :type         => "custom",
                :tokenizer    => "standard",
                :filter       => ["lowercase", "asciifolding", :vernacular_elision, :vernacular_stemmer, :autocomplete]
              },
              :vernacular_name_search => {
                :type         => "custom",
                :tokenizer    => "standard",
                :filter       => ["lowercase", "asciifolding", :vernacular_elision, :vernacular_stemmer]
              }
            }
          }
        },
        :mappings => {
          :scientific => {
            :properties => {
              :id => { :type => 'integer', :index => 'not_analyzed' },
              :name => { :type => 'string', :search_analyzer => :scientific_name_search, :index_analyzer => :scientific_name_index }
            }
          },
          :vernacular => {
            :properties => {
              :id => { :type => 'integer', :index => 'not_analyzed' },
              :name => { :type => 'string', :search_analyzer => :vernacular_name_search, :index_analyzer => :vernacular_name_index }
            }
          },
          :article => {
            :properties => {
              :id => { :type => 'integer', :index => 'not_analyzed' },
              :doi => { :type => 'string', :index => 'not_analyzed' },
              :year => { :type => 'integer' },
              :pdf => { :type => 'string', :index => 'not_analyzed' },
              :txt => { :type => 'string', :index => 'not_analyzed' },
              :jpg => { :type => 'string', :index => 'not_analyzed' },
              :citation => {
                :properties => {
                  :content => { :type => 'string', :analyzer => 'standard' },
                  :scientific_names => { :type => 'string', :search_analyzer => :scientific_name_search, :index_analyzer => :scientific_name_search, :omit_norms => true },
                  :vernacular_names => { 
                    :properties => {
                      :name => { :type => 'string', :search_analyzer => :vernacular_name_search, :index_analyzer => :vernacular_name_index, :omit_norms => true },
                      :language => { :type => 'string', :index => 'not_analyzed'}
                    }
                  }
                }
              },
              :abstract => {
                :properties => {
                  :content => { :type => 'string', :analyzer => 'standard' },
                  :scientific_names => { :type => 'string', :search_analyzer => :scientific_name_search, :index_analyzer => :scientific_name_search, :omit_norms => true },
                  :vernacular_names => { 
                    :properties => {
                      :name => { :type => 'string', :search_analyzer => :vernacular_name_search, :index_analyzer => :vernacular_name_index, :omit_norms => true },
                      :language => { :type => 'string', :index => 'not_analyzed'}
                    }
                  }
                }
              },
              :full_text => {
                :properties => {
                  :content => { :type => 'string', :analyzer => 'standard' },
                  :scientific_names => { :type => 'string', :search_analyzer => :scientific_name_search, :index_analyzer => :scientific_name_search, :omit_norms => true },
                  :vernacular_names => { 
                    :properties => {
                      :name => { :type => 'string', :search_analyzer => :vernacular_name_search, :index_analyzer => :vernacular_name_index, :omit_norms => true },
                      :language => { :type => 'string', :index => 'not_analyzed'}
                    }
                  },
                  :places => {
                    :properties => {
                      :name => { :type => 'string', :analyzer => 'standard' },
                      :location => { :type => 'geo_point', :lat_lon => true }
                    }
                  }
                }
              }
            }
          }
        }
      }
      @client.indices.create index: ArticleSemanticizer::Config.elastic_index, body: config
    end

    def import_scientific_names
      counter = 0
      ResolvedCanonicalForm.find_in_batches(:batch_size => 1_000) do |group|
        scientific_names = []
        group.each do |name|
          scientific_names << { index: {
                                _id: name.id,
                                data: {
                                  id: name.id,
                                  name: name.name }
                                }
                              }
        end
        @client.bulk :index => ArticleSemanticizer::Config.elastic_index, :type => 'scientific', :body => scientific_names
        counter += scientific_names.size
        puts "Added #{counter} scientific names"
      end
    end

    def import_vernacular_names
      counter = 0
      Vernacular.find_in_batches(:batch_size => 1_000) do |group|
        vernacular_names = []
        group.each do |name|
          vernacular_names << { index: {
                                _id: name.id,
                                data: {
                                  id: name.id,
                                  name: name.name }
                                }
                              }
        end
        @client.bulk :index => ArticleSemanticizer::Config.elastic_index, :type => 'vernacular', :body => vernacular_names
        counter += vernacular_names.size
        puts "Added #{counter} vernacular names"
      end
    end

    def import_articles
      counter = 0
      Article.find_in_batches(:batch_size => 50) do |group|
        articles = []
        group.each do |article|
          if !article.doi.nil? && !article.citation.nil?
            resolved_names_title = article.resolved_names_title
            resolved_names_abstract = article.resolved_names_abstract
            resolved_names_content = article.resolved_names_content
            articles << {
                          index: {
                            _id: article.id,
                            data: {
                              id: article.id,
                              doi: article.doi,
                              year: article.year,
                              pdf: article.pdf_url,
                              txt: article.text_url,
                              jpg: article.jpg_url,
                              citation: {
                                content: article.citation,
                                scientific_names: resolved_names_title,
                                vernacular_names: article.vernaculars_title
                              },
                              abstract: {
                                content: article.abstract,
                                scientific_names: resolved_names_abstract,
                                vernacular_names: article.vernaculars_abstract
                              },
                              full_text: {
                                content: article.full_text,
                                scientific_names: resolved_names_content,
                                vernacular_names: article.vernaculars_content,
                                places: article.places
                              }                            
                            }
                          }
                        }
          end
        end
        @client.bulk :index => ArticleSemanticizer::Config.elastic_index, :type => 'article', :body => articles
        counter += articles.size
        puts "Added #{counter} articles"
      end
    end

    def refresh
      @tire.refresh
    end

  end
end
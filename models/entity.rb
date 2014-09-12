class Entity < ActiveRecord::Base
  belongs_to :article_entity

  ENTITY_HASH = {}

  def self.rebuild_entity_hash
    if Entity::ENTITY_HASH.empty?
      Entity.all.each do |n|
        Entity::ENTITY_HASH[n.name.strip] = n.id
      end
    end
  end
  
  def self.populate
    rebuild_entity_hash
    Article.where("entity_status IS NULL").find_in_batches(:batch_size => 20) do |group|
      group.each do |article|
        Article.transaction do
          save_initialized(article)
          entities = send_content(article)
          process_entities(article, entities)
          save_completed(article)
          puts "Processed #{entities.size} entities for article #{article.id}"
        end
      end
      sleep 2
    end
  end

  def self.send_content(article)
    entities = []
    params = { :apikey => ArticleSemanticizer::Config.alchemy_api_key, :text => article.full_text, :outputMode => 'json' }
    RestClient.post(ArticleSemanticizer::Config.alchemy_api_url, params) do |response, request, result, &block|
      entities = JSON.parse(response, :symbolize_names => true)[:entities] rescue []
    end
    entities
  end

  def self.process_entities(article, entities)
    entities.each do |entity|
      if entity.include?(:disambiguated)
        name = entity[:disambiguated][:name].strip
        entity_id = Entity::ENTITY_HASH[name]
        unless entity_id
          type_quoted = Entity.connection.quote(entity[:type].strip)
          name_quoted = Entity.connection.quote(name)
          coords_quoted = entity[:disambiguated].include?(:geo) ? Entity.connection.quote(entity[:disambiguated][:geo]) : "NULL"
          geonames_quoted = entity[:disambiguated].include?(:geonames) ? Entity.connection.quote(entity[:disambiguated][:geonames]) : "NULL"
          Entity.connection.execute("INSERT INTO entities (entity_type, name, coords, geonames, created_at, updated_at) VALUES (%s, %s, %s, %s, now(), now())" % [type_quoted, name_quoted, coords_quoted, geonames_quoted])
          entity_id = Entity.connection.select_values("select last_insert_id()")[0]
          Entity::ENTITY_HASH[name] = entity_id
        end
        Entity.connection.execute("INSERT INTO article_entities (article_id, entity_id, created_at, updated_at) VALUES (%s, %s, now(), now())" % [article.id, entity_id])
      end
    end
  end

  def self.save_initialized(article)
    article.entity_status = Article::ENTITY_STATUS[:init]
    article.save!
  end
  
  def self.save_completed(article)
    article.entity_status = Article::ENTITY_STATUS[:completed]
    article.save!
  end
end
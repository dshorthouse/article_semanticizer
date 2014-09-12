class CreateEntites < ActiveRecord::Migration
  def up
    execute "CREATE TABLE `entities` (
      `id` int(11) UNSIGNED NOT NULL AUTO_INCREMENT,
      `entity_type` varchar(25) DEFAULT NULL,
      `name` varchar(255) COLLATE utf8_bin DEFAULT NULL,
      `coords` varchar(255) DEFAULT NULL,
      `geonames` varchar(128) DEFAULT NULL,
      `created_at` datetime DEFAULT NULL,
      `updated_at` datetime DEFAULT NULL,
      PRIMARY KEY (`id`),
      UNIQUE KEY `idx_entity` (`name`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci"
    create_table :article_entities do |t|
      t.references :article
      t.references :entity
      t.timestamps
    end
    add_column :articles, :entity_status, :integer
  end

  def down
    remove_column :articles, :entity_status
    drop_table :entities
    drop_table :article_entities
  end

end
    
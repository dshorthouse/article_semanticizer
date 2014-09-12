class CreateVernaculars < ActiveRecord::Migration
  def up
    execute "CREATE TABLE `vernaculars` (
      `id` int(11) UNSIGNED NOT NULL AUTO_INCREMENT,
      `name` varchar(255) COLLATE utf8_bin DEFAULT NULL,
      `language` varchar(5) DEFAULT NULL,
      `created_at` datetime DEFAULT NULL,
      `updated_at` datetime DEFAULT NULL,
      PRIMARY KEY (`id`),
      UNIQUE KEY `idx_vernaculars` (`name`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci"
  end

  def down
    drop_table :vernaculars
  end
end
    